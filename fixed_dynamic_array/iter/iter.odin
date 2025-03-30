package fixed_dynamic_array_synchronized_iterator

import fda ".."
import ba "../../iter"

import "core:mem"

FixedDynamicArraySynchronizedIteratorState :: struct($T: typeid) {
	using base:   ba.BaseState,
	array:        ^fda.FixedDynamicArray(T),
	expected_len: int,
	auto_reset:   bool,
}

/// iterates over the array and returns the next element,
/// while trying to keep synchronized with the state of the actual array.
/// the iterator even stays valid, if the array is modified during the iteration
/// by one of the functions that modify the array through the iterator.
next_ref :: ba.next_ref
next_val :: ba.next_val
reset :: ba.reset

unordered_remove_index :: proc "contextless" (
	it: ^$I/ba.OpaqueIterator($T),
	index: int,
	loc := #caller_location,
) #no_bounds_check {
	if is_dead(it) {
		return
	}
	state := ba.state(it, FixedDynamicArraySynchronizedIteratorState(T))
	fda.unordered_remove(state.array, index, loc)
	if index < state.index {
		// swap the currently processed item with the item at the index
		// this is safe, because unordered_remove swaps the item at the last valid index
		// with the deleted item
		state.array.data[state.index] = state.array.data[index]
	}
	// don't update expected_len, so the iterator knows that the array has been modified
}

ordered_remove_index :: proc "contextless" (
	it: ^$I/ba.OpaqueIterator($T),
	index: int,
	loc := #caller_location,
) #no_bounds_check {
	if is_dead(it) {
		return
	}
	state := ba.state(it, FixedDynamicArraySynchronizedIteratorState(T))
	fda.ordered_remove(state.array, index, loc)
	if index > state.index {
		// if the index is greater than the current index, we need to decrement the expected length
		// so the iterator will properly increment its index when called the next time
		state.expected_len -= 1
	}
	// because ordered_remove keeps the order by copying every item after the deleted one
	// to the the position of the deleted item, thus keeping the order of the array
	// this means, we're at the correct position for the next iteration,
	// because the index is only incremented when the expected length is the same as the current length
}

@(private)
is_dead :: proc "contextless" (it: ^$I/ba.OpaqueIterator($T)) -> bool {
	state := ba.state(it, FixedDynamicArraySynchronizedIteratorState(T))
	return state.expected_len < 0
}

@(private)
is_dead_state :: proc "contextless" (
	state: ^$I/FixedDynamicArraySynchronizedIteratorState($T),
) -> bool {
	return state.expected_len < 0
}

unordered_remove_ptr :: proc "contextless" (
	it: ^$I/ba.OpaqueIterator($T),
	ptr: ^T,
	loc := #caller_location,
) #no_bounds_check {
	if is_dead(it) {
		return
	}
	unordered_remove_index(it, index_from_ptr(it, ptr), loc)
}

ordered_remove_ptr :: proc "contextless" (
	it: ^$I/ba.OpaqueIterator($T),
	ptr: ^T,
	loc := #caller_location,
) #no_bounds_check {
	if is_dead(it) {
		return
	}
	ordered_remove_index(it, index_from_ptr(it, ptr), loc)
}

unordered_remove_current :: proc "contextless" (it: ^$I/ba.OpaqueIterator($T)) #no_bounds_check {
	if is_dead(it) {
		return
	}
	state := ba.state(it, FixedDynamicArraySynchronizedIteratorState(T))
	fda.unordered_remove(state.array, state.index)
}

ordered_remove_current :: proc "contextless" (it: ^$I/ba.OpaqueIterator($T)) #no_bounds_check {
	if is_dead(it) {
		return
	}
	fda.ordered_remove(it.state.array, it.state.index)
}

push_back :: proc "contextless" (it: ^$I/ba.OpaqueIterator($T), item: T) -> (ok: bool) {
	if is_dead(it) {
		return false
	}
	state := ba.state(it, FixedDynamicArraySynchronizedIteratorState(T))
	ok = fda.push_back(state.array, item)
	if ok {
		state.expected_len += 1
	}
	return
}

pop_back_safe :: proc "contextless" (it: ^$I/ba.OpaqueIterator($T)) -> (item: T, ok: bool) {
	is_dead(it) or_return
	state := ba.state(it, FixedDynamicArraySynchronizedIteratorState(T))
	item = fda.pop_back_safe(state.array) or_return
	state.expected_len -= 1
	return
}

clear :: proc "contextless" (it: ^$I/ba.OpaqueIterator($T)) {
	if is_dead(it) {
		return
	}
	state := ba.state(it, FixedDynamicArraySynchronizedIteratorState(T))
	fda.clear(state.array)
	state.expected_len = 0
}

push_back_elems :: proc "contextless" (it: ^$I/ba.OpaqueIterator($T), items: ..T) -> (ok: bool) {
	is_dead(it) or_return
	count := len(items)
	state := ba.state(it, FixedDynamicArraySynchronizedIteratorState(T))
	ok = fda.push_back_elems(state.array, ..items)
	if ok {
		expected_len += count
	}
}

make_sync_iter :: proc(
	it: ^$A/fda.FixedDynamicArray($T),
	auto_reset: bool = false,
) -> ba.OpaqueIterator(T) {
	return ba.make_iterator(
		ba.Iterator(FixedDynamicArraySynchronizedIteratorState(T), T) {
			is_dead = proc "contextless" (
				state: ^FixedDynamicArraySynchronizedIteratorState(T),
			) -> bool {
				return is_dead_state(state)
			},
			update = proc "contextless" (state: ^FixedDynamicArraySynchronizedIteratorState(T)) {
				sync_or_increment(state)
			},
			valid = proc "contextless" (
				state: ^FixedDynamicArraySynchronizedIteratorState(T),
			) -> bool {
				return state.index < state.array.len
			},
			get_item = proc "contextless" (
				state: ^FixedDynamicArraySynchronizedIteratorState(T),
			) -> ^T {
				return &state.array.data[state.index]
			},
			index = ba.index,
			died = proc "contextless" (state: ^FixedDynamicArraySynchronizedIteratorState(T)) {
				// mark dead
				state.expected_len = -1

				if state.auto_reset {
					internal_reset(state)
				}
			},
			can_reset = proc "contextless" (
				state: ^FixedDynamicArraySynchronizedIteratorState(T),
			) -> bool {
				return true
			},
			reset = proc "contextless" (state: ^FixedDynamicArraySynchronizedIteratorState(T)) {
				internal_reset(state)
			},
			state = {{-1}, it, fda.len(it^), auto_reset},
		},
	)
}

@(private = "file")
sync_or_increment :: proc "contextless" (it: ^$A/FixedDynamicArraySynchronizedIteratorState) {
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

@(optimization_mode = "none", private)
internal_reset :: proc "contextless" (state: ^$A/FixedDynamicArraySynchronizedIteratorState($T)) {
	state.index = -1
	state.array = state.array
	state.expected_len = state.array.len
}

@(private)
index_from_ptr :: proc "contextless" (it: ^$I/ba.OpaqueIterator($T), ptr: ^T) -> int {
	state := ba.state(it, FixedDynamicArraySynchronizedIteratorState(T))
	return mem.ptr_sub(ptr, &state.array.data[0])
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
