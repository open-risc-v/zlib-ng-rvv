# 真机 rvv/cpu A/B 测试：zlib-ng（首轮）

- 真机：`10.91.8.28`，K3（rv64imafdcvh + RVV 1.0，`zve64d/zvbb/zvkb/zvkned…`），8 核，15GB
- 工具链：Bianbu gcc 15.2.0（**带 `riscv_vector.h`**，这是交叉 gcc 11/12 缺的东西）
- 上游：`github.com/zlib-ng/zlib-ng` @ `6727d88`
- 双侧同源、同 `-O2`，唯一变量是 ISA：`-march=rv64gc`（cpu）vs `-march=rv64gcv -DWITH_RVV=ON`（rvv）

## 1. 是否真的用了向量指令

`objdump -d libz-ng.a | grep -c vsetvli`：

| 产物 | vsetvli | vle*.v |
|---|---|---|
| build/cpu/libz-ng.a | 0 | 0 |
| build/rvv/libz-ng.a | 65 | 29 |

configure 阶段识别 `HAVE_RVV_INTRIN - Success`，编入 `arch/riscv/{adler32,chunkset,compare256,slide_hash}_rvv.c` 与 `crc32_zbc.c`。

## 2. 功能一致性（先于性能）

16 MiB 半可压缩文本（seed=7），`minigzip -6 -c`：

- cpu 输出 825552 字节，rvv 输出 825552 字节
- sha256 前 16 位两侧相同：`2e84d928499a0fdf`

判定：**逐字节一致**，RVV 内核没有改变码流。

## 3. 性能（同机交替跑 3 轮取中位，16 MiB）

| 用例 | cpu | rvv | 比值 |
|---|---|---|---|
| 压缩 `-6` | 396 / 399 / 396 ms | 280 / 277 / 278 ms | **1.42x（rvv 快）** |
| 解压 | 26 / 26 / 26 ms | 32 / 32 / 34 ms | 0.81x（rvv 慢 17%） |

压缩侧收益来自 `chunkset_rvv` + `adler32_rvv`（-6 的主要开销在 match 查找后的 checksum 与 chunk 拷贝）；
解压侧 zlib-ng 的 RVV `chunkset` 在 32KB 窗口下反而多了一次 vsetvl 切换，值得下一轮改成
`vsetvli` 一次设定 + `vle8.v` 批量拷贝，或直接回退到标量 inflate 快路径。

## 4. 结论与下一步

- 真机链路已打通：clone → fetch-upstream → 双配置构建 → 逐字节比对 → 计时，全程在设备上完成。
- 这是本项目第一个**真机 rvv/cpu 性能数字**（此前所有数字都来自 qemu，不能当性能）。
- 下一轮：把 `chunkset_rvv` 的解压路径做一次调优（单内核、单独提交），再把同一套流程推到 libpng / pixbuf 类包。
