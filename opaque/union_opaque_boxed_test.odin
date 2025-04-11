package opaque

import "core:mem"
import "core:testing"

@(test)
union_boxed_test_same_bytes_value :: proc(t: ^testing.T) {
	Some_Type :: struct {
		a: int,
		b: f32,
	}
	original_value := Some_Type {
		a = 42,
		b = 3.14,
	}
	// api usage
	original_value_ptr := &original_value
	o, err := make_opaque_boxed(original_value)
	assert(err == nil)
	defer destroy_boxed_opaque(&o)

	opaque: Opaque(0) = o

	new := get_value(opaque, Some_Type)

	// tests
	new_ptr := &new
	old_bytes := mem.ptr_to_bytes(original_value_ptr)
	opaque_bytes := mem.ptr_to_bytes(get_ptr(&opaque, Some_Type))
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
union_boxed_test_same_bytes_ptr :: proc(t: ^testing.T) {
	Some_Type :: struct {
		a: int,
		b: f32,
	}
	original_value := Some_Type {
		a = 42,
		b = 3.14,
	}
	// api usage
	original_value_ptr := &original_value
	o, err := make_opaque_boxed(original_value)
	assert(err == nil)
	defer destroy_boxed_opaque(&o)

	opaque: Opaque(0) = o

	new_ptr := get_ptr(&opaque, Some_Type)

	// tests
	old_bytes := mem.ptr_to_bytes(original_value_ptr)
	opaque_bytes := mem.ptr_to_bytes(get_ptr(&opaque, Some_Type))
	new_bytes := mem.ptr_to_bytes(new_ptr)

	testing.expect(t, original_value_ptr != new_ptr, "Expected different pointer than original")

	p1 := rawptr(new_ptr)
	p2 := get_ptr(&opaque, Some_Type)

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
union_boxed_test_opaque_with_different_types :: proc(t: ^testing.T) {
	Complex_Type :: struct {
		x: int,
		y: f32,
		z: string,
	}

	int_value: int = 123
	float_value: f32 = 3.14
	complex_value := Complex_Type {
		x = 42,
		y = 2.71,
		z = "hello",
	}

	err: mem.Allocator_Error

	int_o: Opaque_Boxed
	int_o, err = make_opaque_boxed(int_value)
	assert(err == nil)
	defer destroy_boxed_opaque(&int_o)
	float_o: Opaque_Boxed
	float_o, err = make_opaque_boxed(float_value)
	assert(err == nil)
	defer destroy_boxed_opaque(&float_o)
	complex_o: Opaque_Boxed
	complex_o, err = make_opaque_boxed(complex_value)
	assert(err == nil)
	defer destroy_boxed_opaque(&complex_o)

	int_opaque: Opaque(0) = int_o
	float_opaque: Opaque(0) = float_o
	complex_opaque: Opaque(0) = complex_o

	int_new := get_value(int_opaque, int)
	float_new := get_value(float_opaque, f32)
	complex_new := get_value(complex_opaque, Complex_Type)

	testing.expect(t, int_value == int_new, "Expected int values to match")
	testing.expect(t, float_value == float_new, "Expected float values to match")
	testing.expect(t, complex_value == complex_new, "Expected complex values to match")
}

@(test)
union_boxed_test_opaque_alignment :: proc(t: ^testing.T) {
	Aligned_Type :: struct #align (16) {
		a: int,
		b: f32,
	}
	aligned_value := Aligned_Type {
		a = 42,
		b = 3.14,
	}

	o, err := make_opaque_boxed(aligned_value)
	assert(err == nil)
	defer destroy_boxed_opaque(&o)

	opaque: Opaque(0) = o

	new_value := get_value(opaque, Aligned_Type)

	testing.expect(t, aligned_value == new_value, "Expected aligned values to match")

	v := uintptr(get_ptr(&opaque, Aligned_Type)) % align_of(Aligned_Type) == 0
	testing.expectf(
		t,
		v,
		"Expected opaque data to be aligned to %v bytes, but was %v",
		align_of(Aligned_Type),
		v,
	)
}

@(test)
union_boxed_test_opaque_large_struct :: proc(t: ^testing.T) {
	Large_Type :: struct {
		data: [1024]u8,
	}
	large_value := Large_Type {
		data = {0 = 1, 1 = 2, 2 = 3},
	}

	o, err := make_opaque_boxed(large_value)
	assert(err == nil)
	defer destroy_boxed_opaque(&o)

	opaque: Opaque(0) = o

	new_value := get_value(opaque, Large_Type)

	testing.expect(t, large_value == new_value, "Expected large struct values to match")
}

@(test)
union_boxed_test_opaque_zero_sized_type :: proc(t: ^testing.T) {
	Zero_Sized_Type :: struct {
	}
	zero_value := Zero_Sized_Type{}

	o, err := make_opaque_boxed(zero_value)
	assert(err == nil)
	defer destroy_boxed_opaque(&o)

	opaque: Opaque(0) = o

	new_value := get_value(opaque, Zero_Sized_Type)

	testing.expect(t, zero_value == new_value, "Expected zero-sized type values to match")
}

@(test)
union_boxed_test_opaque_nested_structs :: proc(t: ^testing.T) {
	Nested_Type :: struct {
		a: int,
		b: struct {
			c: f32,
			d: string,
		},
	}
	nested_value := Nested_Type {
		a = 42,
		b = {c = 3.14, d = "nested"},
	}

	o, err := make_opaque_boxed(nested_value)
	assert(err == nil)
	defer destroy_boxed_opaque(&o)

	opaque: Opaque(0) = o

	new_value := get_value(opaque, Nested_Type)

	testing.expect(t, nested_value == new_value, "Expected nested struct values to match")
}

@(test)
union_boxed_test_opaque_pointer_handling :: proc(t: ^testing.T) {
	Pointer_Type :: struct {
		ptr: ^int,
	}
	value := 42
	pointer_value := Pointer_Type {
		ptr = &value,
	}

	o, err := make_opaque_boxed(pointer_value)
	assert(err == nil)
	defer destroy_boxed_opaque(&o)

	opaque: Opaque(0) = o

	new_value := get_value(opaque, Pointer_Type)

	testing.expect(t, pointer_value.ptr == new_value.ptr, "Expected pointers to match")
	testing.expect(
		t,
		pointer_value.ptr^ == new_value.ptr^,
		"Expected dereferenced pointer values to match",
	)
}

@(test)
union_boxed_test_opaque_array_handling :: proc(t: ^testing.T) {
	Array_Type :: [5]int
	array_value := Array_Type{1, 2, 3, 4, 5}

	o, err := make_opaque_boxed(array_value)
	assert(err == nil)
	defer destroy_boxed_opaque(&o)

	opaque: Opaque(0) = o

	new_value := get_value(opaque, Array_Type)

	testing.expect(t, array_value == new_value, "Expected array values to match")
}

@(test)
union_boxed_test_opaque_invalid_cast :: proc(t: ^testing.T) {
	Some_Type :: struct {
		a: int,
	}
	Other_Type :: struct {
		b: f32,
	}

	value := Some_Type {
		a = 42,
	}
	o, err := make_opaque_boxed(value)
	assert(err == nil)
	defer destroy_boxed_opaque(&o)

	opaque: Opaque(0) = o

	_, ok := get_value_safe(opaque, Other_Type) // This should return false
	testing.expect(t, !ok, "Expected nok on invalid cast")
}
