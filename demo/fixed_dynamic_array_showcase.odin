package demo

import fda "../fixed_dynamic_array"
import fda_iter "../fixed_dynamic_array/iter"

import ba "../iter"

import "core:mem"

when RUN_FDA_DEMO {
	ITEM_COUNT :: #config(ITEM_COUNT, 100)
	showcase_fixed_dynamic_array :: proc() {
		array := fda.create(int, ITEM_COUNT)
		defer fda.destroy(&array)

		old_context := context
		defer context = old_context

		context.allocator = mem.panic_allocator()
		context.temp_allocator = mem.panic_allocator()

		// append first element
		fda.append(&array, 0)

		// get the pointer the first element
		ptr := fda.get_ptr(&array, 0)

		for i in 1 ..< ITEM_COUNT {
			if i % 20 == 0 {
				info("Current Array Length: %v", fda.len(array))
			}

			// look ma, no allocations!
			fda.append(&array, i)

		}
		info("Full Array Length: %v", fda.len(array))

		// get the pointer the first element again
		ptr2 := fda.get_ptr(&array, 0)

		// no allocation or moving of memory happened
		// so the pointer should be the same
		assert(ptr == ptr2, "Pointers should be the same!")

		i := 0
		it := fda_iter.make_sync_iter(&array)
		for item, index in fda_iter.next(&it) {
			info("Index: %v, Value: %v", index, item)

			// remove every third item
			if i % 3 == 0 {
				// you can remove the current item through the allocator
				// this is the same as manually removing it from the array
				// this is completely safe, because the iterator synchronizes
				// the expected length of the array with the actual length before iterating
				// which makes it safe to remove the current and any later item while iterating
				fda_iter.unordered_remove_current(&it)
			}

			// technically every function, except resize, is safe to call while iterating
			// as the memory is technically still valid. This can easily lead to bugs though,
			// so be careful when doing this.
			// Also, most manipulation functions are defined in the /iter subpackage, which
			// will also make sure that you wont iterate over an element twice or miss an element
			i += 1
		}
		info("Array Length: %v", fda.len(array))

		fda.clear(&array)
		for i in 0 ..< ITEM_COUNT {
			fda.append(&array, i)
		}

		i = 0
		for item in fda_iter.next(&it) {
			fda_iter.unordered_remove_current(&it)
			fda_iter.push_back(&it, i)
			fda_iter.pop_back_safe(&it)
			fda_iter.ordered_remove(&it, i)
			fda_iter.unordered_remove(&it, i)
			state := ba.state(&it, fda_iter.FixedDynamicArraySynchronizedIteratorState(int))
			fda_iter.ordered_remove(&it, fda.get_ptr(state.array, 0))
			fda_iter.unordered_remove(&it, fda.get_ptr(state.array, 0))
			break
		}

		info("Array Length: %v", fda.len(array))
	}
}
