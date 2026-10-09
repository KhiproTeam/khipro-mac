#include <stdio.h>
#include <string.h>
#include "khipro/khipro.h"
int main(int c,char**v){FILE*f=fopen(v[1],"r");char l[512],o[512];int n=0,bad=0;khipro_variant var=c>2?1:0;
fgets(l,512,f);while(fgets(l,512,f)){l[strcspn(l,"\r\n")]=0;char*t=strchr(l,'\t');if(!t)continue;*t++=0;
khipro_convert(var,l,o,512);n++;if(strcmp(o,t)){if(bad++<5)printf("FAIL %s => %s want %s\n",l,o,t);}}
printf("%d cases, %d failed\n",n,bad);return bad!=0;}
