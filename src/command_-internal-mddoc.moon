import ensuredir from require 'exec'
Command=require 'Command'

with Command '-internal-mddoc'
	.noroot=true
	.args={
		{'outdir', required: false}
		{'command', required: false}
	}
	.desc="Generates Markdown documentation"
	.fn= (outdir='docs', command) ->
		ensuredir outdir
		generate=(cname) ->
			file="#{outdir}/cmd_#{cname}.md"
			command=Command\get cname
			return false unless command.help
			fd, err=io.open file, 'w'
			error "Failed to open file #{file}: #{err}" unless fd
			push=(s) -> fd\write s, '\n'
			push "# `container #{command.name}`"
			push command.desc
			push "*root not required*" if command.noroot
			push ""
			push "## Usage"
			push "`#{command\usage!}`"
			push ""
			push "## Help"
			for line in *command.help
				push line
			fd\close!
			return true
		if command
			generate command
		else
			generate cmdname for cmdname in *require 'command-list'
