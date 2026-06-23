# 实验环境问题汇总

从 GLM-5.2 四算子 Humanize RLCR 实验中沉淀的环境/基础设施问题。

---

## 1. Python 版本链

### torch 2.11 + sgl_kernel ABI（MoE Router L3）

- **现象**：`sgl_kernel 0.4.4` 要求 torch 2.11；旧环境 2.9.1 导致 Engine import 失败
- **处理**：升到 torch 2.11.0+cu130 + sglang-kernel 0.4.4+cu129 + nccl 2.30.7
- **临时**：`SGLANG_SKIP_SGL_KERNEL_VERSION_CHECK=1`

### torch 2.11 兼容性

| 组件 | 问题 |
|------|------|
| DSA indexer deep_gemm | `.data` tensor 上 `set_stride` crash → L3 合成模型用非 DSA 架构 |
| SGLang Fp8LinearMethod | weight-processing 报错（Index_Q Phase 5 待修） |
| DeepGEMM | 需按 torch 2.11 ABI 重编 2.5.0 |

### 共享 venv

四工作区共 `shared/.venv`（见 `config/paths.env` 的 `VENV_ROOT`），升级一处影响全部。

---

## 2. CUDA / 编译工具链

| 问题 | 说明 |
|------|------|
| nvcc 不能编 tcgen05 | ptxas 13.0/13.2 拒绝 sm_100 block-scale；用 **nvrtc** |
| CuTe-DSL CCCL 版本 | nvrtc 编译 10 errors → 升到 cutlass-dsl 4.6.0.dev0+cu13 |
| CUDA 13.1+ | CuTe-DSL experimental API 可能需要更高版本 build |

---

## 3. 磁盘与模型

- GLM-5.2-FP8 全量 **704 GiB**（非 150 GiB）
- 484 GiB 磁盘 → 用 `gen_synth_model.py` 合成 ~25 GiB mini 模型
- flashinfer 0.6.12 不支持合成模型 MLA head dims → L3 退 triton attention

---

## 4. DeepGEMM / FP8

- `use_ue8m0=False` → NaN；必须 `use_ue8m0=True`
- Phase 1 harness 的 `torch.randn()` 对 FP8 太严 → 需 prod-distribution gate（scale=0.02）
- 首次调用有数分钟 JIT warmup

---

## 5. GPU 测量纪律

- **跨 session baseline 漂移**：wk baseline 117µs → 13µs（同机器无代码变更）
- **Triton autotune 不一致**：去掉 `@triton.autotune`，pin 静态参数
- candidate 和 baseline 必须**同 session**对比

---

## 6. Git / 工作区

- **嵌套 git**：子工作区嵌在父 monorepo 里；父仓库 `git clean -fd` 可能删掉子工作区 plan 文件
- **共享 SGLang 树**：兄弟会话改 `dsa_indexer.py` → verify hash 过期
- **RLCR 轮转**：stop-hook reset working tree → 未 commit 文件丢失

---

## 7. Codex / 审查基础设施

| 问题 | 处理 |
|------|------|
| 403 INSUFFICIENT_BALANCE | 切 Infini-AI + codex-transfer |
| 429 Concurrency exceeded | 等 2–5 分钟，减并行 review |
| bwrap RTM_NEWADDR | `sandbox_mode = "danger-full-access"` |
| 502 Bad Gateway | 网关临时故障，重试 |

---

## 8. 推荐升级顺序

```
1. torch 2.11.0+cu130
2. sglang-kernel 0.4.4+cu129
3. deep_gemm 2.5.0（源码）
4. cutlass-dsl 4.6.0.dev0+cu13（Phase 5）
5. 四工作区 verify --quick 回归
6. 同 session 重跑所有 bench
```
