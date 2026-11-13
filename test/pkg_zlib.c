// zlib-ng A/B 探针：def late 压缩 → 解压回环，比对压缩字节与回环一致性。
// 压缩输出必须逐字节确定，否则说明编译器/库行为变了，A/B 结论也就不成立。
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#define N 200003   /* 素数长度，避开 2 的幂与 8/16 的整齐边界 */

static uint64_t fnv1a(const void *p, size_t n)
{
    const uint8_t *b = p;
    uint64_t h = 1469598103934665603ULL;
    for (size_t i = 0; i < n; i++) { h ^= b[i]; h *= 1099511628211ULL; }
    return h;
}

int main(int argc, char **argv)
{
    const char *outz = argc > 1 ? argv[1] : NULL;
    unsigned char *plain = malloc(N), *comp = malloc(N), *back = malloc(N);
    if (!plain || !comp || !back) return 2;

    /* 确定性语料：可压缩但带噪，逼出 match/literal 混合路径 */
    for (size_t i = 0; i < N; i++)
        plain[i] = (unsigned char)((i % 251) ^ ((i / 7) % 13) ^ (i >> 9));

    uLongf clen = N;
    int rc = compress2(comp, &clen, plain, N, 6);
    if (rc != Z_OK) { fprintf(stderr, "compress2=%d\n", rc); return 3; }

    uLongf blen = N;
    rc = uncompress(back, &blen, comp, clen);
    if (rc != Z_OK || blen != N || memcmp(plain, back, N) != 0) {
        fprintf(stderr, "roundtrip failed rc=%d blen=%lu\n", rc, (unsigned long)blen);
        return 4;
    }

    printf("in=%d out=%lu crc=%08x fnv=%016llx\n", N, (unsigned long)clen,
           (unsigned)crc32(0, plain, N), (unsigned long long)fnv1a(comp, clen));

    if (outz) {
        FILE *f = fopen(outz, "wb");
        if (!f) return 5;
        fwrite(comp, 1, clen, f);
        fclose(f);
    }
    free(plain); free(comp); free(back);
    return 0;
}
