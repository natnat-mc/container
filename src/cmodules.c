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
	lua_checkstack(L, 3);
	lua_getglobal(L, "package");
	lua_getfield(L, -1, "searchers");
	int len=luaL_len(L, -1);
	lua_pushcfunction(L, cmodules_import);
	lua_seti(L, -2, len+1);
	lua_pop(L, 2);
}
