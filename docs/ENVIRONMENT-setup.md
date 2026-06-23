# GLM-5.2 算子优化环境部署指南

> 脚本入口：`../scripts/setup-env.sh` · `../scripts/env.sh` · `../scripts/verify-env.sh`

---

## 1. 三档测试需求

| 档位 | 测试 | 最低环境 |
|------|------|----------|
| **Tier A** | L1 harness（正确性 + micro-bench） | torch + CUDA |
| **Tier B** | L1.5 SGLang smoke（patch + flag） | Tier A + live SGLang 树 |
| **Tier C** | L3 Engine、FP8 DeepGEMM、CUDA graph、tcgen05 | Tier B + 完整版本栈（见 README） |

四个算子工作区（`sglang-exp/glm52-*-opt/`）**共用一个 venv**，不要各自独立安装。

---

## 2. 部署步骤

### 2.1 配置路径

```bash
cp config/paths.env.example config/paths.env
# 编辑 SGlang_PYTHON、SGLANG_EXP_ROOT、VENV_ROOT
```

### 2.2 安装

```bash
bash scripts/setup-env.sh              # torch 2.11 cu130 + 依赖
bash scripts/setup-env.sh --deep-gemm  # deep_gemm 源码编译（FP8 必需）
bash scripts/verify-env.sh             # 健康检查
```

### 2.3 每次开工

```bash
source scripts/env.sh glm52-index-k-opt   # 第二个参数换工作区名
cd $GLM52_WORKSPACE
scripts/verify_phase*.sh --quick
```

---

## 3. deep_gemm 源码安装

pip wheel 可能与 torch ABI 不匹配。推荐：

```bash
source scripts/env.sh
git clone https://github.com/deepseek-ai/DeepGEMM.git /tmp/DeepGEMM
cd /tmp/DeepGEMM && git checkout 88965b0
pip install -e .
python -c "import deep_gemm, torch; print(deep_gemm.__version__, torch.__version__)"
```

Index_K FP8 必须 `use_ue8m0=True`，否则 DeepGEMM 输出 NaN。

---

## 4. SGLang live 树 patch

环境装好后，还需把 patch 打到 live 树（各工作区 `patches/` + `docs/sglang_integration.md`）：

```bash
export SGlang_PYTHON=~/sglang/python
cd $SGlang_PYTHON
patch -p0 < ~/sglang-exp/glm52-moe-router-opt/patches/phase1_p1_moe_router_hook.patch
```

四工作区并行时，共用 `dsa_indexer.py` 需协调；verify 脚本检查 `sglang_dsa_hash`。

---

## 5. L3 端到端（MoE Router）

| 资源 | 大小 |
|------|------|
| GLM-5.2-FP8 全量 | ~704 GiB（本机可能放不下） |
| 合成 mini 模型 | ~25 GiB BF16（`gen_synth_model.py`） |

L3 需要 torch 2.11 + sgl_kernel 0.4.4 + SGLang Engine：

```bash
export SGLANG_SKIP_SGL_KERNEL_VERSION_CHECK=1   # env.sh 已默认设置
scripts/verify_phase2_l3.sh
```

合成模型限制：`disable_cuda_graph=True` + triton attention，与生产 flashinfer 不完全可比。

---

## 6. Index_Q Phase 5（tcgen05）

额外需要：

- `nvidia-cutlass-dsl==4.6.0.dev0+cu13`
- CUDA toolkit 13.x
- **nvrtc** 编译 DeepGEMM 特化（不要用 nvcc — ptxas 拒绝 sm_100 tcgen05）
- CuTe-DSL 高层 API 可能需要 CUDA 13.1+ build

---

## 7. Codex 审查环境

```bash
# 1. 启动 codex-transfer（见 examples/codex-transfer.config.example.json）
curl -s http://127.0.0.1:4446/health

# 2. ~/.codex/config.toml 指向本地代理（见 examples/codex.config.example.toml）
# 3. sandbox_mode = "danger-full-access" 若 bwrap 报 RTM_NEWADDR
```

---

## 8. 升级 torch 后的回归

```bash
for ws in glm52-kernel-opt glm52-index-k-opt glm52-index-score-opt glm52-moe-router-opt; do
  source scripts/env.sh "$ws"
  bash scripts/verify-env.sh
  # 各工作区 verify_phase*.sh --quick
done
```

详见 [ENVIRONMENT-issues.md](ENVIRONMENT-issues.md)。
