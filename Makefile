.PHONY: all clean mrproper rebuild run install docs

NAME = container

CC = gcc
MOONC = moonc
LD = gcc
RM = rm -f
AR = ar
INSTALL = install

CFLAGS = -Wall -Wextra -I/usr/include/lua5.3 -g
LDFLAGS =
LIBS = -llua5.3

SOURCES = $(wildcard src/*.c)
MOONSCRIPT_SOURCES = $(wildcard src/*.moon)
HEADERS = $(wildcard src/*.h)

OBJECTS = $(foreach source, $(SOURCES), build/$(patsubst src/%.c,%.o,$(source)))
COMPILED_LUA = $(foreach source, $(MOONSCRIPT_SOURCES), build/$(patsubst src/%.moon,%.lua,$(source)))
COMMAND_LIST = build/command-list.lua
BUNDLED_LUA_C = build/luabundle.c
BUNDLED_LUA_O = build/luabundle.o

BINARY = out/$(NAME)

all: $(BINARY)
static: $(LIB)
dynamic: $(DYNAMIC_LIB)

install: all
	$(INSTALL) -o root -g root -m 755 $(BINARY) /usr/local/sbin/container
	$(INSTALL) -o root -g root -m 644 container.cron /etc/cron.d/container
	$(INSTALL) -o root -g root -m 644 container.service /etc/systemd/system/container.service
	systemctl enable container.service 2>/dev/null; true

docs: $(BINARY)
	$(BINARY) -internal-mddoc

clean:
	$(RM) $(OBJECTS)
	$(RM) $(COMPILED_LUA)
	$(RM) $(BUNDLED_LUA_C) $(BUNDLED_LUA_O)
	$(RM) Makefile.deps
	$(RM) build/?*.* # catch all renamed files
mrproper: clean
	$(RM) $(BINARY)

rebuild:
	@make mrproper
	@make

run: all
	./$(BINARY)


include Makefile.deps
Makefile.deps: $(SOURCES) $(HEADERS)
	@echo "Calculating dependencies"
	@$(RM) Makefile.deps
	@for file in $(SOURCES); do echo "build/`gcc $(CFLAGS) -M $$file`" >> Makefile.deps; done

$(BINARY): $(OBJECTS) $(BUNDLED_LUA_O)
	$(LD) $(LDFLAGS) -o $@ $^ $(LIBS)

build/%.o: src/%.c
	$(CC) $(CFLAGS) -o $@ -c $<

build/%.lua: src/%.moon
	$(MOONC) -o $@ $<

$(BUNDLED_LUA_O): $(BUNDLED_LUA_C)
	$(CC) $(CFLAGS) -o $@ -c $<

$(BUNDLED_LUA_C): $(COMPILED_LUA) $(COMMAND_LIST) tools/bundle.lua
	lua tools/bundle.lua $@ $(COMPILED_LUA) $(COMMAND_LIST)

$(COMMAND_LIST): $(MOONSCRIPT_SOURCES) tools/lister.moon
	moon tools/lister.moon $@
