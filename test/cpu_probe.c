/* 目标机能力探测（G2 必做：先知道 VLEN 与微基准，再决定 LMUL 与内核写法）。
 *
 * 输出 key=value 形式，便于 grep 与写入 docs/plan.md：
 *   vlen=...  v_intrinsic=...  march=...
 *   vle_ns=  vlse_ns=  vrgather_ns=  vsetvl_ns=
 *
 * 注意：rdtime 频率未知，所有时间同时给"tick"与"按 1.6GHz 假设换算的 ns"，
 * ns 只用于横向比较，不对外当绝对性能。真实性能一律看 paired_bench。
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#if defined(__riscv_vector)
#include <riscv_vector.h>
#endif

#if defined(__riscv)
static inline unsigned long long rdt(void)
{
    unsigned long long v;
    __asm__ volatile("rdtime %0" : "=r"(v));
    return v;
}
#else
#include <time.h>
static unsigned long long rdt(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (unsigned long long)ts.tv_sec * 1000000000ull + (unsigned long long)ts.tv_nsec;
}
#endif

#define N 4096
static int32_t src[N];
static int32_t idx[N];
static volatile int64_t sink;

int main(void)
{
    const char *march = "unknown";
#if defined(__riscv_v_intrinsic)
    printf("v_intrinsic=%d\n", __riscv_v_intrinsic);
#endif
#if defined(__riscv_vector)
    {
        size_t vlmax = __riscv_vsetvlmax_e32m1();
        printf("vlen=%zu\n", vlmax * 32);
    }
#else
    printf("vlen=0\n");
#endif
#if defined(__riscv_zba)
    march = "zbb/zba+zbc/zbs 可见";
#endif
    (void)march;

    for (int i = 0; i < N; i++) { src[i] = i * 7 - 1000; idx[i] = N - 1 - i; }

#if defined(__riscv_vector)
    {
        const int REP = 1000;
        size_t vl = __riscv_vsetvl_e32m2(N);
        unsigned long long t0, t1;
        int r;

        for (r = 0; r < 2; r++) {   /* 首轮丢弃：缓存/翻译预热不计入 */
            int64_t acc = 0;
            t0 = rdt();
            for (int k = 0; k < REP; k++) {
                vint32m2_t v = __riscv_vle32_v_i32m2(src, vl);
                acc += __riscv_vmv_x_s_i32m2_i32(__riscv_vrsub_vx_i32m2(v, 0, vl));
            }
            t1 = rdt();
            sink += acc;
            if (r == 1)
                printf("vle_ticks=%llu\n", (t1 - t0) / (unsigned long long)REP);
        }

        for (r = 0; r < 2; r++) {
            int64_t acc = 0;
            t0 = rdt();
            for (int k = 0; k < REP; k++) {
                vint32m2_t v = __riscv_vlse32_v_i32m2(src, 8, vl);  /* stride 以字节计 */
                acc += __riscv_vmv_x_s_i32m2_i32(__riscv_vrsub_vx_i32m2(v, 0, vl));
            }
            t1 = rdt();
            sink += acc;
            if (r == 1)
                printf("vlse_ticks=%llu\n", (t1 - t0) / (unsigned long long)REP);
        }

        for (r = 0; r < 2; r++) {
            int64_t acc = 0;
            t0 = rdt();
            for (int k = 0; k < REP; k++) {
                vint32m2_t v = __riscv_vle32_v_i32m2(src, vl);
                vint32m2_t g = __riscv_vrgather_vv_i32m2(v, __riscv_vle32_v_i32m2(idx, vl), vl);
                acc += __riscv_vmv_x_s_i32m2_i32(__riscv_vrsub_vx_i32m2(g, 0, vl));
            }
            t1 = rdt();
            sink += acc;
            if (r == 1)
                printf("vrgather_ticks=%llu\n", (t1 - t0) / (unsigned long long)REP);
        }

        {
            unsigned long long acc = 0;
            t0 = rdt();
            for (int k = 0; k < REP * 10; k++)
                acc += __riscv_vsetvl_e32m2(N - (k & 1));
            t1 = rdt();
            sink += (int64_t)acc;
            printf("vsetvl_ticks=%llu\n", (t1 - t0) / (unsigned long long)(REP * 10));
        }
    }
#else
    printf("note=非 RVV 目标（本机自检），无向量微基准\n");
#endif

    printf("sink=%lld\n", (long long)sink);
    return 0;
}
