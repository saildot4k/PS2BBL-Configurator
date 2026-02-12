#include "devices/pad.h"
#include <kernel.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static char padBuf[256] __attribute__((aligned(64)));

int port, slot;

struct padButtonStatus readPad(int port, int slot) {
  struct padButtonStatus buttons;
  int ret;

  do {
    ret = padGetState(port, slot);
  } while ((ret != PAD_STATE_STABLE) && (ret != PAD_STATE_FINDCTP1));

  ret = padRead(port, slot, &buttons);

  return buttons;
}

int isButtonPressed(uint32_t button) {
  int ret;
  uint32_t paddata;

  struct padButtonStatus padbuttons;

  while (((ret = padGetState(0, 0)) != PAD_STATE_STABLE) && (ret != PAD_STATE_FINDCTP1) && (ret != PAD_STATE_DISCONN))
    ; // more error check ?
  if (padRead(0, 0, &padbuttons) != 0) {
    paddata = 0xffff ^ padbuttons.btns;
    if (paddata & button)
      return 1;
  }
  return 0;
}

void pad_init() {
  printf("devices_pad: initializing\n");
  int ret;

  padInit(0);

  port = 0; // 0 -> Connector 1, 1 -> Connector 2
  slot = 0; // Always zero if not using multitap

  if ((ret = padPortOpen(port, slot, padBuf)) == 0) {
    printf("devices_pad: padOpenPort failed: %d\n", ret);
    SleepThread();
  }
}

void pad_deinit(void) {
  printf("devices_pad: closing\n");
  padPortClose(port, slot);
  padEnd();
}
