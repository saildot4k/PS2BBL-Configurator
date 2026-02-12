#include "devices/pad.h"
#include "lua/player.h"
#include <stdint.h>

static int lua_gettype(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 0 && argc != 1)
    return luaL_error(L, "wrong number of arguments");
  int port = 0;
  if (argc == 1) {
    port = luaL_checkinteger(L, 1);
    if (port > 1)
      return luaL_error(L, "wrong port number.");
  }
  int mode = padInfoMode(port, 0, PAD_MODETABLE, 0);
  lua_pushinteger(L, mode);
  return 1;
}

static int lua_getpad(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 0 && argc != 1)
    return luaL_error(L, "wrong number of arguments");
  int port = 0;
  if (argc == 1) {
    port = luaL_checkinteger(L, 1);
    if (port > 1)
      return luaL_error(L, "wrong port number.");
  }

  padButtonStatus buttons;
  uint32_t paddata = 0;
  int ret;

  int state = padGetState(port, 0);

  if ((state == PAD_STATE_STABLE) || (state == PAD_STATE_FINDCTP1)) {
    ret = padRead(port, 0, &buttons);
    if (ret != 0) {
      paddata = 0xffff ^ buttons.btns;
    }
  }

  lua_pushinteger(L, paddata);
  return 1;
}

static int lua_getleft(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 0 && argc != 1)
    return luaL_error(L, "wrong number of arguments.");
  int port = 0;
  if (argc == 1) {
    port = luaL_checkinteger(L, 1);
    if (port > 1)
      return luaL_error(L, "wrong port number.");
  }

  padButtonStatus buttons;

  int state = padGetState(port, 0);

  if ((state == PAD_STATE_STABLE) || (state == PAD_STATE_FINDCTP1))
    padRead(port, 0, &buttons);

  lua_pushinteger(L, buttons.ljoy_h - 127);
  lua_pushinteger(L, buttons.ljoy_v - 127);
  return 2;
}

static int lua_getright(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 0 && argc != 1)
    return luaL_error(L, "wrong number of arguments.");
  int port = 0;
  if (argc == 1) {
    port = luaL_checkinteger(L, 1);
    if (port > 1)
      return luaL_error(L, "wrong port number.");
  }

  padButtonStatus buttons;

  int state = padGetState(port, 0);

  if ((state == PAD_STATE_STABLE) || (state == PAD_STATE_FINDCTP1))
    padRead(port, 0, &buttons);

  lua_pushinteger(L, buttons.rjoy_h - 127);
  lua_pushinteger(L, buttons.rjoy_v - 127);
  return 2;
}

static int lua_check(lua_State *L) {
  int argc = lua_gettop(L);
  if (argc != 2)
    return luaL_error(L, "wrong number of arguments.");
  int pad = luaL_checkinteger(L, 1);
  int button = luaL_checkinteger(L, 2);
  lua_pushboolean(L, (pad & button));
  return 1;
}

// Register our Screen Functions
static const luaL_Reg Pads_functions[] = {{"get", lua_getpad},      {"getLeftStick", lua_getleft}, {"getRightStick", lua_getright},
                                          {"getType", lua_gettype}, {"check", lua_check},          {0, 0}};

#define LUA_FORWARD_INTMACRO(macro)                                                                                                                  \
  lua_pushinteger(L, macro);                                                                                                                         \
  lua_setglobal(L, #macro)

void luaControls_init(lua_State *L) {
  lua_newtable(L);
  luaL_setfuncs(L, Pads_functions, 0);
  lua_setglobal(L, "Pads");

  LUA_FORWARD_INTMACRO(PAD_SELECT);
  LUA_FORWARD_INTMACRO(PAD_START);
  LUA_FORWARD_INTMACRO(PAD_UP);
  LUA_FORWARD_INTMACRO(PAD_RIGHT);
  LUA_FORWARD_INTMACRO(PAD_DOWN);
  LUA_FORWARD_INTMACRO(PAD_LEFT);
  LUA_FORWARD_INTMACRO(PAD_TRIANGLE);
  LUA_FORWARD_INTMACRO(PAD_CIRCLE);
  LUA_FORWARD_INTMACRO(PAD_CROSS);
  LUA_FORWARD_INTMACRO(PAD_SQUARE);
  LUA_FORWARD_INTMACRO(PAD_L1);
  LUA_FORWARD_INTMACRO(PAD_R1);
  LUA_FORWARD_INTMACRO(PAD_L2);
  LUA_FORWARD_INTMACRO(PAD_R2);
  LUA_FORWARD_INTMACRO(PAD_L3);
  LUA_FORWARD_INTMACRO(PAD_R3);

  LUA_FORWARD_INTMACRO(PAD_TYPE_NEJICON);
  LUA_FORWARD_INTMACRO(PAD_TYPE_KONAMIGUN);
  LUA_FORWARD_INTMACRO(PAD_TYPE_DIGITAL);
  LUA_FORWARD_INTMACRO(PAD_TYPE_ANALOG);
  LUA_FORWARD_INTMACRO(PAD_TYPE_NAMCOGUN);
  LUA_FORWARD_INTMACRO(PAD_TYPE_DUALSHOCK);
  LUA_FORWARD_INTMACRO(PAD_TYPE_JOGCON);
  LUA_FORWARD_INTMACRO(PAD_TYPE_EX_TSURICON);
  LUA_FORWARD_INTMACRO(PAD_TYPE_EX_JOGCON);
}
