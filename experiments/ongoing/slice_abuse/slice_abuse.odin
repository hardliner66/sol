package iter_abuse

import "base:runtime"
import "core:fmt"
import "core:mem"

Update_Proc :: #type proc(slice: ^Base_Slice)

// Common base struct for the slice based iterator
Base_Slice :: struct {
	// start with a raw slice
	// this allows the for loop to use it as a slice
	using inner: runtime.Raw_Slice,
	// we store an update function containing the actual update logic
	update:      Update_Proc,
}

// call the stored update function
update :: proc(slice: ^Base_Slice) {
	slice.update(slice)
}

// helper function to cast the update function to the correct type
make_update :: proc(upd: proc(slice: ^$S)) -> Update_Proc {
	return (Update_Proc)(upd)
}

// update the length, so the loop will do another iteration
next :: proc(slice: ^Base_Slice) {
	slice.len += 1
}

// update the length and correct the data pointer if the iterator doesn't have a backing data structure
next_corrected :: proc(slice: ^Base_Slice, $T: typeid) {
	next(slice)
	slice.data = mem.ptr_offset((^T)(slice.data), -1)
}

// we use deferred_out here to continuously call the update function
// while iterating over the slice
@(deferred_out = update)
from :: proc(slice: ^Base_Slice) -> ^Base_Slice {
	// calculate where the custom data starts
	// (address + size of data pointer + size of length + size of update proc)
	//
	// if the iterator doesn't have a backing data structure,
	// this needs to point to the memory location that remains valid during iteration
	// therefor we store a temporary value inside the actual iterator struct
	// and use that as the backing data structure
	//
	// if the iterator DOES have a backing data structure,
	// we can point this to the beginning of the data directly
	slice.data = rawptr(
		uintptr(slice) + uintptr(size_of(rawptr) + size_of(int) + size_of(Update_Proc)),
	)
	return slice
}

// this is a workaround to get the correct type of slice
every :: proc($T: typeid) -> proc(slice: ^Base_Slice) -> ^[]T {
	return proc(slice: ^Base_Slice) -> ^[]T {
			return (^[]T)(slice)
		}
}

My_Slice :: struct {
	using base: Base_Slice,
	// we need to make sure to put the field that stores the current value
	// directly after the base struct
	// otherwise the data pointer will point to the wrong location
	current:    int,
	max:        int,
}

counting_iter :: proc(count: int) -> My_Slice {
	update :: proc(slice: ^My_Slice) {
		if slice.len < slice.max {
			slice.current += 1
			// we use corrected here to make sure the data pointer points to the correct location
			// this is only necessary if the iterator doesn't have a backing data structure
			// the correct location should be:
			// the address of the current value - (the current index * the size of the type)
			next_corrected(slice, int)
			return
		}

		// if we reach the end of the iterator, we set the length to -1
		// this is not necessary, but it makes the code a bit cleaner
		slice.len = -1
	}

	slice: My_Slice
	slice.current = 0
	slice.max = 10
	// we need to set the length to 1 here,
	// so the for loop will do at least one iteration
	slice.len = 1
	slice.update = make_update(update)
	return slice
}

main :: proc() {
	// create the slice based iterator
	state := counting_iter(10)

	// use the slice based iterator
	for &v in every(int)(from(&state)) {
		if v == 5 {
			v += 10
		}
		fmt.println(v)
	}
}
