/* 内核差分测试框架实现，见 rvv_diff.h 的约定。 */
#include "rvv_diff.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_CASES 128
#define GUARD 64
#define GUARD_BYTE 0x5Au

static const rvv_diff_case *g_cases[MAX_CASES];
static int g_ncases;
static long g_comparisons;

void rvv_diff_register(const rvv_diff_case *c)
{
    if (g_ncases < MAX_CASES)
        g_cases[g_ncases++] = c;
}

/* 长度集合：小尺寸 + 非 2 的幂 + 可能的 VL 整数倍边界。
 * 真正的最佳覆盖由 cpu_probe 报出的 VLEN 决定；这里只用通用集合，
 * 让同一套测试在任何 VLEN 上都能跑到"边界附近"。 */
static const size_t SIZES[] = {1, 3, 7, 8, 15, 16, 17, 31, 33, 63, 64, 65, 127, 129, 255, 256, 257};
#define NSIZES (sizeof(SIZES) / sizeof(SIZES[0]))
static const unsigned SEEDS[] = {1u, 7u, 12345u};
#define NSEEDS (sizeof(SEEDS) / sizeof(SEEDS[0]))

int rvv_diff_main(int argc, char **argv)
{
    int i, s, k, failures = 0;

    if (g_ncases == 0) {
        printf("diff: 没有登记任何内核（在 diff_kernels.c 里用 RVV_DIFF 登记）\n");
        return 2;
    }

    for (i = 0; i < g_ncases; i++) {
        const rvv_diff_case *c = g_cases[i];
        int case_fail = 0;

        for (s = 0; s < (int)NSIZES; s++) {
            for (k = 0; k < (int)NSEEDS; k++) {
                size_t n = SIZES[s];
                size_t in_bytes = 2 * n * c->esz;
                size_t out_bytes = n * c->esz;
                unsigned char *in = malloc(in_bytes ? in_bytes : 1);
                unsigned char *o_s = malloc(out_bytes + GUARD);
                unsigned char *o_v = malloc(out_bytes + GUARD);
                size_t j;

                if (!in || !o_s || !o_v) {
                    printf("diff: OOM at n=%zu\n", n);
                    return 3;
                }
                c->gen(in, n, SEEDS[k]);

                memset(o_s, GUARD_BYTE, out_bytes + GUARD);
                memset(o_v, GUARD_BYTE, out_bytes + GUARD);

                c->scalar(in, o_s, n);
                c->vector(in, o_v, n);
                g_comparisons++;

                if (memcmp(o_s, o_v, out_bytes) != 0) {
                    size_t bad = 0;
                    for (j = 0; j < out_bytes; j++)
                        if (o_s[j] != o_v[j]) { bad = j; break; }
                    printf("FAIL %s n=%zu seed=%u: 首处失配 byte %zu (elem %zu): "
                           "scalar=0x%02x vector=0x%02x\n",
                           c->name, n, SEEDS[k], bad, bad / c->esz,
                           o_s[bad], o_v[bad]);
                    case_fail = 1;
                }
                for (j = out_bytes; j < out_bytes + GUARD; j++) {
                    if (o_v[j] != GUARD_BYTE) {
                        printf("FAIL %s n=%zu seed=%u: 越界写 out+%zu\n",
                               c->name, n, SEEDS[k], j - out_bytes);
                        case_fail = 1;
                        break;
                    }
                }
                /* 输出来自向量侧时，标量侧同样要守住哨兵：说明"参照实现"本身没越界 */
                for (j = out_bytes; j < out_bytes + GUARD; j++) {
                    if (o_s[j] != GUARD_BYTE) {
                        printf("WARN %s n=%zu: 参照实现越界（先修参照）\n", c->name, n);
                        break;
                    }
                }

                free(in); free(o_s); free(o_v);
                if (case_fail)
                    break;
            }
            if (case_fail)
                break;
        }

        if (case_fail)
            failures++;
        else
            printf("PASS %s（%zu 组长度 × %zu 组种子）\n", c->name, NSIZES, NSEEDS);
    }

    printf("\ndiff: %d/%d 内核通过，共 %ld 次比较\n",
           g_ncases - failures, g_ncases, g_comparisons);
    return failures == 0 ? 0 : 1;
}
