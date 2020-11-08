#include "cmodules.h"

#include <string.h>

#define MODULE(mod) else if(!strcmp(name, #mod)) fn=mod##_load

int cmodules_import(lua_State *L) {
	const char* name;
	int (*fn)(lua_State*)=NULL;
	if(!*(name=luaL_checkstring(L, 1))) return 0;
	MODULE(posix);
	if(!fn) {
		lua_pushstring(L, "\n\tnot a builtin module");
		return 1;
	}
	lua_pushcfunction(L, fn);
	return 1;
}

void cmodules_init(lua_State *L) {
	lua_checkstack(L, 5);
	lua_getglobal(L, "table");
	lua_getglobal(L, "package");
	lua_getfield(L, -2, "insert");
	lua_getfield(L, -2, "searchers");
	lua_pushnumber(L, 1);
	lua_pushcfunction(L, cmodules_import);
	lua_call(L, 3, 0);
	lua_pop(L, 3);
}
