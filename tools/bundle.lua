#!/usr/bin/env lua5.3

local outfile=table.remove(arg, 1)
local fd=io.open(outfile, 'w')

local files={}
for i, filename in ipairs(arg) do
	files[filename:match "([a-zA-Z0-9_-]+).lua"]=filename
end

local headers={}
local functions={}
local prototypes={}

local function subst(line, vars)
	return (line:gsub("<%%%s*([a-zA-Z0-9_-]+)%s*%%>", vars or {}))
end
local function escape(str)
	return (str:gsub("[\'\"\t\r\n\\?]", {
		["\'"]=	"\\\'",
		["\""]=	"\\\"",
		["\t"]=	"\\t",
		["\r"]=	"\\r",
		["\n"]=	"\\n",
		["\\"]=	"\\\\",
		["?"]=	"\\?"
	}))
end

local function createfn(name, rettype, args, body)
	if type(name)~='string' then
		error "invalid type for function name"
	end
	if type(rettype)~='string' then
		error "invalid type for function return type"
	end
	if type(args)~='table' then
		error "invalid type for function arguments"
	end
	if type(body)=='table' then
		body=table.concat(body, '\n')
	elseif type(body)=='function' then
		local tab={}
		body(function(line, vars)
			table.insert(tab, "\t"..subst(line, vars))
		end)
		body=table.concat(tab, '\n')
	elseif type(body)~='string' then
		error "invalid type for function body"
	end
	table.insert(functions, subst([[<% rettype %> <% name %>(<% args %>) {<% body %>}]], {
		rettype=rettype,
		name=name,
		args=table.concat(args, ', '),
		body="\n"..body.."\n"
	}))
	table.insert(prototypes, subst([[<% rettype %> <% name %>(<% args %>);]], {
		rettype=rettype,
		name=name,
		args=table.concat(args, ', ')
	}))
end

table.insert(headers, "<string.h>")
table.insert(headers, "<lua.h>")
table.insert(headers, "<lauxlib.h>")

createfn("bundle_import", "int", {"lua_State *L"}, function(line)
	local sources={}
	for file, filename in pairs(files) do
		local sfd=io.open(filename, 'r')
		if not sfd then
			error("Couldn't open file "..filename)
		end
		local code=sfd:read '*a'
		sfd:close()
		if not code then
			error("Couldn't read file "..filename)
		end
		sources[file]=code
	end
	
	line [[const char* name=luaL_checkstring(L, 1);]]
	line [[char* code=NULL;]]
	local first=true
	for object, code in pairs(sources) do
		line([[<% cond %>(!strcmp(name, "<% name %>")) code="<% code %>";]], {
			cond=first and "if" or "else if",
			name=object,
			code=escape(code)
		})
		first=false
	end
	line [[if(code==NULL) {]]
	line 	[[lua_pushstring(L, "\n\tnot in bundle");]]
	line 	[[return 1;]]
	line [[}]]
	line [[int err=luaL_loadbuffer(L, code, strlen(code), name);]]
	line [[if(err==LUA_OK) return 1;]]
	line [[else if(err==LUA_ERRSYNTAX) return luaL_error(L, "syntax error in module %s: %s", name, lua_tostring(L, -1));]]
	line [[else return luaL_error(L, "error while loading module %s", name);]]
end)

createfn("bundle_list", "int", {"lua_State *L"}, function(line)
	line [[lua_settop(L, 0);]]
	line [[lua_newtable(L);]]
	local i=1
	for file in pairs(files) do
		line([[lua_pushstring(L, "<% file %>");]], {
			file=file
		})
		line([[lua_seti(L, 1, <% i %>);]], {
			i=i
		})
		i=i+1
	end
	line [[return 1;]]
end)

createfn("bundle_init", "void", {"lua_State *L"}, function(line)
	line [[lua_checkstack(L, 4);]]
	line [[lua_getglobal(L, "package");]]
	line [[lua_getfield(L, -1, "searchers");]]
	line [[int len=luaL_len(L, -1);]]
	line [[lua_pushcfunction(L, bundle_import);]]
	line [[lua_seti(L, -2, len+1);]]
	line [[lua_getfield(L, -2, "preload");]]
	line [[lua_pushcfunction(L, bundle_list);]]
	line [[lua_setfield(L, -2, "bundle");]]
	line [[lua_pop(L, 3);]]
end)

for i, header in ipairs(headers) do
	fd:write(subst([[#include <% header %>]], {
		header=header
	}))
	fd:write "\n"
end
fd:write "\n"

for i, fn in ipairs(prototypes) do
	fd:write(fn)
	fd:write "\n"
end
fd:write "\n"

for i, fn in ipairs(functions) do
	fd:write(fn)
	fd:write "\n"
end

fd:close()
