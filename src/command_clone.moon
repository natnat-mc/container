import getini from require 'containerutil'
import ensuredir, runorerror, isdir from require 'exec'
require 'env'
State=require 'State'
Command=require 'Command'

with Command 'clone'
	.args={
		{'source', required: true}
		{'name', required: true}
	}
	.desc="Clones a container non-recursively"
	.help={
		"If the container has a layer, this layer is cloned"
		"If the container has a machine, this machine is cloned"
		"If the container uses the cloned layer in its machine, it is replaced by the clone"
	}
	.fn= (source, name) ->
		-- load container
		ini=getini source
		State\lock 'container', source
		error "Container is in use" unless 0==State\uses 'container', source
		
		-- create destination directory
		error "Container #{name} already exists" if isdir "#{CONTAINER_DIR}/#{name}"
		ensuredir "#{CONTAINER_DIR}/#{name}"
		
		-- clone source layer if present
		if ini\hassection 'layer'
			runorerror 'cp', '-a', "#{CONTAINER_DIR}/#{source}/#{ini\get 'layer', 'filename'}", "#{CONTAINER_DIR}/#{name}"
			if ini\hassection 'machine'
				layers=ini\getlist 'machine', 'layers'
				for i, layer in ipairs layers
					layers[i]=name if layer==source
				ini\setlist 'machine', 'layers', layers
		
		-- write config file
		ini\export "#{CONTAINER_DIR}/#{name}/config.ini"
		State\unlock 'container', source
		return 0