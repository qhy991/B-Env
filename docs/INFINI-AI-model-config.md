# Infini-AI 模型配置指南

本文说明如何在 GLM-5.2 算子优化工作流中，通过 **Claude Code（Humanize 执行端）** 和 **Codex（Humanize 审查端）** 使用 Infini-AI GenStudio 上的模型。

适用场景：Humanize RLCR 循环 — Claude 写代码，Codex 做 review。

---

## 架构总览

```
┌─────────────────────────────────────────────────────────────────┐
│  Humanize RLCR 循环                                              │
├──────────────────────────┬──────────────────────────────────────┤
│  Claude Code（执行）      │  Codex CLI（审查 / ask-codex）        │
│  ~/.claude/settings.json │  ~/.codex/config.toml                │
│  （env 块含 ANTHROPIC_*） │  + .humanize/config.json             │
└────────────┬─────────────┴──────────────┬───────────────────────┘
             │                            │
             │ 直连                        │ 本地代理
             ▼                            ▼
   https://cloud.infini-ai.com/maas   http://127.0.0.1:4446/v1
                                      （codex-transfer）
                                             │
                                             ▼
                               https://cloud.infini-ai.com/maas/v1
```

**要点：**

| 组件 | 配置文件 | 作用 |
|------|----------|------|
| Claude Code | `~/.claude/settings.json` | 主 agent + Infini-AI 路由（`env` 块） |
| Codex | `~/.codex/config.toml` | RLCR 每轮 review、ask-codex |
| codex-transfer | `~/.codex-transfer/config.json` | 把 Codex 的 Responses API 转成 Infini-AI 的 Chat Completions |
| Humanize 项目 | `<workspace>/.humanize/config.json` | 指定 review 用的 `codex_model` |

---

## 第一步：获取 Infini-AI API Key

