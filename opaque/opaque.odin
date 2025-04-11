package opaque

import "base:intrinsics"
@(require) import "core:bytes"
import "core:mem"

OPAQUE_ALIGNMENT :: #config(OPAQUE_ALIGNMENT, 16)

Opaque_Ptr :: struct {
	data: rawptr,
	type: typeid,
}

Opaque_Boxed :: struct {
	data:      []byte,
	type:      typeid,
	allocator: mem.Allocator,
}

Opaque_Inline :: struct($MaxSize: int, $Align := OPAQUE_ALIGNMENT) #align (Align) {
	data: [MaxSize]byte,
	type: typeid,
}

Opaque :: union($MaxSizeIfInline: int, $Align := OPAQUE_ALIGNMENT) {
	Opaque_Ptr,
	Opaque_Boxed,
	Opaque_Inline(MaxSizeIfInline, Align),
}

make_opaque_ptr :: proc(ptr: ^$T) -> Opaque_Ptr {
	return {data = ptr, type = T}
}

from_opaque_ptr_safe :: proc(opaque: Opaque_Ptr, $T: typeid) -> (ptr: ^T, ok: bool) {
	(opaque.type == T) or_return
	return transmute(^T)opaque.data, true
}

from_opaque_ptr :: proc(opaque: Opaque_Ptr, $T: typeid) -> ^T {
	for value in from_opaque_ptr_safe(opaque, T) {
		return value
	}
	panic("Type mismatch")
}

value_from_opaque_ptr_safe :: proc "contextless" (
	opaque: Opaque_Ptr,
	$T: typeid,
) -> (
	value: T,
	ok: bool,
) {
	(opaque.type == T) or_return
	return (transmute(^T)(opaque.data))^, true
}

value_from_opaque_ptr :: proc "contextless" (opaque: Opaque_Ptr, $T: typeid) -> T {
	for value in value_from_opaque_ptr_safe(opaque, T) {
		return value
	}
	panic_contextless("Type mismatch")
}

destroy_boxed_opaque :: proc(opaque: ^Opaque_Boxed) {
	if opaque.data != nil {
		delete(opaque.data, opaque.allocator)
	}
	opaque.data = nil
}

make_opaque_dynamic :: proc(
	value: $T,
	allocator := context.allocator,
) -> (
	opaque: Opaque_Boxed,
	err: mem.Allocator_Error,
) {
	opaque.type = T
	opaque.data = mem.make_aligned([]byte, size_of(T), align_of(T), allocator) or_return
	opaque.allocator = allocator
	bytes := transmute([size_of(T)]byte)value
	copy(opaque.data[:], bytes[:])
	return opaque, nil
}

make_opaque_sized :: proc(value: $T, $S: int) -> (opaque: Opaque_Inline(S)) {
	#assert(size_of(T) <= S, "Opaque size exceeds maximum size")
	#assert(
		align_of(T) <= align_of(Opaque_Inline(S)),
		"The type must have the same alignment as the opaque struct or lower",
	)
	#assert(
		align_of(Opaque_Inline(S)) % align_of(T) == 0,
		"The alignment of the opaque struct must be a multiple of the type's alignment",
	)
	opaque.type = T
	bytes := transmute([size_of(T)]byte)value
	copy(opaque.data[:], bytes[:])
	return opaque
}

make_opaque :: proc(value: $T) -> Opaque_Inline(size_of(T)) {
	return make_opaque_sized(value, size_of(T))
}

make_opaque_boxed :: proc(
	value: $T,
	allocator := context.allocator,
) -> (
	Opaque_Boxed,
	mem.Allocator_Error,
) {
	return make_opaque_dynamic(value, allocator)
}

