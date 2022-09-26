# Class that provides methods to convert itself to a Dictionary that is convertible to and from JSON
extends Reference
class_name JSONable

#If ever needed, the strings for the types
# const TYPE_NAMES=["TYPE_NIL","TYPE_BOOL","TYPE_INT","TYPE_REAL","TYPE_STRING","TYPE_VECTOR2","TYPE_RECT2","TYPE_VECTOR3","TYPE_TRANSFORM2D","TYPE_PLANE","TYPE_QUAT","TYPE_AABB","TYPE_BASIS","TYPE_TRANSFORM","TYPE_COLOR","TYPE_NODE_PATH","TYPE_RID","TYPE_OBJECT","TYPE_DICTIONARY","TYPE_ARRAY","TYPE_RAW_ARRAY","TYPE_INT_ARRAY","TYPE_REAL_ARRAY","TYPE_STRING_ARRAY","TYPE_VECTOR2_ARRAY","TYPE_VECTOR3_ARRAY","TYPE_COLOR_ARRAY","TYPE_MAX"]

func to() -> Dictionary:
	push_warning("JSONable.to() is being called. Consider overwriting it.")
	return {}

# For convenience of use, returns self
func from(from : Dictionary) -> JSONable:
	push_warning("JSONable.from() is being called. Consider overwriting it.")
	return self

static func vector2_from(from : Dictionary) -> Vector2:
	return Vector2(from.x, from.y)
static func vector2_to(to : Vector2) -> Dictionary:
		return {
			"x" : to.x,
			"y" : to.y
		}     

static func color_from(from : Dictionary) -> Color:
	return Color(from.r, from.g, from.b)
static func color_to(to : Color) -> Dictionary:
	return {
		"r" : to.r,
		"g" : to.g,
		"b" : to.b
	}
