/* 内核差分测试登记表。
 *
 * 每个内核一行 RVV_DIFF。这里给两个可直接跑通的示例，之后把示例替换成
 * 本包的 RVV 内核（标量参照必须是上游原函数的逐字拷贝，不要改造）。
 *
 * 纪律：
 *  1. 参照实现抄上游 C 版，不改语义、不改类型；
 *  2. 被测实现调 src/ 里的 rvv 版本，不要在测试里另写一份"看起来一样"的；
 *  3. 定点内核必须逐字节相等；浮点内核用误差口径（见 docs/06-acceptance）。
 */
#include "rvv_diff.h"

#include <stdint.h>

#if defined(__riscv_vector)
#include <riscv_vector.h>
#endif

/* ---------------------------------------------------------------- 输入生成 */
static uint32_t lcg(uint32_t *s) { *s = *s * 1664525u + 1013904223u; return *s; }

/* 约定：buf 有 2*n 个元素，两个操作数各占 n 个。 */
static void gen_s16(void *buf, size_t n, unsigned seed)
{
    int16_t *p = (int16_t *)buf;
    uint32_t s = seed;
    size_t i;
    for (i = 0; i < 2 * n; i++)
        p[i] = (int16_t)(lcg(&s) & 0xFFFFu);
}

static void gen_u8(void *buf, size_t n, unsigned seed)
{
    uint8_t *p = (uint8_t *)buf;
    uint32_t s = seed;
    size_t i;
    for (i = 0; i < 2 * n; i++)
        p[i] = (uint8_t)(lcg(&s) & 0xFFu);
}

/* ------------------------------------------------- 示例 1：int16 饱和加法 */
static void scalar_s16_add_sat(const void *in, void *out, size_t n)
{
    const int16_t *a = (const int16_t *)in;
    const int16_t *b = a + n;
    int16_t *o = (int16_t *)out;
    size_t i;
    for (i = 0; i < n; i++) {
        int32_t v = (int32_t)a[i] + (int32_t)b[i];
        if (v > 32767) v = 32767;
        if (v < -32768) v = -32768;
        o[i] = (int16_t)v;
    }
}

/* -------------------------------------------------- 示例 2：uint8 右移 2 位 */
static void scalar_u8_shr2(const void *in, void *out, size_t n)
{
    const uint8_t *a = (const uint8_t *)in;
    uint8_t *o = (uint8_t *)out;
    size_t i;
    for (i = 0; i < n; i++)
        o[i] = (uint8_t)(a[i] >> 2);
}

#if defined(__riscv_vector)
static void vec_s16_add_sat(const void *in, void *out, size_t n)
{
    const int16_t *a = (const int16_t *)in;
    const int16_t *b = a + n;
    int16_t *o = (int16_t *)out;
    size_t i = 0;
    while (i < n) {
        size_t vl = __riscv_vsetvl_e16m2(n - i);   /* vsetvl 放循环内，尾块靠它收敛 */
        vint16m2_t va = __riscv_vle16_v_i16m2(a + i, vl);
        vint16m2_t vb = __riscv_vle16_v_i16m2(b + i, vl);
        __riscv_vse16_v_i16m2(o + i, __riscv_vsadd_vv_i16m2(va, vb, vl), vl);
        i += vl;
    }
}

static void vec_u8_shr2(const void *in, void *out, size_t n)
{
    const uint8_t *a = (const uint8_t *)in;
    uint8_t *o = (uint8_t *)out;
    size_t i = 0;
    while (i < n) {
        size_t vl = __riscv_vsetvl_e8m1(n - i);
        vuint8m1_t va = __riscv_vle8_v_u8m1(a + i, vl);
        __riscv_vse8_v_u8m1(o + i, __riscv_vsrl_vx_u8m1(va, 2, vl), vl);
        i += vl;
    }
}

#define IMPL_s16_add_sat vec_s16_add_sat
#define IMPL_u8_shr2     vec_u8_shr2
#else
/* 非 RVV 目标（本机自检）：被测实现退化为标量，门禁仍可运行。 */
#define IMPL_s16_add_sat scalar_s16_add_sat
#define IMPL_u8_shr2     scalar_u8_shr2
#endif

RVV_DIFF(s16_add_sat, 2, gen_s16, scalar_s16_add_sat, IMPL_s16_add_sat)
RVV_DIFF(u8_shr2, 1, gen_u8, scalar_u8_shr2, IMPL_u8_shr2)

RVV_DIFF_MAIN()
