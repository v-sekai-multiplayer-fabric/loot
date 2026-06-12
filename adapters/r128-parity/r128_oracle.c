#define R128_IMPLEMENTATION
#define R128_STDC_ONLY
#include "r128.h"
#include <stdio.h>
int main(int argc, char **argv) {
  FILE *f = fopen(argv[1], "r"); if (!f) { perror("open"); return 2; }
  char hdr[600]; if (!fgets(hdr, sizeof hdr, f)) return 2;
  const char *names[7] = {"add","sub","neg","mul","cmp","shl","shr"};
  long bad[7] = {0}, firstbad[7]; for (int i = 0; i < 7; i++) firstbad[i] = -1;
  unsigned long long alo,ahi,blo,bhi, ea_lo,ea_hi,es_lo,es_hi,en_lo,en_hi,em_lo,em_hi,el_lo,el_hi,er_lo,er_hi;
  unsigned amt; long long ecmp; long n = 0;
  while (fscanf(f, "%llu,%llu,%llu,%llu,%u,%llu,%llu,%llu,%llu,%llu,%llu,%llu,%llu,%lld,%llu,%llu,%llu,%llu\n",
      &alo,&ahi,&blo,&bhi,&amt,&ea_lo,&ea_hi,&es_lo,&es_hi,&en_lo,&en_hi,&em_lo,&em_hi,&ecmp,&el_lo,&el_hi,&er_lo,&er_hi) == 18) {
    R128 a, b, r; a.lo = alo; a.hi = ahi; b.lo = blo; b.hi = bhi;
    r128Add(&r,&a,&b); if (r.lo!=ea_lo||r.hi!=ea_hi) { if(firstbad[0]<0)firstbad[0]=n; bad[0]++; }
    r128Sub(&r,&a,&b); if (r.lo!=es_lo||r.hi!=es_hi) { if(firstbad[1]<0)firstbad[1]=n; bad[1]++; }
    r128Neg(&r,&a);    if (r.lo!=en_lo||r.hi!=en_hi) { if(firstbad[2]<0)firstbad[2]=n; bad[2]++; }
    r128Mul(&r,&a,&b); if (r.lo!=em_lo||r.hi!=em_hi) { if(firstbad[3]<0)firstbad[3]=n; bad[3]++; }
    int c = r128Cmp(&a,&b); int cs = c<0?-1:(c>0?1:0); if (cs != ecmp) { if(firstbad[4]<0)firstbad[4]=n; bad[4]++; }
    r128Shl(&r,&a,(int)amt); if (r.lo!=el_lo||r.hi!=el_hi) { if(firstbad[5]<0)firstbad[5]=n; bad[5]++; }
    r128Shr(&r,&a,(int)amt); if (r.lo!=er_lo||r.hi!=er_hi) { if(firstbad[6]<0)firstbad[6]=n; bad[6]++; }
    n++;
  }
  long tot = 0; for (int i = 0; i < 7; i++) tot += bad[i];
  printf("checked %ld vectors x 7 ops\n", n);
  for (int i = 0; i < 7; i++) printf("  %-4s mismatches: %ld%s\n", names[i], bad[i], bad[i] ? "   <-- FAIL" : "");
  if (tot == 0) { printf("R128 PARITY PASS: Lean R128 == vendored r128.c on all %ld vectors\n", n); return 0; }
  return 1;
}
