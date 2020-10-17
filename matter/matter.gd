extends Node
# Singleton to track all types of "matter" (AKA Resources, but that name is
# already taken)


var matter_name := PoolStringArray()
var matter_volume := PoolIntArray()
var name_to_id := {}


# Add matter. 1 unit of volume is considered to be 1 mm^3, so 1 dm^3 (liters) is
# equivalent to 1_000_000 units and 1 m^3 is equivalent to 1_000_000_000 units
#
# The largest volume possible is thus 2^63 / 10 ^ 9 == 9223372036 m^3 or 10 km^3
# For comparison, that's roughly 3.6 billion Schwerer Gustav shells each fitted
# in a rectangular box.
func add_matter(p_name: String, volume: int) -> int:
	assert(not p_name in name_to_id)
	assert(len(matter_name) == len(matter_volume))
	name_to_id[p_name] = len(matter_name)
	matter_name.append(p_name)
	matter_volume.append(volume)
	return len(matter_name)
