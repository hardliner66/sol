package iter_abuse

import "base:intrinsics"
import "base:runtime"
import "core:log"
import "core:mem"

MySlice :: struct {
	// start with a raw slice
	// this allows the for loop to use it as a slice
	// and the deferred function to use it as MySlice
	using inner: runtime.Raw_Slice,
	// current is the current value,
	// as the slice needs a pointer to the first element to work
	current:     int,
	max:         int,
}

// gets called when the loop scope ends
update :: proc(state: rawptr) {
	my_slice := transmute(^MySlice)state
	// if we're not done
	if my_slice.len < my_slice.max {
		// update the internal state
		my_slice.current += 1
		// the for loop fetches the next value from the slice
		// by taking the base address and incrementing it by the size of the type
		// times the current index
		//
		// to mitigate this, we change the base address to point to a location in memory
		// that is in front of the actual value, so the for loop will pick up the correct value
		my_slice.data = rawptr(uintptr(&my_slice.current) - uintptr(size_of(int) * my_slice.len))
		// increment the length of the iterator,
		// so the for loop knows to loop one more time
		my_slice.len += 1
	} else {
		free(my_slice)
	}
}

// allocate a new struct which starts with the same layout as a slice
@(deferred_out = update)
create :: proc(max: int) -> rawptr {
	state := new(MySlice)
	state.current = 0
	state.max = max
	state.data = &state.current
	state.len = 1
	return transmute(^[]int)state
}

// this is needed because deferred_* doesn't work with generic types
to_iter :: proc($T: typeid, ptr: rawptr) -> ^[]T {
	return transmute(^[]T)ptr
}

main :: proc() {
	context.logger = log.create_console_logger()

	for &v in to_iter(int, create(10)) {
		if v == 5 {
			v += 10
		}
		log.info(v)
	}
}
