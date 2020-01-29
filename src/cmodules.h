#ifndef __CMODULES_H
#define __CMODULES_H

#include <lua.h>
#include <lauxlib.h>

void bundle_init(lua_State *L);
void cmodules_init(lua_State *L);

int posix_load(lua_State *L);

#endif

