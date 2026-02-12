#include <libmc.h>
#include <stdio.h>

int mc_init(void) {
  printf("devices_mc: initializing\n");
  int ret = mcInit(MC_TYPE_XMC);
  if (ret < 0) {
    printf("devices_mc: failed to initialize memcard server.\n");
    return ret;
  }
  return 0;
}

int mc_deinit(void) {
  printf("devices_mc: deinitializing\n");
  mcReset();
  return 0;
}
