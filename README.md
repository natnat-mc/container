# container
This is a simple container script, to make `systemd-nspawn` more usable.
This script also adds layering capabilities using `overlayfs2` (like Docker).

## Usage
This script expects containers in `/sys/containers` (or `CONTAINER_DIR`) as directories containing a `config.ini` file.

### `container list`
This command lists the containers in `CONTAINER_DIR` with the layer types.

### `container info <container>`
This command displays the info of a container.

### `container mount <machine>`
This command mounts a container containing a machine and displays the relevant paths.

### `container boot <machine>`
This command boots a container containing a machine, boots it and unmounts it when it shuts down.

### `container derive <source> <name>`
This command creates a container using the source as base, with a directory layer on top.

### `container freeze <layer>`
This command freezes a layer (compresses its layer to `squashfs`) and, if there is also a machine in the container, updates it to use a `tmpfs` upper layer.

## Installing
This script is written in [MoonScript](http://moonscript.org) and as such requires lua and moon to be installed. It uses `systemd-nspawn` which is usually in the `systemd-container` package.

### Installing on Debian and derivatives (Raspbian, Ubuntu)
```bash
sudo apt install systemd-container lua5.1 liblua5.1-dev luarocks git
sudo luarocks install moonscript
cd /tmp
git clone https://github.com/natnat-mc/container.git
cd container
./install.sh
```

The use of `screen` and `screenie` or `tmux` is also greatly encouraged. They can be installed with the following command: `sudo apt install screen sceenie tmux`.

