const _MATTER_NAME := PoolStringArray()
const _MATTER_VOLUME := PoolIntArray()
const _NAME_TO_ID := {}


# Add matter. 1 unit of volume is considered to be 1 mm^3, so 1 dm^3 (liters) is
# equivalent to 1_000_000 units and 1 m^3 is equivalent to 1_000_000_000 units
#
# The largest volume possible is thus 2^63 / 10 ^ 9 == 9223372036 m^3 or 10 km^3
# For comparison, that's roughly 3.6 billion Schwerer Gustav shells each fitted
# in a rectangular box.
static func add_matter(p_name: String, volume: int) -> int:
	assert(not p_name in _NAME_TO_ID)
	assert(len(_MATTER_NAME) == len(_MATTER_VOLUME))
	var id := len(_MATTER_NAME)
	_NAME_TO_ID[p_name] = id
	_MATTER_NAME.append(p_name)
	_MATTER_VOLUME.append(volume)
	return id


static func has_matter(p_name: String) -> bool:
	return p_name in _NAME_TO_ID


static func get_matter_id(p_name: String) -> int:
	assert(p_name in _NAME_TO_ID)
	return _NAME_TO_ID[p_name]


static func try_get_matter_id(p_name: String) -> int:
	return _NAME_TO_ID.get(p_name, -1)


static func get_matter_name(id: int) -> String:
	assert(id < len(_MATTER_NAME))
	assert(len(_MATTER_NAME) == len(_MATTER_VOLUME))
	return _MATTER_NAME[id]


static func get_matter_volume(id: int) -> int:
	assert(id < len(_MATTER_VOLUME))
	assert(len(_MATTER_NAME) == len(_MATTER_VOLUME))
	return _MATTER_VOLUME[id]


static func get_matter_types_count() -> int:
	assert(len(_MATTER_NAME) == len(_MATTER_VOLUME))
	assert(len(_MATTER_NAME) == len(_NAME_TO_ID))
	return len(_MATTER_NAME)