1. 登录 [Infini-AI GenStudio](https://cloud.infini-ai.com/)
2. 在控制台创建 API Key（形如 `sk-xxxxxxxx`）
3. **不要把真实 Key 提交到 git** — 只放在本机环境变量文件里

---

## 第二步：配置 Claude Code（`~/.claude`）

Claude Code 的用户配置在 **`~/.claude/settings.json`**（不是 `~/.claude.json`，后者是运行时状态，不要手改）。

```bash
mkdir -p ~/.claude
cp examples/claude.settings.example.json ~/.claude/settings.json
# 1. 改 extraKnownMarketplaces 里 humanize 插件路径
# 2. 改 env 块里的 sk-your-infini-ai-key-here 为真实 Key
```

### 关键字段

```json
{
  "enabledPlugins": {
    "humanize@PolyArch": true
  },
  "extraKnownMarketplaces": {
    "PolyArch": {
      "source": { "source": "directory", "path": "/path/to/humanize" }
    }
  },
  "env": {
    "ANTHROPIC_BASE_URL": "https://cloud.infini-ai.com/maas",
    "ANTHROPIC_AUTH_TOKEN": "sk-your-infini-ai-key-here",
    "ANTHROPIC_API_KEY": "sk-your-infini-ai-key-here",
    "ANTHROPIC_MODEL": "claude-opus-4-7",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.2",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash",
    "HUMANIZE_CODEX_BYPASS_SANDBOX": "true"
  }
}
```

| 字段 | 说明 |
|------|------|
| `enabledPlugins` | 启用 Humanize 插件 |
| `extraKnownMarketplaces` | 本地 humanize 仓库路径 |
| `env.ANTHROPIC_BASE_URL` | 指向 Infini-AI，**不是** `api.anthropic.com` |
| `env.ANTHROPIC_*_MODEL` | 各档位默认模型 |
| `env.HUMANIZE_CODEX_BYPASS_SANDBOX` | 绕过 Codex bwrap 沙箱（部分主机必须） |

模板：[`examples/claude.settings.example.json`](../examples/claude.settings.example.json)

### 切换 Claude 主模型

**方式 A — 会话内（推荐）：**

```bash
claude
/model glm-5.2          # 或 claude-opus-4-7 / deepseek-v4-pro 等
```

**方式 B — 改 settings.json：**

编辑 `~/.claude/settings.json` 里 `env.ANTHROPIC_MODEL`，重启 Claude Code。

---

## 第三步：安装并启动 codex-transfer

Codex CLI 使用 OpenAI **Responses API**，Infini-AI 提供 **Chat Completions API**。中间需要 `codex-transfer` 做协议转换。

### 安装

```bash
bash scripts/install-codex-transfer.sh
```

或手动：

```bash
mkdir -p ~/.local/codex-transfer ~/.codex-transfer/logs
cd ~/.local/codex-transfer
npm init -y
npm install @classicicn/codex-transfer@^0.4.1
```

### 配置文件

```bash
mkdir -p ~/.codex-transfer
cp examples/codex-transfer.config.example.json ~/.codex-transfer/config.json
```

### `modelMap` 说明

Codex / Humanize 请求里出现的模型名会被映射到 Infini-AI 实际模型：

```json
{
  "modelMap": {
    "gpt-5.5": "glm-5.2",
    "gpt-5.2": "glm-5.2",
    "glm-5.2": "glm-5.2",
    "claude-opus-4-7": "claude-opus-4-7",
    "deepseek-v4-flash": "deepseek-v4-flash",
    "deepseek-v4-pro": "deepseek-v4-pro",
    "*": "glm-5.2"
  }
}
```

| 键 | 含义 |
|----|------|
| 具体模型名 | 精确匹配时替换 |
| `"*"` | 兜底：未匹配到的全部映射到此模型 |

**常见改法：**

- 想让所有 Codex review 走 `glm-5.2`：保持 `"*": "glm-5.2"`
- Humanize 默认 `codex_model: gpt-5.5`，会被映射到 `glm-5.2`（见上表）
- 想 review 走 DeepSeek：改 `"gpt-5.5": "deepseek-v4-pro"` 或改 Humanize 的 `codex_model`

### 启动

```bash
# 方式 A：启动前 export（与 Claude settings 里用同一个 Infini-AI Key）
export CODEX_TRANSFER_API_KEY=sk-your-infini-ai-key-here
bash scripts/start-codex-transfer.sh

# 方式 B：可选 env 文件
mkdir -p ~/.config/humanize
cp examples/codex-transfer.env.example ~/.config/humanize/codex-transfer.env
# 编辑 Key 后：
set -a && source ~/.config/humanize/codex-transfer.env && set +a
bash scripts/start-codex-transfer.sh
```

验证：

```bash
curl -s http://127.0.0.1:4446/health
```

停止：

```bash
kill "$(cat ~/.codex-transfer/logs/codex-transfer.pid)"
```

---

## 第四步：配置 Codex（`~/.codex`）

```bash
mkdir -p ~/.codex
cp examples/codex.config.example.toml ~/.codex/config.toml
```

### 逐项说明

```toml
model_provider = "infini_transfer"   # 使用下面定义的 provider
model = "glm-5.2"                    # 主模型（Codex 直接调用时）
review_model = "glm-5.2"             # review 专用模型
model_reasoning_effort = "high"      # 推理强度：medium / high / xhigh
disable_response_storage = true
network_access = "enabled"

# 部分 Linux 容器/共享主机上 bwrap 沙箱会失败，RLCR review 会 STALL
sandbox_mode = "danger-full-access"

[model_providers.infini_transfer]
name = "Infini-AI GenStudio via codex-transfer"
base_url = "http://127.0.0.1:4446/v1"   # 指向本地 codex-transfer，不是 Infini-AI 直连
wire_api = "responses"
requires_openai_auth = false

[features]
goals = true
hooks = true

[projects."/path/to/workspace"]
trust_level = "trusted"               # RLCR 需要 trusted 项目
```

| 字段 | 改什么 |
|------|--------|
| `model` / `review_model` | Codex 默认模型；也可被 Humanize `codex_model` 覆盖 |
| `model_reasoning_effort` | 推理深度，影响延迟和 review 质量 |
| `base_url` | **必须** 指向 codex-transfer（`:4446`），不要写 Infini-AI 直连 |
| `sandbox_mode` | 沙箱报错时设为 `danger-full-access` |
| `[projects.*]` | 每个 RLCR 工作区路径加一条 `trust_level = "trusted"` |

模板：[`examples/codex.config.example.toml`](../examples/codex.config.example.toml)

---

## 第五步：配置 Humanize 项目（`.humanize/config.json`）

在每个算子工作区（或 monorepo 根）创建：

```bash
mkdir -p .humanize
cp examples/humanize.config.example.json .humanize/config.json
```

```json
{
  "codex_model": "glm-5.2",
  "codex_effort": "high"
}
```

| 字段 | 说明 |
|------|------|
| `codex_model` | RLCR review 轮 Codex 使用的模型名；会经 codex-transfer `modelMap` 映射 |
| `codex_effort` | 传给 Codex 的 reasoning effort |

**优先级：** 工作区 `.humanize/config.json` > Humanize 插件 `config/default_config.json`（默认 `gpt-5.5`）。

若 `codex_model` 设为 `gpt-5.5` 而 `modelMap` 里有 `"gpt-5.5": "glm-5.2"`，实际 upstream 收到的是 `glm-5.2`。

模板：[`examples/humanize.config.example.json`](../examples/humanize.config.example.json)

---

## 第六步：一键验证

```bash
source scripts/env.sh <workspace-name>
bash scripts/verify-env.sh
```

`verify-env.sh` 会检查：

- Python / torch / sgl_kernel 栈
- `curl http://127.0.0.1:4446/health`（codex-transfer）

---

## 常见故障

### 1. Codex review 429 / rate limit

- 降低并行 RLCR 会话数
- review 模型改用 `glm-5.2` 或 `deepseek-v4-flash`（比 opus 便宜）
- 检查 Infini-AI 控制台配额

### 2. `codex-transfer not reachable on :4446`

```bash
bash scripts/start-codex-transfer.sh
curl -s http://127.0.0.1:4446/health
```

确认 `CODEX_TRANSFER_API_KEY` 已 export，或已 source `~/.config/humanize/codex-transfer.env`。

### 3. Codex review STALL（bwrap 沙箱）

```
bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted
```

修复（三选一，建议都做）：

1. `~/.codex/config.toml` → `sandbox_mode = "danger-full-access"`
2. `~/.claude/settings.json` → `"env": { "HUMANIZE_CODEX_BYPASS_SANDBOX": "true" }`
3. shell → `export HUMANIZE_CODEX_BYPASS_SANDBOX=true`

### 4. Claude 仍走 Anthropic 官方而非 Infini-AI

检查 `~/.claude/settings.json` 的 `env` 块：

```json
"ANTHROPIC_BASE_URL": "https://cloud.infini-ai.com/maas"
```

修改后**重启 Claude Code**（settings.json 的 env 在进程启动时注入）。

### 5. Review 用了错误模型

检查链路：

1. `<workspace>/.humanize/config.json` → `codex_model`
2. `~/.codex-transfer/config.json` → `modelMap`
3. `~/.codex/config.toml` → `review_model`

---

## 文件清单（本仓库提供的模板）

| 模板 | 复制到 |
|------|--------|
| `examples/claude.settings.example.json` | `~/.claude/settings.json` |
| `examples/codex-transfer.config.example.json` | `~/.codex-transfer/config.json` |
| `examples/codex-transfer.env.example` | `~/.config/humanize/codex-transfer.env`（可选） |
| `examples/codex.config.example.toml` | `~/.codex/config.toml` |
| `examples/humanize.config.example.json` | `<workspace>/.humanize/config.json` |
| `scripts/install-codex-transfer.sh` | 安装 codex-transfer |
| `scripts/start-codex-transfer.sh` | 启动本地代理 |

---

## 推荐模型搭配（GLM-5.2 算子优化）

| 角色 | 推荐模型 | 配置位置 |
|------|----------|----------|
| Claude 执行（复杂推理） | `claude-opus-4-7` | `~/.claude/settings.json` → `env.ANTHROPIC_MODEL` 或 `/model` |
| Claude 执行（省钱） | `glm-5.2` | `/model glm-5.2` |
| Codex review | `glm-5.2` | `.humanize/config.json` + modelMap |
| BitLesson / 轻量任务 | `deepseek-v4-flash` | Humanize `bitlesson_model` |

此搭配在 B200 算子优化实验中验证可用。
