#!/usr/bin/env bash
# Health check for GLM-5.2 B200 operator environment.
#
#   bash scripts/verify-env.sh
#   bash scripts/verify-env.sh --strict

set -uo pipefail

STRICT=0
[[ "${1:-}" == "--strict" ]] && STRICT=1

PASS=0; FAIL=0; WARN=0
ok()   { echo "  OK   $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL $*"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN $*"; WARN=$((WARN + 1)); }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "${ROOT}/config/paths.env" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/config/paths.env"
else
  # shellcheck disable=SC1091
  source "${ROOT}/config/paths.env.example"
fi

VENV="${VENV_ROOT:-}"
PY="${VENV}/bin/python3"
[[ -x "${PY}" ]] || PY="$(command -v python3 2>/dev/null || true)"

echo "=== B-Env health check ==="

if command -v nvidia-smi >/dev/null 2>&1; then
  GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
  echo "${GPU}" | grep -qi B200 && ok "GPU: ${GPU}" || warn "GPU: ${GPU} (expected B200)"
else
  fail "nvidia-smi not found"
fi

[[ -x "${PY}" ]] || { fail "python not found at ${VENV}"; echo; exit 1; }

check_ver() {
  local name="$1" expect="$2" got
  got=$("${PY}" -c "import ${name}; print(getattr(${name}, '__version__', 'ok'))" 2>/dev/null) || got="IMPORT_FAIL"
  if [[ "${got}" == "${expect}"* ]] || [[ "${got}" == ok ]]; then ok "${name}: ${got}"
  elif [[ "${got}" == IMPORT_FAIL ]]; then fail "${name}: import failed (need ${expect})"
  else warn "${name}: ${got} (expected ${expect})"; fi
}

check_ver torch 2.11.0
check_ver triton 3.6.0
check_ver sgl_kernel 0.4.4
check_ver deep_gemm 2.5.0
check_ver flashinfer 0.6.12

CUTLASS=$("${PY}" -c "import cutlass; print(cutlass.__version__)" 2>/dev/null) || CUTLASS=FAIL
[[ "${CUTLASS}" == 4.6.0.dev0 ]] && ok "cutlass: ${CUTLASS}" || warn "cutlass: ${CUTLASS} (Phase 5 needs 4.6.0.dev0)"

SGL="${SGlang_PYTHON:-}"
if [[ -z "${SGL}" ]]; then
  warn "SGlang_PYTHON not set in config/paths.env"
elif [[ -f "${SGL}/sglang/srt/layers/attention/dsa/dsa_indexer.py" ]]; then
  ok "SGLang tree: ${SGL}"
else
  fail "SGLang tree missing: ${SGL}"
fi

command -v nvcc >/dev/null && ok "nvcc: $(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9.]+' | head -1)" || warn "nvcc not on PATH"
command -v ncu >/dev/null && ok "ncu: $(command -v ncu)" || warn "ncu not on PATH"

curl -sf http://127.0.0.1:4446/health >/dev/null 2>&1 \
  && ok "codex-transfer :4446" || warn "codex-transfer not reachable"

if [[ ${STRICT} -eq 1 ]]; then
  "${PY}" -c "import torch, deep_gemm; assert torch.cuda.is_available()" \
    && ok "deep_gemm + CUDA" || fail "deep_gemm + CUDA"
fi

echo
echo "=== ${PASS} OK, ${WARN} WARN, ${FAIL} FAIL ==="
[[ ${FAIL} -eq 0 ]] || exit 1
