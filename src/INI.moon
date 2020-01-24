class INI
	new: () =>
		@sections={}
	
	addsection: (name) =>
		@sections[name]={} unless @sections[name]
	
	get: (section, key, default=nil) =>
		section=@sections[section]
		return default unless section
		val=section[key]
		return default if val==nil
		return val
	getlist: (section, key) =>
		[item for item in (@get section, key, '')\gmatch '%S+']
	getorerror: (section, key) =>
		error "no such section #{section}" unless @sections[section]
		error "no suck key #{key} in section #{section}" unless nil!=@sections[section][key]
		return @sections[section][key]
	
	has: (section, key) =>
		@sections[section] and @sections[section][key]!=nil
	hassection: (section) =>
		@sections[section]!=nil
	
	set: (section, key, val) =>
		@addsection section
		@sections[section][key]=val
	setlist: (section, key, list) =>
		@set section, key, table.concat list, ' '
	append: (section, key, ...) =>
		list=@getlist section, key
		table.insert list, select i, ... for i=1, select '#', ...
		@set section, key, table.concat list, ' '
	
	export: (filename) =>
		fd=io.stdout
		fd, err=io.open filename, 'w' if filename
		error err unless fd
		for section, data in pairs @sections
			ok, err=fd\write "[#{section}]\n"
			error err unless ok
			for key, value in pairs data
				ok, err=fd\write "#{key} = #{value}\n"
				error err unless ok
		ok, err=fd\close! if filename
		error err unless ok
	
	@parse: (filename, defaultsection='general') =>
		ini=@!
		currentsection=defaultsection
		lineno=0
		parseval= (val) ->
			return true if val=='true'
			return false if val=='false'
			return nil if val=='nil'
			return tonumber val if tonumber val
			val
		for line in io.lines filename
			line=line\match '^%s*(.*)%s*$'
			lineno+=1
			if section=line\match '^%[([^%]]+)%]$'
				currentsection=section
			elseif line\match '^[^=]+=%s*.+$'
				key, val=line\match '^([^=]-)%s*=%s*(.+)$'
				ini\set currentsection, key, parseval val
			elseif (line\match '^#') or line==''
				nil -- comment
			else
				error "line #{lineno}: '#{line}' not understood"
		return ini
