---
name: rvv-kernel-loop
description: 在单个 <pkg>-rvv 工程里推进 RVV 内核移植的迭代循环。当需要决定"下一个写哪个内核"、把一个 SSE/NEON 路径改成 RVV、排查位精确失配、或判断是否可以收手（G3→G4）时使用。
---

# 单工程内核迭代循环

目标：每轮只动**一个内核**，且每轮结束时既有正确性证据，也有性能数字。
顺序不能跳：没有 B 侧数字的"优化"不算优化。

## 每轮七步（固定顺序）

1. **确认热点**：用 `perf record`、上游 profile 开关或 `-finstrument-functions` 拿到占比。
   占比 <5% 的内核不写，写进 `docs/plan.md` 的"不做"清单。
2. **读参照实现**：找到该内核在 x86（SSE/AVX）或 NEON 侧的实现，弄清它的**语义契约**
   （饱和？舍入？尾部？对齐要求？），写成一句话贴进 `docs/perf-log.md` 的备注。
3. **抄标量参照**：把上游 C 版函数逐字复制进 `test/diff_kernels.c` 的 `scalar_*`，
   不改类型、不改循环边界。参照一旦被"顺手优化"，后面所有比较都失效。
4. **写 RVV 实现**：放在 `src/<lib>/rvv/<module>_rvv.c`，通过 `PROJECT_SRC_DIR`/宏开关接到
   上游调用点（`OVERRIDE_*` 或 dispatch 表）。先求对，再求快。
5. **跑差分**：`cmake --build build/riscv64 && ./build/riscv64/diff_kernels`。
   必须覆盖：小尺寸、非 2 的幂、VL 边界、多组种子、越界哨兵。
6. **跑 paired 基准**：`./benchmark/pair_bench.sh`，A/B 交替 ≥5 次取中位。
   把 A、B、比值、规模写进 `docs/perf-log.md` 一行。
7. **回归门禁**：`./test/run_ab.sh` 必须全 PASS。任何 FAIL 优先修，不要先追性能。

## 判定"这个内核可以放下"

- 差分全 PASS（含哨兵）且 `run_ab.sh` 全 PASS；
- 单内核收益 ≥5%，或已证明收益上限 <5%（写理由）；
- 无 RVV 目标能安全回退。

三条都满足才进下一个内核；否则留在本轮，写进 `docs/rvv-notes.md` 的待查清单。

## 失配排查顺序（省时间的顺序）

1. **只看第一个失配元素**：打印 index、scalar 值、vector 值、输入上下文。
2. **长度边界**：把 n 换成 VL 整数倍 / VL±1，看是否只在尾部错 → 多半是 `vl` 算错。
3. **符号/宽度**：把 `u`/`i` 类型写反、SEW 写错（`e16` vs `e32`）都会安静地错。
4. **饱和与舍入**：检查是否该用 `vsadd/vssub`、`vnclip`、`vssra`（带舍入的算术右移）。
5. **mask 语义**：`vmerge` 的 true/false 顺序，`vcompress` 的索引顺序。
6. **越界写**：看哨兵是否被踩——这通常不是算法错，是 `vse` 的 `vl` 用了 `vlmax`。

## 性能排查顺序

1. `vsetvl` 是否在循环内、是否每次都用 `n-i`；
2. LMUL 是否合适（窄数据先用 m1/m2，别一上来 m8；m8 会增加寄存器压力）；
3. 是否有多余的 `vmv`/跨 LMUL 转换；
4. 访存模式：`vlse` → 能否改成预重排 + `vle`；
5. 依赖链：累加器是否单链（拆 2/4 条独立链）；
6. 分支：循环内是否有可外提的条件。

## 禁止事项

- 不得为了通过 A/B 而修改 `baseline/`；
- 不得关闭 `RVV_KERNELS` 做"对比"（那是 B 侧的配置，不是 A 的）；
- 不得在 qemu 上得出的数字写进 `perf-log.md` 当结论（只能标"功能验证"）；
- 不得在 `src/` 里留调试打印、临时断点、`#if 0` 大段代码。

## 收手（G4）判据

覆盖度 ≥80%，且剩余热点经剖析属于"串行依赖/分支密集/收益 <5%"；把这些写进
`docs/plan.md` 的停止条件段和 `docs/perf-log.md` 的收敛分析段，然后推进 G4 评审。
