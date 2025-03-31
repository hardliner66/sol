package opaque

import "core:testing"

@(test)
ptr_test_opaque_ptr_basic :: proc(t: ^testing.T) {
	PointerType :: struct {
		ptr: ^int,
	}
	value := 42
	pointer_value := PointerType {
		ptr = &value,
	}

	opaque_ptr := make_opaque_ptr(pointer_value.ptr)
	new_ptr := from_opaque_ptr(opaque_ptr, int)

	testing.expect(t, pointer_value.ptr == new_ptr, "Expected pointers to match")
	testing.expect(
		t,
		pointer_value.ptr^ == new_ptr^,
		"Expected dereferenced pointer values to match",
	)
}

@(test)
ptr_test_opaque_ptr_nested :: proc(t: ^testing.T) {
	NestedPointerType :: struct {
		ptr: ^^int,
	}
	value := 42
	value_ptr := &value
	nested_pointer_value := NestedPointerType {
		ptr = &value_ptr,
	}

	opaque_ptr := make_opaque_ptr(nested_pointer_value.ptr)
	new_ptr := from_opaque_ptr(opaque_ptr, ^int)

	testing.expect(t, nested_pointer_value.ptr == new_ptr, "Expected nested pointers to match")
	testing.expect(
		t,
		nested_pointer_value.ptr^^ == new_ptr^^,
		"Expected dereferenced nested pointer values to match",
	)
}

@(test)
ptr_test_opaque_ptr_invalid_cast :: proc(t: ^testing.T) {
	PointerType :: struct {
		ptr: ^int,
	}
	OtherPointerType :: struct {
		ptr: ^f32,
	}

	value := 42
	pointer_value := PointerType {
		ptr = &value,
	}

	opaque_ptr := make_opaque_ptr(pointer_value.ptr)

	_, ok := from_opaque_ptr_safe(opaque_ptr, f32) // This should panic
	testing.expect(t, !ok, "Expected panic on invalid pointer cast")
}