get_ptr_safe_inline :: proc "contextless" (
	opaque: ^Opaque_Inline($S),
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
	opaque: ^Opaque_Boxed,
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

get_ptr_safe_union :: proc(op: ^$O/Opaque($MaxSizeIfInline), $T: typeid) -> (value: ^T, ok: bool) {
	switch &o in op {
	case Opaque_Inline(MaxSizeIfInline):
		return get_ptr_safe_inline(&o, T)
	case Opaque_Boxed:
		return get_ptr_safe_boxed(&o, T)
	case Opaque_Ptr:
		tmp := from_opaque_ptr_safe(o, T) or_return
		return tmp, true
	}
	panic("Could not get pointer from opaque")
}

get_ptr_safe :: proc {
	get_ptr_safe_inline,
	get_ptr_safe_boxed,
	get_ptr_safe_union,
	from_opaque_ptr_safe,
}

get_value_safe_inline :: proc "contextless" (
	opaque: Opaque_Inline($S),
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
	opaque: Opaque_Boxed,
	$T: typeid,
) -> (
	value: T,
	ok: bool,
) {
	(opaque.type == T) or_return
	opaque := opaque
	return mem.reinterpret_copy(T, raw_data(opaque.data)), true
}

get_value_safe_union :: proc(op: $O/Opaque($MaxSizeIfInline), $T: typeid) -> (value: T, ok: bool) {
	switch &o in op {
	case Opaque_Inline(MaxSizeIfInline):
		return get_value_safe_inline(o, T)
	case Opaque_Boxed:
		return get_value_safe_boxed(o, T)
	case Opaque_Ptr:
		tmp := from_opaque_ptr_safe(o, T) or_return
		return tmp^, true
	}
	panic("Could not get value from opaque")
}

get_value_safe :: proc {
	get_value_safe_inline,
	get_value_safe_boxed,
	get_value_safe_union,
	value_from_opaque_ptr_safe,
}

get_ptr_inline :: proc "contextless" (opaque: ^Opaque_Inline($S), $T: typeid) -> ^T {
	// I just found out that instead of doing
	// if var, ok := some_proc(); ok {}
	// you can use
	// for var in some_proc() {}
	// which seems a bit simpler,
	// though it might lead to some confusion ;)
	for value in get_ptr_safe_inline(opaque, T) {
		return value
	}
	panic_contextless("Type mismatch")
}

get_ptr_boxed :: proc "contextless" (opaque: ^Opaque_Boxed, $T: typeid) -> ^T {
	for value in get_ptr_safe_boxed(opaque, T) {
		return value
	}
	panic_contextless("Type mismatch")
}

get_ptr_union :: proc(op: ^$O/Opaque($MaxSizeIfInline), $T: typeid) -> ^T {
	switch &o in op {
	case Opaque_Inline(MaxSizeIfInline):
		return get_ptr_inline(&o, T)
	case Opaque_Boxed:
		return get_ptr_boxed(&o, T)
	case Opaque_Ptr:
		tmp := from_opaque_ptr(o, T)
		return tmp
	}
	panic("Could not get pointer from opaque")
}

get_ptr :: proc {
	get_ptr_inline,
	get_ptr_boxed,
	get_ptr_union,
	from_opaque_ptr,
}

get_value_inline :: proc "contextless" (opaque: Opaque_Inline($S), $T: typeid) -> T {
	for value in get_value_safe_inline(opaque, T) {
		return value
	}
	panic_contextless("Type mismatch")
}

get_value_boxed :: proc "contextless" (opaque: Opaque_Boxed, $T: typeid) -> T {
	for value in get_value_safe_boxed(opaque, T) {
		return value
	}
	panic_contextless("Type mismatch")
}

get_value_union :: proc(op: Opaque($MaxSizeIfInline), $T: typeid) -> T {
	switch &o in op {
	case Opaque_Inline(MaxSizeIfInline):
		return get_value_inline(o, T)
	case Opaque_Boxed:
		return get_value_boxed(o, T)
	case Opaque_Ptr:
		tmp := from_opaque_ptr(o, T)
		return tmp^
	}
	panic("Could not get value from opaque")
}

get_value :: proc {
	get_value_inline,
	get_value_boxed,
	get_value_union,
	value_from_opaque_ptr,
}
