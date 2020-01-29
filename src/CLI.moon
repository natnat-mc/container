identity= (a) -> a
number= (a) -> (tonumber a) or error "must be a number"
integer= (a) -> (math.type (tonumber a))=='integer' and (number a) or error "must be an integer"
oneof= (list) ->
	(a) ->
		for e in *list
			return a if e==a
		error "must be one of #{table.concat list, ', '}"

class Flag
	new: (opt) =>
		@type='flag'
		import long, short from opt
		@long=long
		@short=short
		error "No name given for flag" unless short or long

	usage: =>
		local content
		if @long and @short
			content="-#{@short}|--#{@long}"
		elseif @long
			content="--#{@long}"
		else
			content="-#{@short}"
		return "[#{content}]"

class Named
	new: (opt) =>
		@type='named'
		import long, short, default, required, multiple, translator from opt
		@long=long
		@short=short
		error "No name given for named argument" unless short or long
		@default=default or nil
		@required=required or false
		@multiple=multiple or false
		@translator=translator or identity

	usage: =>
		local content
		if @long and @short
			content="-#{@short}|--#{@long}"
		elseif @long
			content="--#{@long}"
		else
			content="-#{@short}"
		return "#{@required and "<" or "["}#{content} <value>#{@multiple and "..." or ""}#{@required and ">" or "]"}"

class Positional
	new: (opt) =>
		@type='positional'
		import name, translator from opt
		@name=name or error "No name given for positional argument"
		@translator=translator or identity

	usage: =>
		"<#{@name}>"

class CLI
	new: (opt={}) =>
		@_named={}
		@_positional={}
		@_splat=false

		@splat! if opt.splat
		for arg in *opt
			@flag arg if arg.type=='flag'
			@named arg if arg.type=='named'
			@positional arg if arg.type=='positional'

	_register: (named) =>
		@_named['--'..named.long]=named if named.long
		@_named['-'..named.short]=named if named.short

	flag: (opt) => @_register Flag opt
	named: (opt) => @_register Named opt

	positional: (opt) =>
		table.insert @_positional, Positional opt

	splat: (enable) =>
		enable=true if enable==nil
		@_splat=enable

	parse: (argv) =>
		parsed={}
		seen={}
		i=1
		posi=1
		current='nil'
		while argv[i]
			arg=argv[i]
			if current=='positional' or (arg\sub 1, 1)!='-'
				if @_positional[posi]==nil and @_splat
					table.insert parsed, arg
				elseif p=@_positional[posi]
					ok, val=pcall p.translator, arg
					error "At argument #{i} (#{arg}): #{val}" unless ok
					parsed[p.name]=p.translator arg
					posi+=1
				else
					error "At argument #{i} (#{arg}): too many arguments"
			elseif arg=='--'
				current='positional'
			elseif a=@_named[arg]
				if seen[a] and not a.multiple
					error "At argument #{i} (#{arg}): duplicate argument"
				seen[a]=true
				if a.type=='flag'
					parsed[a.short]=true if a.short
					parsed[a.long]=true if a.long
				else
					i+=1
					arg=argv[i]
					error "At argument #{i} (#{arg}): no value given" unless arg
					if a.multiple
						t=parsed[a.short] if a.short
						t=parsed[a.long] if a.long
						t={} unless t
						ok, val=pcall a.translator, arg
						error "At argument #{i} (#{argv}): #{val}" unless ok
						table.insert t, val
						parsed[a.short]=t if a.short
						parsed[a.long]=t if a.long
					else
						ok, val=pcall a.translator, arg
						error "At argument #{i} (#{argv}): #{val}" unless ok
						parsed[a.short]=val if a.short
						parsed[a.long]=val if a.long
			else
				error "At argument #{i} (#{arg}): invalid argument"
			i+=1
		error "Too few arguments" if posi!=#@_positional+1
		for _, v in pairs @_named
			unless seen[v]
				error "Argument #{v.long and "--#{v.long}" or "-#{v.short}"} not given}" if v.required
				parsed[v.short]=v.default if v.short
				parsed[v.long]=v.default if v.long
		return parsed

	usage: =>
		list={}
		seen={}
		args={}
		for _, v in pairs @_named
			continue if seen[v]
			seen[v]=true
			table.insert args, v
		table.sort args, (a, b) ->
			return a.long<b.long if a.long and b.long
			return a.short<b.short if a.short and b.short
			return -1 if a.short
			return 1
		for v in *args
			table.insert list, v\usage!
		table.insert list, "[--]"
		for positional in *@_positional
			table.insert list, positional\usage!
		if @_splat
			table.insert list, "[...]"
		return table.concat list, ' '

	@translator: {
		:identity,
		:number, :integer,
		:oneof
	}

CLI
