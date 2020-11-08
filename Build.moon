public var 'NAME', "container"

var 'CC', 'gcc'
var 'LD', 'gcc'
var 'MOONC', 'moonc'
var 'INSTALLX', 'install', '-o', 'root', '-g', 'root', '-m', '755'
var 'INSTALLR', 'install', '-o', 'root', '-g', 'root', '-m', '644'
var 'RM', 'rm', '-f', '--'

var 'CFLAGS', '-Wall', '-Wextra', '-g', _.pkgconfig.cflags 'lua5.3'
var 'LDFLAGS', _.pkgconfig.libs 'lua5.3'

var 'MOON_SOURCES', _.wildcard 'src/**.moon'
var 'LUA_OBJECTS', _.patsubst MOON_SOURCES, 'src/%.moon', 'build/%.lua'

var 'C_SOURCES', _.wildcard 'src/**.c'
var 'C_OBJECTS', _.patsubst C_SOURCES, 'src/%.c', 'build/%.o'

var 'CMD_LIST', 'build/command-list.lua'
var 'BUNDLE_C', 'build/bundle.c'
var 'BUNDLE_O', 'build/bundle.o'
var 'C_OBJECTS', C_OBJECTS, BUNDLE_O

var 'BINARY', "out/#{NAME}"

with public default target 'all'
	\depends BINARY

with public target 'clean'
	\fn => _.cmd RM, LUA_OBJECTS
	\fn => _.cmd RM, C_OBJECTS
	\fn => _.cmd RM, CMD_LIST, BUNDLE_C

with public target 'mrproper'
	\after 'clean'
	\fn => _.cmd RM, BINARY

with public target 'docs'
	\depends BINARY
	\fn => _.cmd BINARY, '-internal-mddoc'

with public target 'install'
	\depends BINARY
	\depends 'container.cron'
	\depends 'container.service'
	\produces "/usr/local/sbin/#{NAME}"
	\produces "/etc/cron.d/#{NAME}"
	\produces "/etc/systemd/system.#{NAME}.service"
	\fn => _.cmd INSTALLX, BINARY, "/usr/local/sbin/#{NAME}"
	\fn => _.cmd INSTALLR, 'container.cron', "/etc/cron.d/#{NAME}"
	\fn => _.cmd INSTALLR, 'container.service', "/etc/systemd/system/#{NAME}.service"

with target CMD_LIST
	\depends LUA_OBJECTS
	\depends 'tools/lister.moon'
	\produces CMD_LIST
	\fn => _.cmd 'moon', 'tools/lister.moon', @outfile

with target BUNDLE_C
	\depends LUA_OBJECTS
	\depends CMD_LIST
	\depends 'tools/bundle.lua'
	\produces BUNDLE_C
	\fn => _.cmd 'lua', 'tools/bundle.lua', @outfile, LUA_OBJECTS, CMD_LIST

with target C_OBJECTS, pattern: 'build/%.o'
	\depends 'src/%.c'
	\depends => _.cdeps[CC] @infile, CFLAGS
	\produces 'build/%.o'
	\fn => _.cmd CC, CFLAGS, '-c', @infile, '-o', @outfile

with target LUA_OBJECTS, pattern: 'build/%.lua'
	\depends 'src/%.moon'
	\produces 'build/%.lua'
	\fn => _.moonc @infile, @outfile

with target BUNDLE_O
	\depends BUNDLE_C
	\produces BUNDLE_O
	\fn => _.cmd CC, CFLAGS, '-c', @infile, '-o', @outfile

with target BINARY
	\depends C_OBJECTS
	\produces BINARY
	\fn => _.cmd LD, '-o', @outfile, @infiles, LDFLAGS
