package opaque

import "core:log"
import "core:mem"
import "core:testing"

@(test)
test_same_bytes_value :: proc(t: ^testing.T) {
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
test_same_bytes_ptr :: proc(t: ^testing.T) {
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
