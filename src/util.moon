import run from require 'exec'

try= (options) ->
	import times, delay, fn from options
	for i=1, times
		ok, val=pcall fn
		return val if ok
		run 'sleep', delay if i!=tries

isin= (arr, e) ->
	for v in *arr
		return true if e==v
	return false

{
	:try
	:isin
}
