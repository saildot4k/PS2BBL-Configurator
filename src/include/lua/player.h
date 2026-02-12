#ifndef LUA_PLAYER_H
#define LUA_PLAYER_H

#include <debug.h>

extern "C" {
#include "lauxlib.h"
#include "lua.h"
#include "lualib.h"
}

#ifdef DEBUG
#define dbgprintf(args...) scr_printf(args)
#else
#define dbgprintf(args...) ;
#endif

int getBootDevice(void);

#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define CLAMP(val, min, max) ((val) > (max) ? (max) : ((val) < (min) ? (min) : (val)))

#define ASYNC_TASKS_MAX 1


const char *runScript(const char *script, bool isStringBuffer);
void luaC_collectgarbage(lua_State *L);

void luaControls_init(lua_State *L);
void luaGraphics_init(lua_State *L);
void luaScreen_init(lua_State *L);
void luaTimer_init(lua_State *L);
void luaSystem_init(lua_State *L);
void luaRender_init(lua_State *L);
void stackDump(lua_State *L);

#endif
