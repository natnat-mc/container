import pread, ensuredir from require 'exec'
import isdir from require 'posix'
require 'env'
INI=require 'INI'
Command=require 'Command'

with Command 'create'
	.args={
		{'name', required: true}
	}
	.desc="Creates a container with minimal config and directory layer"
	.help={
		"The created container uses a directory layer called `layer.dir`, which is created empty"
		"If you want to create a container with an os already in it, you may want to use `container create-debian` or `container create-alpine` instead"
	}
	.fn= (name) ->
		-- create INI
		ini=INI!
		ini\set 'layer', 'filename', 'layer.dir'
		ini\set 'layer', 'type', 'directory'
		ini\set 'layer', 'writable', true
		ini\set 'machine', 'arch', (pread 'arch')[1]
		ini\set 'machine', 'layers', name

		-- create destination directories
		error "Container #{name} already exists" if isdir "#{CONTAINER_DIR}/#{name}"
		ensuredir "#{CONTAINER_DIR}/#{name}"
		ensuredir "#{CONTAINER_DIR}/#{name}/layer.dir"
		ensuredir "#{CONTAINER_DIR}/#{name}/layer.dir/rootfs"
		ensuredir "#{CONTAINER_DIR}/#{name}/layer.dir/workdir"

		-- write config file
		ini\export "#{CONTAINER_DIR}/#{name}/config.ini"
		return 0
