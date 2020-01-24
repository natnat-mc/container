import pread, ensuredir, isdir from require 'exec'
require 'env'
INI=require 'INI'
Command=require 'Command'

with Command 'create'
	.args={
		{'name', required: true}
	}
	.desc="Creates a container with minimal config and directory layer"
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