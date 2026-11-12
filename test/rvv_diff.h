/* 内核差分测试框架（通用，不含任何包私有逻辑）。
 *
 * 用法：在 diff_kernels.c 里为每个内核登记一条
 *     RVV_DIFF(名字, n, 元素字节数, 输入生成器, 标量参照, RVV 实现)
 *
 * 缓冲区约定（避免为每个内核单独设计签名）：
 *   in : 2*n 个元素。前 n 个是操作数 1，后 n 个是操作数 2（单目内核只用前半）。
 *   out: n 个元素。框架会在 out 之后放 64 字节哨兵，用来抓越界写。
 *
 * 框架自动覆盖：长度集合（含非 VL 整数倍的尾巴）× 多组种子 × 越界哨兵。
 * 只比较"逐字节相等"，因此同时适用于定点、密码、编解码类内核。
 */
#ifndef RVV_DIFF_H
#define RVV_DIFF_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*kdiff_fn)(const void *in, void *out, size_t n);
typedef void (*kdiff_gen)(void *buf, size_t n, unsigned seed);

typedef struct {
    const char *name;
    size_t esz;         /* 单元素字节数 */
    kdiff_gen gen;      /* 确定性输入生成，填满 2*n 个元素 */
    kdiff_fn scalar;    /* 参照实现（要求逐字节可信） */
    kdiff_fn vector;    /* 被测实现 */
} rvv_diff_case;

void rvv_diff_register(const rvv_diff_case *c);

/* 声明并自动登记（依赖 constructor 属性；gcc/clang 均支持） */
#define RVV_DIFF(tag, esz_, gen_, scalar_, vector_)                        \
    static const rvv_diff_case rvv_case_##tag = {                          \
        #tag, (esz_), (gen_), (scalar_), (vector_)};                       \
    __attribute__((constructor)) static void rvv_reg_##tag(void)           \
    { rvv_diff_register(&rvv_case_##tag); }

/* 入口：跑全部已登记内核。返回 0 = 全通过；非 0 = 有失配（打印细节）。 */
int rvv_diff_main(int argc, char **argv);

#define RVV_DIFF_MAIN() \
    int main(int argc, char **argv) { return rvv_diff_main(argc, argv); }

#ifdef __cplusplus
}
#endif
#endif /* RVV_DIFF_H */
