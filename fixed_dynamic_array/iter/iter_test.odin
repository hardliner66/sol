package fixed_dynamic_array_synchronized_iterator

import fda ".."
import "core:log"

import "core:testing"

@(test)
tests :: proc(t: ^testing.T) {
	// Test FixedDynamicArray basic functionality
	array := fda.create(int, 10)
	defer fda.destroy(&array)

	item: int
	index: int
	ok: bool

	testing.expect(t, fda.len(array) == 0)
	testing.expect(t, fda.cap(array) == 10)

	ok = fda.push_back(&array, 1)
	testing.expect(t, ok)
	testing.expect(t, fda.len(array) == 1)
	testing.expect(t, fda.get(array, 0) == 1)

	ok = fda.push_back(&array, 2)
	testing.expect(t, ok)
	testing.expect(t, fda.len(array) == 2)
	testing.expect(t, fda.get(array, 1) == 2)

	item, ok = fda.pop_back_safe(&array)
	testing.expect(t, ok)
	testing.expect(t, item == 2)
	testing.expect(t, fda.len(array) == 1)

	// Test FixedDynamicArray synchronized iterator
	iter := make_sync_iter(&array, auto_reset = true)

	// Add elements to the array
	fda.push_back(&array, 3)
	fda.push_back(&array, 4)
	fda.push_back(&array, 5)

	// Iterate over the array
	for item, index in next(&iter) {
		testing.expect(t, item == array.data[index])
	}

	// Test removing elements during iteration
	iter = make_sync_iter(&array, auto_reset = false)
	for item, index in next(&iter) {
		if item == 3 {
			unordered_remove_index(&iter, index)
		}
	}
	testing.expectf(t, fda.len(array) == 3, "Expected length 2, got %d", fda.len(array))
	testing.expect(t, fda.get(array, 0) == 1)
	testing.expect(t, fda.get(array, 1) == 5)

	// Test adding elements during iteration
	iter = make_sync_iter(&array, auto_reset = false)
	for item in next(&iter) {
		if item == 5 {
			push_back(&iter, 6)
		}
	}
	testing.expect(t, fda.len(array) == 4)
	testing.expect(t, fda.get(array, 2) == 4)

	// Test clearing the array
	reset(&iter)
	clear(&iter)
	testing.expectf(t, fda.len(array) == 0, "Expected length 0, got %d", fda.len(array))

	// Test reset functionality
	iter = make_sync_iter(&array, auto_reset = true)
	fda.push_back(&array, 7)
	fda.push_back(&array, 8)
	ok = reset(&iter)
	testing.expect(t, ok)
	item, index, ok = next(&iter)
	testing.expect(t, ok)
	testing.expect(t, item == 7)
	testing.expect(t, index == 0)

	// Test iterator dead state
	iter = make_sync_iter(&array, auto_reset = false)
	fda.clear(&array)
	_, _, ok = next(&iter)
	testing.expect(t, !ok)
}
