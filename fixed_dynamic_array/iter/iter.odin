package fixed_dynamic_array_synchronized_iterator

import fda ".."
import ba "../../iter"

import "core:mem"

Fixed_Dynamic_Array_Synchronized_Iterator_State :: struct($T: typeid) {
	using base:   ba.Base_State,
	array:        ^fda.Fixed_Dynamic_Array(T),
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

unordered_remove_index :: proc(
	it: ^$I/ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State($T), T),
	index: int,
	loc := #caller_location,
) #no_bounds_check {
	fda.unordered_remove(it.state.array, index, loc)
	if index < it.state.index {
		// swap the currently processed item with the item at the index
		// this is safe, because unordered_remove swaps the item at the last valid index
		// with the deleted item
		it.state.array.data[it.state.index] = it.state.array.data[index]
	}
	// don't update expected_len, so the iterator knows that the array has been modified
}

ordered_remove_index :: proc(
	it: ^$I/ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State($T), T),
	index: int,
	loc := #caller_location,
) #no_bounds_check {
	fda.ordered_remove(it.state.array, index, loc)
	if index > it.state.index {
		// if the index is greater than the current index, we need to decrement the expected length
		// so the iterator will properly increment its index when called the next time
		it.state.expected_len -= 1
	}
	// because ordered_remove keeps the order by copying every item after the deleted one
	// to the the position of the deleted item, thus keeping the order of the array
	// this means, we're at the correct position for the next iteration,
	// because the index is only incremented when the expected length is the same as the current length
}

unordered_remove_ptr :: proc(
	it: ^$I/ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State($T), T),
	ptr: ^T,
	loc := #caller_location,
) #no_bounds_check {
	unordered_remove_index(it, index_from_ptr(it, ptr), loc)
}

ordered_remove_ptr :: proc(
	it: ^$I/ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State($T), T),
	ptr: ^T,
	loc := #caller_location,
) #no_bounds_check {
	ordered_remove_index(it, index_from_ptr(it, ptr), loc)
}

unordered_remove_current :: proc(
	it: ^$I/ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State($T), T),
) #no_bounds_check {
	fda.unordered_remove(it.state.array, it.state.index)
}

ordered_remove_current :: proc "contextless" (
	it: ^$I/ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State($T), T),
) #no_bounds_check {
	fda.ordered_remove(it.state.array, it.state.index)
}

push_back :: proc(
	it: ^$I/ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State($T), T),
	item: T,
) -> (
	ok: bool,
) {
	ok = fda.push_back(it.state.array, item)
	if ok {
		it.state.expected_len += 1
	}
	return
}

pop_back_safe :: proc(
	it: ^$I/ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State($T), T),
) -> (
	item: T,
	ok: bool,
) {
	item = fda.pop_back_safe(it.state.array) or_return
	it.state.expected_len -= 1
	return
}

clear :: proc "contextless" (
	it: ^$I/ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State($T), T),
) {
	fda.clear(it.state.array)
	state.expected_len = 0
}

push_back_elems :: proc "contextless" (
	it: ^$I/ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State($T), T),
	items: ..T,
) -> (
	ok: bool,
) {
	count := len(items)
	ok = fda.push_back_elems(it.state.array, ..items)
	if ok {
		expected_len += count
	}
}

make_sync_iter :: proc(
	it: ^$A/fda.Fixed_Dynamic_Array($T),
	auto_reset: bool = false,
) -> ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State(T), T) {
	TII :: ba.State_Aware_Iterator_Interface(Fixed_Dynamic_Array_Synchronized_Iterator_State(T), T)
	TI :: ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State(T), T)

	return ba.make_iterator(TI{interface = ba.build_interface(TII {
			update = proc(it: ^TI) {
				sync_or_increment(&it.state)
			},
			is_valid = proc(it: ^TI) -> bool {
				if (it.state.index < it.state.array.len) {
					return true
				}

				if it.state.auto_reset {
					internal_reset(&it.state)
				}
				return false
			},
			get_item = proc(it: ^TI) -> ^T {
				return &it.state.array.data[it.state.index]
			},
			can_reset = proc(it: ^TI) -> bool {
				return true
			},
			reset = proc(it: ^TI) {
				internal_reset(&it.state)
			},
		}), state = {{-1}, it, fda.len(it^), auto_reset}})
}

@(private = "file")
sync_or_increment :: proc "contextless" (it: ^$A/Fixed_Dynamic_Array_Synchronized_Iterator_State) {
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
internal_reset :: proc "contextless" (
	state: ^$A/Fixed_Dynamic_Array_Synchronized_Iterator_State($T),
) {
	state.index = -1
	state.array = state.array
	state.expected_len = state.array.len
}

@(private)
index_from_ptr :: proc(
	it: ^$I/ba.State_Aware_Iterator(Fixed_Dynamic_Array_Synchronized_Iterator_State($T), T),
	ptr: ^T,
) -> int {
	return mem.ptr_sub(ptr, &it.state.array.data[0])
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
