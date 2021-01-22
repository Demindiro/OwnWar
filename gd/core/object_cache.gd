extends Object
class_name ObjectCache


const _CACHE := {}


static func dedup_immutable(object):
	if object in _CACHE:
		return _CACHE[object]
	else:
		_CACHE[object] = object
		return object
