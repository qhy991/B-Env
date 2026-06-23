#!/usr/bin/env bash
# Bootstrap shared GLM-5.2 B200 Python environment for operator workspaces.
#
# Usage:
#   cp config/paths.env.example config/paths.env   # edit paths first
#   bash scripts/setup-env.sh
#   bash scripts/setup-env.sh --deep-gemm
#   bash scripts/setup-env.sh --verify
#
# Prerequisites: NVIDIA B200, CUDA 13.x toolkit, git, python 3.12 or uv

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -f "${ROOT}/config/paths.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/config/paths.env"
else
  # shellcheck disable=SC1091
  source "${ROOT}/config/paths.env.example"
fi

VENV="${VENV_ROOT:-}"
if [[ -z "${VENV}" ]]; then
  echo "Set VENV_ROOT in config/paths.env before running setup." >&2
  exit 1
fi
TORCH_INDEX="https://download.pytorch.org/whl/cu130"
DEEP_GEMM_REPO="${DEEP_GEMM_REPO:-https://github.com/deepseek-ai/DeepGEMM.git}"
DEEP_GEMM_REF="${DEEP_GEMM_REF:-88965b0}"

DO_VERIFY=0
DO_DEEP_GEMM=0
for arg in "$@"; do
  case "${arg}" in
    --verify) DO_VERIFY=1 ;;
    --deep-gemm) DO_DEEP_GEMM=1 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown arg: ${arg}" >&2; exit 2 ;;
  esac
done

if [[ ${DO_VERIFY} -eq 1 ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/scripts/env.sh"
  bash "${ROOT}/scripts/verify-env.sh"
  exit $?
fi

echo "=== B-Env setup (GLM-5.2 / B200) ==="
echo "  venv target = ${VENV}"
echo "  operator root = ${SGLANG_EXP_ROOT}"
echo

mkdir -p "$(dirname "${VENV}")"

if [[ ! -d "${VENV}" ]]; then
  if command -v uv >/dev/null 2>&1; then
    echo ">>> Creating venv with uv..."
    uv venv "${VENV}" --python 3.12
  else
    echo ">>> Creating venv with python3.12..."
    python3.12 -m venv "${VENV}"
  fi
else
  echo ">>> Venv exists: ${VENV}"
fi

PY="${VENV}/bin/python3"
PIP="${PY} -m pip"

echo ">>> Upgrading pip..."
${PIP} install -U pip setuptools wheel

echo ">>> Installing torch 2.11.0+cu130..."
${PIP} install torch==2.11.0 torchvision torchaudio --index-url "${TORCH_INDEX}"

echo ">>> Installing requirements..."
${PIP} install -r "${ROOT}/scripts/requirements-glm52-b200.txt"

# Optional: symlink .venv into sibling workspaces (set WORKSPACE_VENV_LINKS in paths.env)
# Example in paths.env:
#   WORKSPACE_VENV_LINKS="ws-b ws-c ws-d"   # each gets .venv -> shared VENV_ROOT
if [[ -n "${WORKSPACE_VENV_LINKS:-}" && -d "${SGLANG_EXP_ROOT:-}" ]]; then
  for ws in ${WORKSPACE_VENV_LINKS}; do
    LINK="${SGLANG_EXP_ROOT}/${ws}/.venv"
    if [[ -d "${SGLANG_EXP_ROOT}/${ws}" ]]; then
      ln -sfn "${VENV}" "${LINK}"
      echo ">>> Linked ${ws}/.venv -> ${VENV}"
    fi
  done
fi

if [[ ${DO_DEEP_GEMM} -eq 1 ]]; then
  echo ">>> Building deep_gemm from ${DEEP_GEMM_REPO}..."
  BUILD_DIR="$(mktemp -d)"
  git clone --depth 1 "${DEEP_GEMM_REPO}" "${BUILD_DIR}/DeepGEMM"
  cd "${BUILD_DIR}/DeepGEMM"
  git fetch --depth 1 origin "${DEEP_GEMM_REF}" 2>/dev/null || true
  git checkout "${DEEP_GEMM_REF}" 2>/dev/null || true
  ${PIP} install -e .
  cd "${ROOT}"
  rm -rf "${BUILD_DIR}"
fi

bash "${ROOT}/scripts/verify-env.sh" || true

echo
echo "Done. Next: source ${ROOT}/scripts/env.sh <workspace-name>"
