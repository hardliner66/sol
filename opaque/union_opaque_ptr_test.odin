package opaque

import "core:testing"

@(test)
union_ptr_test_opaque_ptr_basic :: proc(t: ^testing.T) {
	Pointer_Type :: struct {
		ptr: ^int,
	}
	value := 42
	pointer_value := Pointer_Type {
		ptr = &value,
	}

	opaque_ptr: Opaque(0) = make_opaque_ptr(pointer_value.ptr)
	new_ptr := get_ptr(&opaque_ptr, int)

	testing.expect(t, pointer_value.ptr == new_ptr, "Expected pointers to match")
	testing.expect(
		t,
		pointer_value.ptr^ == new_ptr^,
		"Expected dereferenced pointer values to match",
	)
}

@(test)
union_ptr_test_opaque_ptr_nested :: proc(t: ^testing.T) {
	Nested_Pointer_Type :: struct {
		ptr: ^^int,
	}
	value := 42
	value_ptr := &value
	nested_pointer_value := Nested_Pointer_Type {
		ptr = &value_ptr,
	}

	opaque_ptr: Opaque(0) = make_opaque_ptr(nested_pointer_value.ptr)
	new_ptr := get_ptr(&opaque_ptr, ^int)

	testing.expect(t, nested_pointer_value.ptr == new_ptr, "Expected nested pointers to match")
	testing.expect(
		t,
		nested_pointer_value.ptr^^ == new_ptr^^,
		"Expected dereferenced nested pointer values to match",
	)
}

@(test)
union_ptr_test_opaque_ptr_invalid_cast :: proc(t: ^testing.T) {
	Pointer_Type :: struct {
		ptr: ^int,
	}
	Other_Pointer_Type :: struct {
		ptr: ^f32,
	}

	value := 42
	pointer_value := Pointer_Type {
		ptr = &value,
	}

	opaque_ptr: Opaque(0) = make_opaque_ptr(pointer_value.ptr)

	_, ok := get_ptr_safe(&opaque_ptr, f32) // This should return false
	testing.expect(t, !ok, "Expected nok on invalid pointer cast")
}
