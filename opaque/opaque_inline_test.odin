package opaque

import "core:mem"
import "core:testing"

@(test)
inline_test_same_bytes_value :: proc(t: ^testing.T) {
	SomeType :: struct {
		a: int,
		b: f32,
	}
	original_value := SomeType {
		a = 42,
		b = 3.14,
	}
	// api usage
	original_value_ptr := &original_value
	opaque := make_opaque(original_value)
	new := get_value(opaque, SomeType)

	// tests
	new_ptr := &new
	old_bytes := mem.ptr_to_bytes(original_value_ptr)
	opaque_bytes := opaque.data[0:size_of(SomeType)]
	new_bytes := mem.ptr_to_bytes(new_ptr)

	testing.expect(t, original_value_ptr != new_ptr, "Expected different pointers")
	testing.expectf(
		t,
		mem.compare(old_bytes, opaque_bytes) == 0,
		"Expected same bytes 1, got %v :: %v",
		old_bytes,
		opaque_bytes,
	)
	testing.expectf(
		t,
		mem.compare(opaque_bytes, new_bytes) == 0,
		"Expected same bytes 2, got %v :: %v",
		opaque_bytes,
		new_bytes,
	)
}

@(test)
inline_test_same_bytes_ptr :: proc(t: ^testing.T) {
	SomeType :: struct {
		a: int,
		b: f32,
	}
	original_value := SomeType {
		a = 42,
		b = 3.14,
	}
	// api usage
	original_value_ptr := &original_value
	opaque := make_opaque(original_value)
	new_ptr := get_ptr(&opaque, SomeType)

	// tests
	old_bytes := mem.ptr_to_bytes(original_value_ptr)
	opaque_bytes := opaque.data[0:size_of(SomeType)]
	new_bytes := mem.ptr_to_bytes(new_ptr)

	testing.expect(t, original_value_ptr != new_ptr, "Expected different pointer than original")

	p1 := rawptr(new_ptr)
	p2 := rawptr(&opaque.data)

	// any idea why the pointers are different by a small amount? 0x1001FF7D0 :: 0x1001FF7A0
	testing.expectf(
		t,
		p1 == p2,
		"Expected same pointer than opaque, got %p :: %p :: %v",
		p1,
		p2,
		uintptr(p1) - uintptr(p2),
	)
	testing.expectf(
		t,
		mem.compare(old_bytes, opaque_bytes) == 0,
		"Expected same bytes 1, got %v :: %v",
		old_bytes,
		opaque_bytes,
	)
	testing.expectf(
		t,
		mem.compare(opaque_bytes, new_bytes) == 0,
		"Expected same bytes 2, got %v :: %v",
		opaque_bytes,
		new_bytes,
	)
}

@(test)
inline_test_opaque_with_different_types :: proc(t: ^testing.T) {
	IntType :: struct {
		a: int,
	}
	FloatType :: struct {
		b: f32,
	}
	ComplexType :: struct {
		x: int,
		y: f32,
		z: string,
	}

	int_value := IntType {
		a = 123,
	}
	float_value := FloatType {
		b = 3.14,
	}
	complex_value := ComplexType {
		x = 42,
		y = 2.71,
		z = "hello",
	}

	int_opaque := make_opaque(int_value)
	float_opaque := make_opaque(float_value)
	complex_opaque := make_opaque(complex_value)

	int_new := get_value(int_opaque, IntType)
	float_new := get_value(float_opaque, FloatType)
	complex_new := get_value(complex_opaque, ComplexType)

	testing.expect(t, int_value == int_new, "Expected int values to match")
	testing.expect(t, float_value == float_new, "Expected float values to match")
	testing.expect(t, complex_value == complex_new, "Expected complex values to match")
}

@(test)
inline_test_opaque_alignment :: proc(t: ^testing.T) {
	AlignedType :: struct #align (16) {
		a: int,
		b: f32,
	}
	aligned_value := AlignedType {
		a = 42,
		b = 3.14,
	}

	opaque := make_opaque(aligned_value)
	new_value := get_value(opaque, AlignedType)

	testing.expect(t, aligned_value == new_value, "Expected aligned values to match")

	v := uintptr(rawptr(&opaque.data)) % align_of(AlignedType) == 0
	testing.expectf(
		t,
		v,
		"Expected opaque data to be aligned to %v bytes, but was %v",
		align_of(AlignedType),
		v,
	)
}

@(test)
inline_test_opaque_large_struct :: proc(t: ^testing.T) {
	LargeType :: struct {
		data: [1024]u8,
	}
	large_value := LargeType {
		data = {0 = 1, 1 = 2, 2 = 3},
	}

	opaque := make_opaque(large_value)
	new_value := get_value(opaque, LargeType)

	testing.expect(t, large_value == new_value, "Expected large struct values to match")
}

@(test)
inline_test_opaque_zero_sized_type :: proc(t: ^testing.T) {
	ZeroSizedType :: struct {
	}
	zero_value := ZeroSizedType{}

	opaque := make_opaque(zero_value)
	new_value := get_value(opaque, ZeroSizedType)

	testing.expect(t, zero_value == new_value, "Expected zero-sized type values to match")
}

@(test)
inline_test_opaque_nested_structs :: proc(t: ^testing.T) {
	NestedType :: struct {
		a: int,
		b: struct {
			c: f32,
			d: string,
		},
	}
	nested_value := NestedType {
		a = 42,
		b = {c = 3.14, d = "nested"},
	}

	opaque := make_opaque(nested_value)
	new_value := get_value(opaque, NestedType)

	testing.expect(t, nested_value == new_value, "Expected nested struct values to match")
}

@(test)
inline_test_opaque_pointer_handling :: proc(t: ^testing.T) {
	PointerType :: struct {
		ptr: ^int,
	}
	value := 42
	pointer_value := PointerType {
		ptr = &value,
	}

	opaque := make_opaque(pointer_value)
	new_value := get_value(opaque, PointerType)

	testing.expect(t, pointer_value.ptr == new_value.ptr, "Expected pointers to match")
	testing.expect(
		t,
		pointer_value.ptr^ == new_value.ptr^,
		"Expected dereferenced pointer values to match",
	)
}

@(test)
inline_test_opaque_array_handling :: proc(t: ^testing.T) {
	ArrayType :: [5]int
	array_value := ArrayType{1, 2, 3, 4, 5}

	opaque := make_opaque(array_value)
	new_value := get_value(opaque, ArrayType)

	testing.expect(t, array_value == new_value, "Expected array values to match")
}

@(test)
inline_test_opaque_invalid_cast :: proc(t: ^testing.T) {
	SomeType :: struct {
		a: int,
	}
	OtherType :: struct {
		b: f32,
	}

	value := SomeType {
		a = 42,
	}
	opaque := make_opaque(value)

	_, ok := get_value_safe(opaque, OtherType) // This should panic
	testing.expect(t, !ok, "Expected panic on invalid cast")
}
