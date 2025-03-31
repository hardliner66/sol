package opaque

import "base:intrinsics"
import "core:bytes"
import "core:mem"

OPAQUE_ALIGNMENT :: #config(OPAQUE_ALIGNMENT, 16)

OpaquePtr :: struct {
	data: rawptr,
	type: typeid,
}

OpaqueBoxed :: struct {
	data:      []byte,
	type:      typeid,
	allocator: mem.Allocator,
}

OpaqueInline :: struct($MaxSize: int) #align (OPAQUE_ALIGNMENT) {
	data: [MaxSize]byte,
	type: typeid,
}

make_opaque_ptr :: proc(ptr: ^$T) -> OpaquePtr {
	return {data = rawptr(ptr), type = T}
}

from_opaque_ptr_safe :: proc(opaque: OpaquePtr, $T: typeid) -> (ptr: ^T, ok: bool) {
	(opaque.type == T) or_return
	return transmute(^T)(opaque.data), true
}

from_opaque_ptr :: proc(opaque: OpaquePtr, $T: typeid) -> ^T {
	for value in from_opaque_ptr_safe(opaque, T) {
		return value
	}
	panic_contextless("Type mismatch")
}

destroy_boxed_opaque :: proc(opaque: ^OpaqueBoxed) {
	if opaque.data != nil {
		delete(opaque.data, opaque.allocator)
	}
	opaque.data = nil
}

make_opaque_dynamic :: proc(
	value: $T,
	allocator := context.allocator,
) -> (
	opaque: OpaqueBoxed,
	err: mem.Allocator_Error,
) {
	opaque.type = T
	opaque.data = mem.make_aligned([]byte, size_of(T), align_of(T), allocator) or_return
	opaque.allocator = allocator
	bytes := transmute([size_of(T)]byte)value
	copy(opaque.data[:], bytes[:])
	return opaque, nil
}

make_opaque_sized :: proc(value: $T, $S: int) -> (opaque: OpaqueInline(S)) {
	#assert(size_of(T) <= S, "Opaque size exceeds maximum size")
	#assert(
		align_of(T) <= align_of(OpaqueInline(S)),
		"The type must have the same alignment as the opaque struct or lower",
	)
	#assert(
		align_of(OpaqueInline(S)) % align_of(T) == 0,
		"The alignment of the opaque struct must be a multiple of the type's alignment",
	)
	opaque.type = T
	bytes := transmute([size_of(T)]byte)value
	copy(opaque.data[:], bytes[:])
	return opaque
}

make_opaque :: proc(value: $T) -> OpaqueInline(size_of(T)) {
	return make_opaque_sized(value, size_of(T))
}

make_opaque_boxed :: proc(
	value: $T,
	allocator := context.allocator,
) -> (
	OpaqueBoxed,
	mem.Allocator_Error,
) {
	return make_opaque_dynamic(value, allocator)
}

get_ptr_safe_inline :: proc "contextless" (
	opaque: ^OpaqueInline($S),
	$T: typeid,
) -> (
	value: ^T,
	ok: bool,
) {
	context = {}
	(opaque.type == T) or_return

	result := transmute(^T)(bytes.ptr_from_bytes(opaque.data[:]))

	p1 := rawptr(&opaque.data)
	p2 := rawptr(result)

	assert(p1 == p2, "Expected pointers to be the same")

	return result, true
}

get_ptr_safe_boxed :: proc "contextless" (
	opaque: ^OpaqueBoxed,
	$T: typeid,
) -> (
	value: ^T,
	ok: bool,
) {
	context = {}
	(opaque.type == T) or_return

	result := transmute(^T)(bytes.ptr_from_bytes(opaque.data))

	p1 := raw_data(opaque.data)
	p2 := rawptr(result)

	assert(p1 == p2, "Expected pointers to be the same")

	return result, true
}

get_ptr_safe :: proc {
	get_ptr_safe_inline,
	get_ptr_safe_boxed,
}

get_value_safe_inline :: proc "contextless" (
	opaque: OpaqueInline($S),
	$T: typeid,
) -> (
	value: T,
	ok: bool,
) {
	(opaque.type == T) or_return
	opaque := opaque
	return mem.reinterpret_copy(T, &opaque.data), true
}

get_value_safe_boxed :: proc "contextless" (
	opaque: OpaqueBoxed,
	$T: typeid,
) -> (
	value: T,
	ok: bool,
) {
	(opaque.type == T) or_return
	opaque := opaque
	return mem.reinterpret_copy(T, raw_data(opaque.data)), true
}

get_value_safe :: proc {
	get_value_safe_inline,
	get_value_safe_boxed,
}

get_ptr_inline :: proc "contextless" (opaque: ^OpaqueInline($S), $T: typeid) -> ^T {
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

get_ptr_boxed :: proc "contextless" (opaque: ^OpaqueBoxed, $T: typeid) -> ^T {
	for value in get_ptr_safe(opaque, T) {
		return value
	}
	panic_contextless("Type mismatch")
}

get_ptr :: proc {
	get_ptr_inline,
	get_ptr_boxed,
}

get_value_inline :: proc "contextless" (opaque: OpaqueInline($S), $T: typeid) -> T {
	for value in get_value_safe(opaque, T) {
		return value
	}
	panic_contextless("Type mismatch")
}

get_value_boxed :: proc "contextless" (opaque: OpaqueBoxed, $T: typeid) -> T {
	for value in get_value_safe(opaque, T) {
		return value
	}
	panic_contextless("Type mismatch")
}

get_value :: proc {
	get_value_inline,
	get_value_boxed,
}
