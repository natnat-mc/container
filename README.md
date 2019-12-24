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

