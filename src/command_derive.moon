import getini from require 'containerutil'
import ensuredi from require 'exec'
import isdir from require 'posix'
require 'env'
Command=require 'Command'

with Command 'derive'
	.args={
		{'source', required: true}
		{'name', required: true}
	}
	.desc="Creates a container deriving from another container"
	.help={
		"The new container will use the same machine information, but will have an extra directory layer on top"
		"This is similar to the `FROM` instruction of a dockerfile"
	}
	.fn= (source, name) ->
		-- load container config
		ini=getini source, machine: true

		-- derive config file
		error "Container #{name} already exists" if isdir "#{CONTAINER_DIR}/#{name}"
		ini\set 'layer', 'filename', 'layer.dir'
		ini\set 'layer', 'type', 'directory'
		ini\set 'layer', 'writable', true
		ini\set 'machine', 'rootfs', 'layer'
		ini\append 'machine', 'layers', name

		-- create new container
		ensuredir "#{CONTAINER_DIR}/#{name}"
		ensuredir "#{CONTAINER_DIR}/#{name}/layer.dir"
		ini\export "#{CONTAINER_DIR}/#{name}/config.ini"
		return 0
