# Config file format
Note than most functionality is based on `systemd-nspawn`, and some options may not work on older versions

## `[layer]` section
- `writable`: boolean  
- `type`: `ext4|squashfs|directory`  
- `filename`: string

## `[machine]` section
- `hostname`: string *defaults to the name of the machine*
- `arch`: string  
	should be an architecture that can actually run on the host, the script will not check this for you
- `layers`: list *defaults to the layer of the machine*  
	the layers used by this machine, from bottom to top
- `rootfs`: `layer|tmpfs` *defaults to `layer`*
- `networking`: `host|private` *defaults to `host`*
- `capabilities`: `auto|all|list` *defaults to `auto`*
- `resolv-conf`: `host|container|copy` *defaults to `host`*
- `timezone`: `host|container|copy` *defaults to `host`*
- `interactive`: boolean *defaults to true*  
	if set to `true`, the container will have a `/dev/console` linked to the terminal, otherwise it will be created but linked nowhere

## `[binds]` section
The `[binds]` sections maps as key the mountpoint on the container, and as value a string of the format `[+][-]<path>` where:
- `+` means that the path is relative to the container (otherwise it will be relative to the host)
- `-` means that the bind mount is read-only
- `path` is the absolute path which will be bind-mounted

**no attempt is made to satisfy bind mount dependencies, mounts are done in alphabetical order**

## `[capabilities]` section
**this section will only be used if the `capability` parameter is set to `list` in the `[machine]` section**

The `[capabilities]` section maps as key th name of the capaility and as value `grant` or `drop`

## `[networking]`
**this section will only be used if the `networking` parameter is set to `private` in the `[machine]` section**

- `interfaces`: list  
	will assign the given interfaces to the container and remove them from the host
- `macvlan`: list  
	will create `macvlan` from the specified interfaces
- `ipvlan`: list  
	will create `ipvlan` from the specified interfaces
- `veth`: list  
	will create `veth` interfaces with the specified names
- `bridge`: string *defaults to none*  
	will create a `veth` interface and bridge it with the specified interface
- `zone`: string *defaults to none*  
	will create a `veth` interface and add it to a bridge with other containers using the same zone