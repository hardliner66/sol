package rustic

import "core:fmt"

Ok :: struct($T: typeid) {
	value: T,
}

ok :: proc(value: $T) -> Ok(T) {
	return {value}
}

Err :: struct($T: typeid) {
	value: T,
}

err :: proc(value: $T) -> Err(T) {
	return {value}
}

Result :: union($T: typeid, $E: typeid) #no_nil {
	Ok(T),
	Err(E),
}

unwrap_maybe :: proc(opt: Maybe($T), loc := #caller_location) -> T {
	if opt == nil {
		panic("Called unwrap on a nil value", loc)
	}
	return opt.(T)
}

unwrap_result :: proc(res: Result($T, $E), loc := #caller_location) -> T {
	#partial switch v in res {
	case Ok(T):
		return v.value
	case Err(E):
		panic(fmt.aprintf("Called unwrap on an Err value: %v", v.value), loc)
	}
	panic("How did you get here?")
}

unwrap :: proc {
	unwrap_maybe,
	unwrap_result,
}

unwrap_or_maybe :: proc(opt: Maybe($T), other: T) -> T {
	if opt == nil {
		return other
	}
	return opt.(T)
}

unwrap_or_result :: proc(res: Result($T, $E), other: T) -> T {
	#partial switch v in res {
	case Ok(T):
		return v.value
	}
	return other
}

unwrap_or :: proc {
	unwrap_or_maybe,
	unwrap_or_result,
}

unwrap_or_else_maybe :: proc(opt: Maybe($T), other: proc() -> T) -> T {
	if opt == nil {
		return other()
	}
	return opt.(T)
}

unwrap_or_else_result :: proc(res: Result($T, $E), other: proc() -> T) -> T {
	#partial switch v in res {
	case Ok(T):
		return v.value
	}
	return other()
}

unwrap_or_else :: proc {
	unwrap_or_else_maybe,
	unwrap_or_else_result,
}

map_maybe :: proc(opt: Maybe($T), f: proc(_: T) -> $U) -> Maybe(U) {
	if opt == nil {
		return nil
	}
	return f(opt.(T))
}

map_result :: proc(res: Result($T, $E), f: proc(_: T) -> $U) -> Result(U, E) {
	#partial switch v in res {
	case Ok(T):
		return f(v.value)
	}
	return res
}

map_with :: proc {
	map_maybe,
	map_result,
}

map_err :: proc(res: Result($T, $E), f: proc(_: E) -> $U) -> Result(T, U) {
	#partial switch v in res {
	case Err(T):
		return f(v.value)
	}
	return res
}
