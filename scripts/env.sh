#!/usr/bin/env bash
# Source in every shell session for GLM-5.2 B200 operator optimization.
#
#   source /path/to/B-Env/scripts/env.sh
#   source /path/to/B-Env/scripts/env.sh glm52-moe-router-opt
#
# Optional arg: workspace name under $SGLANG_EXP_ROOT (default: glm52-kernel-opt)

set -euo pipefail

_B_ENV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load machine-specific paths
if [[ -f "${_B_ENV_ROOT}/config/paths.env" ]]; then
  # shellcheck disable=SC1091
  source "${_B_ENV_ROOT}/config/paths.env"
elif [[ -f "${_B_ENV_ROOT}/config/paths.env.example" ]]; then
  # shellcheck disable=SC1091
  source "${_B_ENV_ROOT}/config/paths.env.example"
fi

_WS_NAME="${1:-glm52-kernel-opt}"
export SGLANG_EXP_ROOT="${SGLANG_EXP_ROOT:-${HOME}/sglang-exp}"
export GLM52_WORKSPACE="${SGLANG_EXP_ROOT}/${_WS_NAME}"
export SGlang_PYTHON="${SGlang_PYTHON:-${HOME}/sglang/python}"
export VENV_ROOT="${VENV_ROOT:-${SGLANG_EXP_ROOT}/glm52-kernel-opt/.venv}"

if [[ -f "${VENV_ROOT}/bin/activate" ]]; then
  # shellcheck disable=SC1091
  source "${VENV_ROOT}/bin/activate"
fi
export PATH="${VENV_ROOT}/bin:${PATH}"

export PYTHONPATH="${SGlang_PYTHON}:${GLM52_WORKSPACE}:${PYTHONPATH:-}"
export SGLANG_SKIP_SGL_KERNEL_VERSION_CHECK="${SGLANG_SKIP_SGL_KERNEL_VERSION_CHECK:-1}"
export CODEX_API_BASE="${CODEX_API_BASE:-http://127.0.0.1:4446/v1}"
export CUDA_DEVICE_ORDER=PCI_BUS_ID

if [[ -n "${NCU_ROOT:-}" && -d "${NCU_ROOT}" ]]; then
  export PATH="${NCU_ROOT}:${PATH}"
fi

echo "B-Env loaded:"
echo "  B-Env root  = ${_B_ENV_ROOT}"
echo "  workspace   = ${GLM52_WORKSPACE}"
echo "  SGlang_PYTHON = ${SGlang_PYTHON}"
echo "  venv        = ${VENV_ROOT}"
echo "  python      = $(command -v python3 2>/dev/null || echo 'not found')"
echo "  torch       = $(python3 -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'N/A')"
