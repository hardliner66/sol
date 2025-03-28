package fixed_dynamic_array

import "base:builtin"
import "base:runtime"
_ :: runtime

FixedDynamicArraySynchronizedIterator :: struct($T: typeid) {
	array:        ^FixedDynamicArray(T),
	index:        int,
	expected_len: int,
}

@(private = "file")
sync_or_increment :: proc "contextless" (it: ^$A/FixedDynamicArraySynchronizedIterator($T)) {
	// Check if the array has been modified since the last iteration.
	if it.expected_len == it.array.len {
		// The array has not been modified.
		// increment the index and return the next element.
		it.index += 1
	} else {
		// The array has been modified.
		// update the expected length and don't update the index.
		it.expected_len = it.array.len
	}
}

next :: proc "contextless" (it: ^$A/FixedDynamicArraySynchronizedIterator($T)) -> (^T, bool) {
	sync_or_increment(it)

	if it.index < it.array.len {
		return &it.array.data[it.index], true
	}
	return nil, false
}

sync_iter :: proc "contextless" (
	a: ^$A/FixedDynamicArray($T),
) -> FixedDynamicArraySynchronizedIterator(T) {
	return FixedDynamicArraySynchronizedIterator(T){a, -1, len(a^)}
}

FixedDynamicArray :: struct($T: typeid) {
	data: []T,
	len:  int,
}

create :: proc($T: typeid, capacity: int) -> FixedDynamicArray(T) {
	return FixedDynamicArray(T){make([]T, capacity), 0}
}

destroy :: proc(arr: ^FixedDynamicArray($T)) {
	delete(arr.data)
}

len :: proc "contextless" (a: $A/FixedDynamicArray) -> int {
	return a.len
}

cap :: proc "contextless" (a: $A/FixedDynamicArray) -> int {
	return builtin.len(a.data)
}

space :: proc "contextless" (a: $A/FixedDynamicArray) -> int {
	return builtin.len(a.data) - a.len
}

slice :: proc "contextless" (a: ^$A/FixedDynamicArray($T)) -> []T {
	return a.data[:a.len]
}

get :: proc "contextless" (a: $A/FixedDynamicArray($T), index: int) -> T {
	return a.data[index]
}
get_ptr :: proc "contextless" (a: ^$A/FixedDynamicArray($T), index: int) -> ^T {
	return &a.data[index]
}

get_safe :: proc(a: $A/FixedDynamicArray($T), index: int) -> (T, bool) #no_bounds_check {
	if index < 0 || index >= a.len {
		return {}, false
	}
	return a.data[index], true
}

get_ptr_safe :: proc(a: ^$A/FixedDynamicArray($T), index: int) -> (^T, bool) #no_bounds_check {
	if index < 0 || index >= a.len {
		return {}, false
	}
	return &a.data[index], true
}

set :: proc "contextless" (a: ^$A/FixedDynamicArray($T), index: int, item: T) {
	a.data[index] = item
}

push_back :: proc "contextless" (a: ^$A/FixedDynamicArray($T), item: T) -> bool {
	if a.len < cap(a^) {
		a.data[a.len] = item
		a.len += 1
		return true
	}
	return false
}

push_front :: proc "contextless" (a: ^$A/FixedDynamicArray($T), item: T) -> bool {
	if a.len < cap(a^) {
		a.len += 1
		data := slice(a)
		copy(data[1:], data[:])
		data[0] = item
		return true
	}
	return false
}

pop_back :: proc "odin" (a: ^$A/FixedDynamicArray($T), loc := #caller_location) -> T {
	assert(condition = (a.len > 0), loc = loc)
	item := a.data[a.len - 1]
	a.len -= 1
	return item
}

pop_front :: proc "odin" (a: ^$A/FixedDynamicArray($T), loc := #caller_location) -> T {
	assert(condition = (a.len > 0), loc = loc)
	item := a.data[0]
	s := slice(a)
	copy(s[:], s[1:])
	a.len -= 1
	return item
}

pop_back_safe :: proc "contextless" (a: ^$A/FixedDynamicArray($T)) -> (item: T, ok: bool) {
	if a.len > 0 {
		item = a.data[a.len - 1]
		a.len -= 1
		ok = true
	}
	return
}

pop_front_safe :: proc "contextless" (a: ^$A/FixedDynamicArray($T)) -> (item: T, ok: bool) {
	if a.len > 0 {
		item = a.data[0]
		s := slice(a)
		copy(s[:], s[1:])
		a.len -= 1
		ok = true
	}
	return
}

consume :: proc "odin" (a: ^$A/FixedDynamicArray($T), count: int, loc := #caller_location) {
	assert(condition = a.len >= count, loc = loc)
	a.len -= count
}

ordered_remove :: proc "contextless" (
	a: ^$A/FixedDynamicArray($T),
	index: int,
	loc := #caller_location,
) #no_bounds_check {
	runtime.bounds_check_error_loc(loc, index, a.len)
	if index + 1 < a.len {
		copy(a.data[index:], a.data[index + 1:])
	}
	a.len -= 1
}

unordered_remove_index :: proc "contextless" (
	a: ^$A/FixedDynamicArray($T),
	index: int,
	loc := #caller_location,
) #no_bounds_check {
	runtime.bounds_check_error_loc(loc, index, a.len)
	n := a.len - 1
	if index != n {
		a.data[index] = a.data[n]
	}
	a.len -= 1
	a.len = max(a.len, 0)
}

unordered_remove_ptr :: proc "contextless" (
	a: ^$A/FixedDynamicArray($T),
	ptr: ^T,
	loc := #caller_location,
) #no_bounds_check {
	n := a.len - 1
	if ptr != &a.data[n] {
		ptr^ = a.data[n]
	}
	a.len -= 1
	a.len = max(a.len, 0)
}

clear :: proc "contextless" (a: ^$A/FixedDynamicArray($T)) {
	a.len = 0
}

push_back_elems :: proc "contextless" (a: ^$A/FixedDynamicArray($T), items: ..T) -> bool {
	if a.len + builtin.len(items) <= cap(a^) {
		n := copy(a.data[a.len:], items[:])
		a.len += n
		return true
	}
	return false
}

inject_at :: proc "contextless" (
	a: ^$A/FixedDynamicArray($T),
	item: T,
	index: int,
) -> bool #no_bounds_check {
	if a.len < cap(a^) && index >= 0 && index <= len(a^) {
		a.len += 1
		for i := a.len - 1; i >= index + 1; i -= 1 {
			a.data[i] = a.data[i - 1]
		}
		a.data[index] = item
		return true
	}
	return false
}

resize :: proc(a: ^$A/FixedDynamicArray($T), new_len: int) {
	new_array := make([]T, new_len)
	if new_len < a.len {
		// shrink
		a.len = new_len
		// copy subset of data
		copy(new_array, a.data[:new_len])
	} else {
		// copy all data
		copy(new_array, a.data[:a.len])
		// len stays the same
	}
	delete(a.data)
	a.data = new_array
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
unordered_remove :: proc {
	unordered_remove_index,
	unordered_remove_ptr,
}
