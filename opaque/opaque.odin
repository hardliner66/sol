package opaque

import "core:mem"

Opaque :: struct($MaxSize: int) {
	type: typeid,
	data: [MaxSize]byte,
}

make_opaque_sized :: proc(value: $T, $S: int) -> (opaque: Opaque(S)) {
	#assert(size_of(T) <= S, "Opaque size exceeds maximum size")
	opaque.type = T
	value := value
	bytes := mem.ptr_to_bytes(&value, size_of(T))
	mem.copy(&opaque.data, raw_data(bytes), size_of(T))
	return opaque
}

make_opaque :: proc(value: $T) -> Opaque(size_of(T)) {
	return make_opaque_sized(value, size_of(T))
}

get_ptr_safe :: proc "contextless" (opaque: ^Opaque($S), $T: typeid) -> (value: ^T, ok: bool) {
	(opaque.type == T) or_return
	return transmute(^T)(&opaque.data), true
}

get_value_safe :: proc "contextless" (opaque: Opaque($S), $T: typeid) -> (value: T, ok: bool) {
	(opaque.type == T) or_return
	opaque := opaque
	ptr := get_ptr_safe(&opaque, T) or_return
	return ptr^, true
}

get_ptr :: proc "contextless" (opaque: ^Opaque($S), $T: typeid) -> ^T {
	// I just found out that instead of doing
	// if var, ok := some_proc(); ok {}
	// you can use
	// for var in some_proc() {}
	// which seems a bit simpler,
	// though it might lead to some confusion ;)
	for value in get_ptr_safe(opaque, T) {
		return value
	}
	panic_contextless("Type mismatch")
}

get_value :: proc "contextless" (opaque: Opaque($S), $T: typeid) -> T {
	for value in get_value_safe(opaque, T) {
		return value
	}
	panic_contextless("Type mismatch")
}
