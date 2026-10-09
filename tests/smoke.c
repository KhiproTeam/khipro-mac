#include <stdio.h>
#include "khipro/khipro.h"
int main(void){
  khipro_engine* e = khipro_create(KHIPRO_VARIANT_DEFAULT);
  const char* keys[] = {"a","m","i"};
  for(int i=0;i<3;i++){
    khipro_result r = khipro_feed_key(e, keys[i]);
    printf("key=%s delta='%s' preedit='%s' consumed=%d\n",
      keys[i], r.committed_delta?r.committed_delta:"", r.preedit?r.preedit:"", r.consumed);
  }
  khipro_result c = khipro_commit(e);
  printf("commit delta='%s'\n", c.committed_delta?c.committed_delta:"");
  printf("version=%s lib=%s\n", khipro_version(), khipro_library_version());
  khipro_destroy(e);
  return 0;
}
