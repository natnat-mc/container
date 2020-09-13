NAME = "container"

LUA_CFLAGS = findclib 'lua5.3', 'cc'
LUA_LDFLAGS = findclib 'lua5.3', 'ld'

CFLAGS = {"-Wall", "-Wextra", "-g", LUA_CFLAGS}
LDFLAGS = {LUA_LDFLAGS}

MOON_SOURCES = wildcard 'src/*.moon'
LUA_OBJECTS = patsubst MOON_SOURCES, 'src/%.moon', 'build/%.lua'

C_SOURCES = wildcard 'src/*.c'
OBJECTS = patsubst C_SOURCES, 'src/%.c', 'build/%.o'

CMD_LIST = 'build/command-list.lua'
BUNDLE_C = 'build/bundle.c'
BUNDLE_O = 'build/bundle.o'

BINARY = "out/#{NAME}"

public default target 'build', deps: BINARY

public target 'clean', fn: =>
	-rm '-f', OBJECTS
	-rm '-f', LUA_OBJECTS
	-rm '-f', CMD_LIST, BUNDLE_C, BUNDLE_O

public target 'mrproper', deps: 'clean', fn: =>
	-rm '-f', BINARY

public target 'docs', deps: BINARY, fn: =>
	run BINARY, '-internal-mddoc'

public target 'install', deps: BINARY, fn: =>
	-install '-o', 'root', '-g', 'root', '-m', '755', BINARY, '/usr/local/sbin/container'
	-install '-o', 'root', '-g', 'root', '-m', '644', 'container.cron', '/etc/cron.d/container'
	-install '-o', 'root', '-g', 'root', '-m', '644', 'container.service', '/etc/systemd/system/container.service'
	run 'systemctl', {'enable', 'container.service', {raw: '2>/dev/null; true'}}

target CMD_LIST, from: {LUA_OBJECTS}, in: 'tools/lister.moon', out: CMD_LIST, fn: =>
	-moon 'tools/lister.moon', @outfile

target BUNDLE_C, from: {LUA_OBJECTS, CMD_LIST}, in: 'tools/bundle.lua', out: BUNDLE_C, fn: =>
	-lua 'tools/bundle.lua', @outfile, LUA_OBJECTS, CMD_LIST

target BUNDLE_O, from: BUNDLE_C, out: BUNDLE_O, fn: =>
	-cc CFLAGS, '-c', @infile, '-o', @outfile

target BINARY, from: {OBJECTS, BUNDLE_O}, out: BINARY, fn: =>
	-cc '-o', @outfile, @ins, LDFLAGS

-- autobuild
target 'build/%.lua', in: 'src/%.moon', out: 'build/%.lua', fn: =>
	-moonc '-o', @outfile, @infile

foreach C_SOURCES, (src) ->
	obj=patsubst src, 'src/%.c', 'build/%.o'
	target obj, in: {src, calccdeps src}, out: obj, fn: =>
		-cc CFLAGS, '-c', @infile, '-o', @outfile
