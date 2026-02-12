#ifndef DEVICES_PAD_H
#define DEVICES_PAD_H

#include <libpad.h>
#include <stdint.h>

void pad_init();
int isButtonPressed(uint32_t button);
void pad_deinit(void);

#endif
