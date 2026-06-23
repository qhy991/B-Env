# B-Env — GLM-5.2 / B200 算子优化环境

可复现的 Python + CUDA + SGLang + Codex 环境，用于在 **NVIDIA B200 (sm_100)** 上优化 GLM-5.2 解码算子（Index_Q、Index_K、Index_Score、MoE Router），配合 [SGLang](https://github.com/sgl-project/sglang) 使用。

仓库地址：[github.com/qhy991/B-Env](https://github.com/qhy991/B-Env)

[English README](README.md)

---

## 快速开始

```bash
git clone https://github.com/qhy991/B-Env.git
cd B-Env

# 1. 配置本机路径
cp config/paths.env.example config/paths.env
# 编辑 SGlang_PYTHON、SGLANG_EXP_ROOT、VENV_ROOT

# 2. 安装 Python 栈（需单独 clone sglang-exp 仓库）
bash scripts/setup-env.sh
bash scripts/setup-env.sh --deep-gemm   # Index_Score / FP8 需要

# 3. 每次开新 shell
source scripts/env.sh glm52-moe-router-opt
bash scripts/verify-env.sh
```

---

## 已验证软件栈（2026-06-22）

| 组件 | 版本 |
|------|------|
| Python | 3.12 |
| torch | 2.11.0+cu130 |
| triton | 3.6.0 |
| sglang-kernel | 0.4.4+cu129 |
| deep_gemm | 2.5.0（源码编译） |
| flashinfer | 0.6.12 |
| sglang | 0.5.9 |
| nvidia-cutlass-dsl | 4.6.0.dev0+cu13 |
| GPU | NVIDIA B200 |

---

## 目录结构

```
B-Env/
├── README.md / README.zh-CN.md
├── config/
│   └── paths.env.example      # 本机路径（复制为 paths.env）
├── scripts/
│   ├── setup-env.sh           # 一次性安装
│   ├── env.sh                 # 每次 session source
│   ├── verify-env.sh          # 健康检查
│   ├── install-codex-transfer.sh
│   ├── start-codex-transfer.sh
│   └── requirements-glm52-b200.txt
├── docs/
│   ├── ENVIRONMENT-setup.md       # 完整部署指南
│   ├── ENVIRONMENT-issues.md      # 实验踩坑汇总
│   └── INFINI-AI-model-config.md # Claude + Codex + Infini-AI 配置
└── examples/
    ├── claude.settings.example.json
    ├── codex-transfer.config.example.json
    ├── codex-transfer.env.example
    ├── codex.config.example.toml
    └── humanize.config.example.json
```

---

## 关联仓库（不包含在本仓库内）

本仓库只管理**环境**。算子代码在：

- `sglang-exp/` — 四个算子工作区（`glm52-*-opt/`）
- `sglang/python/` — 线上 SGLang 源码树（打 patch 的目标）

---

## 测试分级

| 级别 | 跑什么 | 依赖 |
|------|--------|------|
| **A** | L1 harness（正确性 + bench） | torch + CUDA |
| **B** | L1.5 SGLang smoke | A + 已 patch 的 live 树 |
| **C** | L3 Engine、FP8、CUDA graph、tcgen05 | B + torch 2.11 + deep_gemm + sgl_kernel |

详见 [docs/ENVIRONMENT-setup.md](docs/ENVIRONMENT-setup.md)。

---

## Codex / Humanize RLCR 模型配置

完整指南：**[docs/INFINI-AI-model-config.md](docs/INFINI-AI-model-config.md)**

Humanize RLCR 使用 Infini-AI 模型的快速配置：

```bash
# 1. Claude Code + Humanize 插件
cp examples/claude.settings.example.json ~/.claude/settings.json   # 填 Key 和 humanize 路径

# 2. codex-transfer（Codex review 桥接）
bash scripts/install-codex-transfer.sh
cp examples/codex-transfer.config.example.json ~/.codex-transfer/config.json
export CODEX_TRANSFER_API_KEY=sk-your-key && bash scripts/start-codex-transfer.sh

# 3. Codex CLI
cp examples/codex.config.example.toml ~/.codex/config.toml

# 4. 工作区 Humanize 覆盖
cp examples/humanize.config.example.json /path/to/workspace/.humanize/config.json

# 5. 验证
curl -s http://127.0.0.1:4446/health
bash scripts/verify-env.sh
```

### 配置文件对照

| 文件 | 作用 |
|------|------|
| `~/.claude/settings.json` | Humanize 插件 + Infini-AI 路由（`env` 块） |
| `~/.codex-transfer/config.json` | 上游 URL + modelMap（模型名映射） |
| `~/.codex/config.toml` | Codex → 本地 `:4446` 代理 |
| `.humanize/config.json` | 每个工作区的 review 模型（`codex_model`） |

### 两条模型链路

```
Claude Code（写代码）
  ~/.claude/settings.json → env.ANTHROPIC_*
  → 直连 https://cloud.infini-ai.com/maas

Codex（review）
  ~/.codex/config.toml → http://127.0.0.1:4446/v1（codex-transfer）
  → https://cloud.infini-ai.com/maas/v1
```

**切换 Claude 模型：** 会话内 `/model glm-5.2`，或改 `settings.json` 里 `env.ANTHROPIC_MODEL`。

**切换 Codex review 模型：** 改工作区 `.humanize/config.json` 的 `codex_model`，或改 `~/.codex-transfer/config.json` 的 `modelMap`。

---

## 许可证

MIT
