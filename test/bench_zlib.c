/* zlib-ng 吞吐基准：adler32 校验 + deflate/inflate 回环。
   A（WITH_RVV）/ B（WITH_RVV=OFF）同 -march，真机上交替跑取中位数。 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <zlib.h>

static double now_ns(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec * 1e9 + (double)ts.tv_nsec;
}

int main(int argc, char **argv)
{
	int reps = argc > 1 ? atoi(argv[1]) : 5;
	size_t n = 16u << 20;               /* 16 MiB 数据，超过 cache，测的是内存带宽下的校验吞吐 */
	unsigned char *buf = malloc(n);
	if (!buf) return 2;
	for (size_t i = 0; i < n; i++) buf[i] = (unsigned char)((i * 2654435761u) >> 13);

	double best_ad = 1e30, best_de = 1e30;
	for (int r = 0; r < reps; r++) {
		double t0 = now_ns();
		unsigned long ad = adler32(adler32(0L, Z_NULL, 0), buf, (unsigned int)n);
		double dt = now_ns() - t0;
		if (dt < best_ad) best_ad = dt;
		if (r == 0) printf("adler=%08lx\n", ad);

		/* 取前 1 MiB 做 deflate 回环 */
		size_t m = 1u << 20;
		unsigned char *out = malloc(m * 2);
		if (!out) return 2;
		z_stream zs; memset(&zs, 0, sizeof zs);
		deflateInit(&zs, 6);
		zs.next_in = buf; zs.avail_in = (unsigned int)m;
		zs.next_out = out; zs.avail_out = (unsigned int)(m * 2);
		t0 = now_ns();
		deflate(&zs, Z_FINISH);
		double dt2 = now_ns() - t0;
		if (dt2 < best_de) best_de = dt2;
		if (r == 0) printf("deflate_bytes=%lu\n", (unsigned long)zs.total_out);
		deflateEnd(&zs);
		free(out);
	}
	printf("adler16M_ns=%.0f ns_per_byte=%.3f deflate1M_ns=%.0f\n",
	       best_ad, best_ad / (double)n, best_de);
	free(buf);
	return 0;
}
