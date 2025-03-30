package opaque

import "base:intrinsics"
import "core:bytes"
import "core:mem"

OPAQUE_ALIGNMENT :: #config(OPAQUE_ALIGNMENT, 16)

Opaque :: struct($MaxSize: int) #align (OPAQUE_ALIGNMENT) {
	data: [MaxSize]byte,
	type: typeid,
}

make_opaque_sized :: proc(value: $T, $S: int) -> (opaque: Opaque(S)) {
	#assert(size_of(T) <= S, "Opaque size exceeds maximum size")
	#assert(
		align_of(T) <= align_of(Opaque(S)),
		"The type must have the same alignment as the opaque struct or lower",
	)
	#assert(
		align_of(Opaque(S)) % align_of(T) == 0,
		"The alignment of the opaque struct must be a multiple of the type's alignment",
	)
	opaque.type = T
	bytes := transmute([size_of(T)]byte)value
	copy(opaque.data[:], bytes[:])
	return opaque
}

make_opaque :: proc(value: $T) -> Opaque(size_of(T)) {
	return make_opaque_sized(value, size_of(T))
}

get_ptr_safe :: proc "contextless" (opaque: ^Opaque($S), $T: typeid) -> (value: ^T, ok: bool) {
	context = {}
	(opaque.type == T) or_return

	result := transmute(^T)(bytes.ptr_from_bytes(opaque.data[:]))

	p1 := rawptr(&opaque.data)
	p2 := rawptr(result)

	assert(p1 == p2, "Expected pointers to be the same")

	return result, true
}

get_value_safe :: proc "contextless" (opaque: Opaque($S), $T: typeid) -> (value: T, ok: bool) {
	(opaque.type == T) or_return
	opaque := opaque
	return mem.reinterpret_copy(T, &opaque.data), true
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
