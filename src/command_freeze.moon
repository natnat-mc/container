import getini, mountlayer from require 'containerutil'
import runorerror from require 'exec'
require 'env'
State=require 'State'
Command=require 'Command'

with Command 'freeze'
	.args={
		{'name', required: true}
	}
	.desc="Freezes a container to squashfs"
	.fn= (name) ->
		-- mount layer
		ini=getini name, layer: true
		State\lock 'container', name
		error "Container is in use" unless 0==State\uses 'container', name
		layer=mountlayer name
		State\use 'layer', layer.root
		ok, err=pcall () ->
			runorerror 'mksquashfs', layer.rootfs, "#{CONTAINER_DIR}/#{name}/layer.squashfs", '-comp', 'xz', '-Xdict-size', '100%'
		State\release 'layer', layer.root
		oldroot="#{CONTAINER_DIR}/#{name}/#{ini\get 'layer', 'filename'}"
		error err unless ok
		ini\set 'layer', 'filename', 'layer.squashfs'
		ini\set 'layer', 'type', 'squashfs'
		ini\set 'layer', 'writable', false
		if ini\hassection 'machine'
			ini\set 'machine', 'rootfs', 'tmpfs'
		ini\export "#{CONTAINER_DIR}/#{name}/config.ini"
		runorerror 'rm', '-rf', oldroot
		State\unlock 'container', name
		return 0