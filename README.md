# B-Env — GLM-5.2 / B200 Operator Optimization Environment

Reproducible Python + CUDA + SGLang + Codex environment for optimizing
GLM-5.2 decode operators (Index_Q, Index_K, Index_Score, MoE Router) on
**NVIDIA B200 (sm_100)** with [SGLang](https://github.com/sgl-project/sglang).

Repository: [github.com/qhy991/B-Env](https://github.com/qhy991/B-Env)

**[中文版 README](README.zh-CN.md)** · Model config guide (中文): [docs/INFINI-AI-model-config.md](docs/INFINI-AI-model-config.md)

---

## Quick start

```bash
git clone https://github.com/qhy991/B-Env.git
cd B-Env

# 1. Configure machine paths
cp config/paths.env.example config/paths.env
# edit SGlang_PYTHON, SGLANG_EXP_ROOT, VENV_ROOT

# 2. Install Python stack (requires operator repo cloned separately; set paths in config/paths.env)
bash scripts/setup-env.sh
bash scripts/setup-env.sh --deep-gemm   # Index_Score / FP8 needs this

# 3. Every session
source scripts/env.sh <workspace-name>
bash scripts/verify-env.sh
```

---

## Verified stack (2026-06-22)

| Component | Version |
|-----------|---------|
| Python | 3.12 |
| torch | 2.11.0+cu130 |
| triton | 3.6.0 |
| sglang-kernel | 0.4.4+cu129 |
| deep_gemm | 2.5.0 (source build) |
| flashinfer | 0.6.12 |
| sglang | 0.5.9 |
| nvidia-cutlass-dsl | 4.6.0.dev0+cu13 |
| GPU | NVIDIA B200 |

---

## Repository layout

```
B-Env/
├── README.md
├── config/
│   └── paths.env.example      # Machine paths (copy → paths.env)
├── scripts/
│   ├── setup-env.sh           # One-time bootstrap
│   ├── env.sh                 # Source every session
│   ├── verify-env.sh          # Health check
│   ├── install-codex-transfer.sh
│   ├── start-codex-transfer.sh
│   └── requirements-glm52-b200.txt
├── docs/
│   ├── ENVIRONMENT-setup.md   # Full deployment guide
│   ├── ENVIRONMENT-issues.md  # Known pitfalls from experiments
│   └── INFINI-AI-model-config.md  # Claude + Codex + Infini-AI setup
└── examples/
    ├── claude.settings.example.json
    ├── codex-transfer.config.example.json
    ├── codex-transfer.env.example
    ├── codex.config.example.toml
    └── humanize.config.example.json
```

---

## Related repos (not included)

This repo only manages **environment**. Operator code lives in your local workspace tree (configure `SGLANG_EXP_ROOT` in `config/paths.env`):

- Operator workspaces — one directory per kernel optimization task
- `sglang/python/` or similar — live SGLang source tree (patch target, set `SGlang_PYTHON`)

---

## Test tiers

| Tier | What runs | Requirements |
|------|-----------|--------------|
| **A** | L1 harness (correctness + bench) | torch + CUDA |
| **B** | L1.5 SGLang smoke | Tier A + patched live tree |
| **C** | L3 Engine, FP8, CUDA graph, tcgen05 | Tier B + torch 2.11 + deep_gemm + sgl_kernel |

See [docs/ENVIRONMENT-setup.md](docs/ENVIRONMENT-setup.md) for details.

---

## Codex / Humanize RLCR

Full guide: **[docs/INFINI-AI-model-config.md](docs/INFINI-AI-model-config.md)**

Quick setup for Humanize RLCR with Infini-AI models:

```bash
# 1. Claude Code + Humanize 插件
cp examples/claude.settings.example.json ~/.claude/settings.json   # edit keys + humanize path

# 2. codex-transfer (Codex review bridge)
bash scripts/install-codex-transfer.sh
cp examples/codex-transfer.config.example.json ~/.codex-transfer/config.json
export CODEX_TRANSFER_API_KEY=sk-your-key && bash scripts/start-codex-transfer.sh

# 3. Codex CLI
cp examples/codex.config.example.toml ~/.codex/config.toml

# 4. Per-workspace Humanize override
cp examples/humanize.config.example.json /path/to/workspace/.humanize/config.json

# 5. Verify
curl -s http://127.0.0.1:4446/health
bash scripts/verify-env.sh
```

| Config file | Purpose |
|-------------|---------|
| `~/.claude/settings.json` | Humanize plugin + Infini-AI routing (`env` block) |
| `~/.codex-transfer/config.json` | Upstream URL + modelMap |
| `~/.codex/config.toml` | Codex → local proxy on :4446 |
| `.humanize/config.json` | Review model (`codex_model`) per workspace |

---

## License

MIT
