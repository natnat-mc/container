# container
This is a simple container script, to make `systemd-nspawn` more usable.
This script also adds layering capabilities using `overlayfs2` (like Docker).

## Usage
This script expects containers in `/sys/containers` (or `$CONTAINER_DIR`) as directories containing a `config.ini` file. It also uses a global config file in `$CONTAINER_DIR/globalconfig.ini`.

For more information on the commands, see `container help` and the Markdown documentation.

### `container list`
This command lists the containers in `CONTAINER_DIR` with the layer types.

### `container boot <machine>`
This command boots a container containing a machine, boots it and unmounts it when it shuts down.

### `container start <machine>`
This command starts a container in a detached state, to be reattached with `container attach <machine>`.

### `container derive <source> <name>`
This command creates a container using the source as base, with a directory layer on top.

### `container status [machine]`
This command checks the status of a machine, or of all machines if not specified.

## Installing
This script is written in [MoonScript](http://moonscript.org) and as such requires lua and moon to be installed. It uses `systemd-nspawn` which is usually in the `systemd-container` package. It also uses `screen` for detached containers.

### Installing on Debian and derivatives (Raspbian, Ubuntu)
```bash
sudo apt install systemd-container lua5.1 lua5.3 liblua5.1-dev liblua5.3-dev luarocks git build-essential screen
sudo luarocks install moonscript
cd /tmp
git clone https://github.com/natnat-mc/container.git
cd container
make; sudo make install; make docs
```
