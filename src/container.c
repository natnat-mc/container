#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "cmodules.h"

int main(int argc, char** argv) {
        // create a Lua state
        lua_State *L=luaL_newstate();
        luaL_openlibs(L);

        // allow loading from our bundle
        bundle_init(L);

		// allow loading from our modules
		cmodules_init(L);

        // load argc/argv into arg global
        lua_newtable(L);
        for(int i=0; i<argc; i++) {
                lua_pushstring(L, argv[i]);
                lua_seti(L, -2, i);
        }
        lua_pushnumber(L, argc-1);
        lua_setfield(L, -2, "n");
        lua_setglobal(L, "arg");

        // load the entrypoint
        lua_getglobal(L, "require");
        lua_pushstring(L, "container");
        if(lua_pcall(L, 1, 0, 0)) {
                lua_getglobal(L, "io");
                lua_getfield(L, 2, "stderr");
                lua_getfield(L, 3, "write");
                lua_getfield(L, 2, "stderr");
                lua_pushfstring(L, "An unprotected error has occurred: %s\n", luaL_checkstring(L, 1));
                lua_call(L, 2, 0);
        }

        // close the Lua state and exit
        lua_close(L);
        return 0;
}
