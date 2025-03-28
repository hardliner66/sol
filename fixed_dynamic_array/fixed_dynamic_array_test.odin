package fixed_dynamic_array

import "core:mem"
import "core:testing"

@(test)
test_fixed_dynamic_array :: proc(t: ^testing.T) {
	// Test creation
	arr := create(int, 5)
	defer destroy(&arr)

	old_alloc := context.allocator
	context.allocator = mem.panic_allocator()
	defer context.allocator = old_alloc

	old_temp_alloc := context.temp_allocator
	context.temp_allocator = mem.panic_allocator()
	defer context.temp_allocator = old_temp_alloc

	testing.expect(t, len(arr) == 0)
	testing.expect(t, cap(arr) == 5)

	// Test push_back
	testing.expect(t, push_back(&arr, 10))
	testing.expect(t, push_back(&arr, 20))
	testing.expect(t, len(arr) == 2)
	testing.expect(t, get(arr, 0) == 10)
	testing.expect(t, get(arr, 1) == 20)

	// Test push_front
	testing.expect(t, push_front(&arr, 5))
	testing.expect(t, len(arr) == 3)
	testing.expect(t, get(arr, 0) == 5)
	testing.expect(t, get(arr, 1) == 10)

	// Test pop_back
	item := pop_back(&arr)
	testing.expect(t, item == 20)
	testing.expect(t, len(arr) == 2)

	// Test pop_front
	item = pop_front(&arr)
	testing.expect(t, item == 5)
	testing.expect(t, len(arr) == 1)

	// Test get_safe
	val, ok := get_safe(arr, 0)
	testing.expect(t, ok)
	testing.expect(t, val == 10)
	_, ok = get_safe(arr, 1)
	testing.expect(t, !ok)

	// Test push_back_elems
	testing.expect(t, push_back_elems(&arr, 30, 40, 50))
	testing.expect(t, len(arr) == 4)
	testing.expect(t, get(arr, 1) == 30)
	testing.expect(t, get(arr, 3) == 50)

	// Test inject_at
	testing.expect(t, inject_at(&arr, 25, 1))
	testing.expect(t, len(arr) == 5)
	testing.expect(t, get(arr, 1) == 25)
	testing.expect(t, get(arr, 2) == 30)

	// Test ordered_remove
	ordered_remove(&arr, 1)
	testing.expect(t, len(arr) == 4)
	testing.expect(t, get(arr, 1) == 30)

	// Test unordered_remove_index
	unordered_remove_index(&arr, 1)
	testing.expect(t, len(arr) == 3)

	// Test clear
	clear(&arr)
	testing.expect(t, len(arr) == 0)

	// Test resize
	resize(&arr, 10)
	testing.expect(t, cap(arr) == 10)
	testing.expect(t, len(arr) == 0)
}
