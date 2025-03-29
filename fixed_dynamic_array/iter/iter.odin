package fixed_dynamic_array_synchronized_iterator

import fda ".."

import "base:runtime"
import "core:mem"

FixedDynamicArraySynchronizedIterator :: struct($T: typeid) {
	array:        ^fda.FixedDynamicArray(T),
	index:        int,
	expected_len: int,
	auto_reset:   bool,
}

@(private = "file")
sync_or_increment :: proc "contextless" (it: ^$A/FixedDynamicArraySynchronizedIterator($T)) {
	if it.index < 0 {
		// we have not started iterating yet, so can safely update the length and increment the index
		it.expected_len = it.array.len
		it.index = 0
		return
	}
	// Check if the array has been modified since the last iteration.
	if it.array.len > it.expected_len {
		// Elements were added to the array
		it.expected_len = it.array.len
		it.index += 1
	} else if it.array.len < it.expected_len {
		// Elements were removed from the array.
		// update the expected length and don't update the index.
		it.expected_len = it.array.len
	} else {
		// The array has not been modified.
		// increment the index and return the next element.
		it.index += 1
	}
}

/// iterates over the array and returns the next element,
/// while trying to keep synchronized with the state of the actual array.
/// the iterator even stays valid, if the array is modified during the iteration
/// by one of the functions that modify the array through the iterator.
next :: proc "contextless" (it: ^$A/FixedDynamicArraySynchronizedIterator($T)) -> (T, bool) {
	if is_dead(it) {
		return {}, false
	}
	sync_or_increment(it)

	if it.index < it.array.len {
		return it.array.data[it.index], true
	}

	// mark dead
	it.expected_len = -1

	if it.auto_reset {
		reset(it)
	}

	return {}, false
}

unordered_remove_index :: proc "contextless" (
	it: ^$A/FixedDynamicArraySynchronizedIterator($T),
	index: int,
	loc := #caller_location,
) #no_bounds_check {
	if is_dead(it) {
		return
	}
	fda.unordered_remove(it.array, index, loc)
	if index < it.index {
		// swap the currently processed item with the item at the index
		// this is safe, because unordered_remove swaps the item at the last valid index
		// with the deleted item
		it.array[it.index] = it.array[index]
	}
	// don't update expected_len, so the iterator knows that the array has been modified
}

ordered_remove_index :: proc "contextless" (
	it: ^$A/FixedDynamicArraySynchronizedIterator($T),
	index: int,
	loc := #caller_location,
) #no_bounds_check {
	if is_dead(it) {
		return
	}
	fda.ordered_remove(it.array, index, loc)
	if index > it.index {
		// if the index is greater than the current index, we need to decrement the expected length
		// so the iterator will properly increment its index when called the next time
		it.expected_len -= 1
	}
	// because ordered_remove keeps the order by copying every item after the deleted one
	// to the the position of the deleted item, thus keeping the order of the array
	// this means, we're at the correct position for the next iteration,
	// because the index is only incremented when the expected length is the same as the current length
}

unordered_remove_ptr :: proc "contextless" (
	it: ^$A/FixedDynamicArraySynchronizedIterator($T),
	ptr: ^T,
	loc := #caller_location,
) #no_bounds_check {
	if is_dead(it) {
		return
	}
	unordered_remove_index(it, index_from_ptr(it.array, ptr), loc)
}

ordered_remove_ptr :: proc "contextless" (
	it: ^$A/FixedDynamicArraySynchronizedIterator($T),
	ptr: ^T,
	loc := #caller_location,
) #no_bounds_check {
	if is_dead(it) {
		return
	}
	ordered_remove_index(it, index_from_ptr(it.array, ptr), loc)
}

unordered_remove_current :: proc "contextless" (
	it: ^$A/FixedDynamicArraySynchronizedIterator($T),
) #no_bounds_check {
	if is_dead(it) {
		return
	}
	fda.unordered_remove(it.array, it.index)
}

ordered_remove_current :: proc "contextless" (
	it: ^$A/FixedDynamicArraySynchronizedIterator($T),
) #no_bounds_check {
	if is_dead(it) {
		return
	}
	fda.ordered_remove(it.array, it.index)
}

@(optimization_mode = "none")
reset :: proc "contextless" (it: ^$A/FixedDynamicArraySynchronizedIterator($T)) {
	it.index = -1
	it.array = it.array
	it.expected_len = it.array.len
}

is_dead :: proc "contextless" (it: ^$A/FixedDynamicArraySynchronizedIterator($T)) -> bool {
	return it.expected_len < 0
}

make_sync_iter :: proc "contextless" (
	a: ^$A/fda.FixedDynamicArray($T),
	auto_reset: bool = true,
) -> FixedDynamicArraySynchronizedIterator(T) {
	return {a, -1, fda.len(a^), auto_reset}
}

@(private)
index_from_ptr :: proc "contextless" (
	it: ^$A/FixedDynamicArraySynchronizedIterator($T),
	ptr: ^T,
) -> int {
	return mem.ptr_sub(ptr, &it.array.data[0])
}

push_back :: proc "contextless" (
	a: ^$A/FixedDynamicArraySynchronizedIterator($T),
	item: T,
) -> (
	ok: bool,
) {
	ok = fda.push_back(a.array, item)
	if ok {
		a.expected_len += 1
	}
	return
}

pop_back :: proc "odin" (
	a: ^$A/FixedDynamicArraySynchronizedIterator($T),
	loc := #caller_location,
) -> T {
	fda.pop_back(a.array, item)
	a.expected_len -= 1
}

pop_back_safe :: proc "contextless" (
	a: ^$A/FixedDynamicArraySynchronizedIterator($T),
) -> (
	item: T,
	ok: bool,
) {
	item, ok = fda.pop_back_safe(a)
	if ok {
		a.expected_len -= 1
	}
}

clear :: proc "contextless" (a: ^$A/FixedDynamicArraySynchronizedIterator($T)) {
	fda.clear(a.array)
	a.expected_len = 0
}

push_back_elems :: proc "contextless" (
	a: ^$A/FixedDynamicArraySynchronizedIterator($T),
	items: ..T,
) -> (
	ok: bool,
) {
	count := len(items)
	ok = fda.push_back_elems(a, ..items)
	if ok {
		a.expected_len += count
	}
}

unordered_remove :: proc {
	unordered_remove_index,
	unordered_remove_ptr,
}
ordered_remove :: proc {
	ordered_remove_index,
	ordered_remove_ptr,
}

append_elem :: push_back
append_elems :: push_back_elems
push :: proc {
	push_back,
	push_back_elems,
}
append :: proc {
	push_back,
	push_back_elems,
}
