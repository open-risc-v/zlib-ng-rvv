# 移植计划 —— `sys-libs/zlib-ng`

> 本文件是**范围与通过标准**的唯一出处。改口径要重走 G0 评审，不允许在 G3 中途放宽。

## 1. 立项信息

| 项 | 值 |
|---|---|
| 包 | `sys-libs/zlib-ng` |
| 上游 | https://github.com/zlib-ng/zlib-ng.git |
| 固定点 | `6727d8837b83e4d09842b86b201c9adf20999079`（） |
| 许可证 | Zlib |
| 难度 | D2 |
| 路径 | 路径 A（A 集成 / B 参照重写 / C 汇编复原 / D 架构重构） |
| 优先级 / 波次 | P0 / W1 |
| 验证口径 | bit-exact |
| 主仓库编号 | {{RVV_ID}} |
| 工期 | 待 G2 后回填（主仓库 `data/plan.csv` 的经验区间） |

## 2. 范围（做什么 / 不做什么）

**要做**（G4 前必须闭环）：

1. 列出上游已有的 SIMD 路径（x86 / NEON），逐项判断"是否有 RVV 对应物"；
2. 覆盖目标机负载画像里占比 ≥80% 的热点内核；
3. 运行期分派：无 RVV 时必须安全回退，不得 SIGILL。

**不做**（写清楚，避免无限扩张）：

- 不重写与 SIMD 无关的算法；
- 不追上游新增的 x86 内核（追平不是目标）；
- 不为了"更干净"重构上游代码结构。

## 3. 目标机与分析前提

```
CPU        : SpacemiT X60 / X100（VLEN=256，rv64gcv_zba_zbb_zbc_zbs_zicond）
工具链     : gcc-14.2 交叉（生产）、gcc-15 / clang-18 对照
基线构建   : 同 -march、RVV_KERNELS=OFF（编译器自动向量化）
```

G2 必须把 `test/cpu_probe` 的输出贴在这里：

```
vlen=
v_intrinsic=
vle_ticks=
vlse_ticks=
vrgather_ticks=
vsetvl_ticks=
```

## 4. 内核清单（G0 先列，G3 逐项填）

| # | 上游实现 | 热点占比 | RVV 方案 | LMUL | 数据类型 | 位精确 | 状态 |
|---|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  | todo |

> 热点占比来源：`perf record` / `-finstrument-functions` / 上游自带 profile 开关。
> 没有占比数据的内核先不要写。

## 5. 门禁与判定

| 门禁 | 判定标准 |
|---|---|
| G1 scaffolded | 骨架可构建；`run_ab.sh` 能跑出 PASS；`cpu_probe` 能出数 |
| G2 baseline-green | 基线数字入库；上游自带测试全绿；内核清单与占比确定 |
| G3 kernels | 每个内核：差分测试 PASS + 单内核加速比 + `perf-log` 一条记录 |
| G4 converged | 覆盖度 ≥80%；剩余热点经剖析证明不可再向量化或收益 <5% |
| G5 upstreamed | 补丁提交上游或明确"本地维护 + rebase 策略" |

**停止条件**（任一满足即收手，不追求满分）：

- 剩余热点都是串行依赖/分支密集，向量化会破坏位精确；
  - 单内核收益 <5%，且实现复杂度 ≥D3；
- 已经达到目标机上的性能目标（见 `docs/06-acceptance.md` 的性能门）。

## 6. 风险

| 风险 | 应对 |
|---|---|
| 工具链对该 intrinsics 组合生成差代码 | 先 probe 再写；必要时落 `.S` |
| 上游大版本变更 | 每季度 rebase 窗口，baseline 与 src 同步升级 |
| 位精确难达成 | 先用"内核差分"定位到单元素，再查饱和/舍入/尾部 |
