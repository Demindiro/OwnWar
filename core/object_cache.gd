extends Node


var _cache := {}


func dedup_immutable(object):
	if object in _cache:
		return _cache[object]
	else:
		_cache[object] = object
		return object
