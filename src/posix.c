#include <lua.h>
#include <lauxlib.h>

#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>

#include <sys/types.h>
#include <sys/stat.h>

#define intfield(name, val) do{ lua_pushinteger(L, val); lua_setfield(L, -2, name); }while(0)
#define stringfield(name, val) do{ lua_pushstring(L, val); lua_setfield(L, -2, name); }while(0)
#define functionfield(name, val) do { lua_pushcfunction(L, val); lua_setfield(L, -2, name); }while(0)

static void _posix_statbufTable(lua_State *L, struct stat* stat) {
	lua_newtable(L);
	intfield("dev", stat->st_dev);
	intfield("ino", stat->st_ino);
	intfield("mode", stat->st_mode);
	intfield("nlink", stat->st_nlink);
	intfield("uid", stat->st_uid);
	intfield("gid", stat->st_gid);
	intfield("rdev", stat->st_rdev);
	intfield("size", stat->st_size);
	intfield("blksize", stat->st_blksize);
	intfield("blocks", stat->st_blocks);
	intfield("atime", stat->st_atime);
	intfield("mtime", stat->st_mtime);
	intfield("ctime", stat->st_ctime);
}

static int posix_stat(lua_State *L) {
	const char* pathname=luaL_checkstring(L, 1);
	struct stat statbuf;
	if(stat(pathname, &statbuf)) {
		luaL_error(L, strerror(errno));
	}
	_posix_statbufTable(L, &statbuf);
	return 1;
}

static int posix_fstat(lua_State *L) {
	int fd=luaL_checkinteger(L, 1);
	struct stat statbuf;
	if(fstat(fd, &statbuf)) {
		luaL_error(L, strerror(errno));
	}
	_posix_statbufTable(L, &statbuf);
	return 1;
}

static int posix_exists(lua_State *L) {
	const char* pathname=luaL_checkstring(L, 1);
	struct stat statbuf;
	if(stat(pathname, &statbuf)) {
		if(errno==ENOENT || errno==ENOTDIR) {
			lua_pushboolean(L, 0);
			return 1;
		}
		luaL_error(L, strerror(errno));
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int posix_isfile(lua_State *L) {
	const char* pathname=luaL_checkstring(L, 1);
	struct stat statbuf;
	if(stat(pathname, &statbuf)) {
		luaL_error(L, strerror(errno));
	}
	lua_pushboolean(L, statbuf.st_mode&S_IFREG);
	return 1;
}

static int posix_isdir(lua_State *L) {
	const char* pathname=luaL_checkstring(L, 1);
	struct stat statbuf;
	if(stat(pathname, &statbuf)) {
		luaL_error(L, strerror(errno));
	}
	lua_pushboolean(L, statbuf.st_mode&S_IFDIR);
	return 1;
}

int posix_load(lua_State *L) {
	lua_newtable(L);
	functionfield("stat", posix_stat);
	functionfield("fstat", posix_fstat);
	functionfield("exists", posix_exists);
	functionfield("isfile", posix_isfile);
	functionfield("isdir", posix_isdir);
	return 1;
}
