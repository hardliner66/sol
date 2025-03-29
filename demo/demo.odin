#+feature dynamic-literals

package demo

RUN_FDA_DEMO :: #config(RUN_FDA_DEMO, true)
RUN_EE_DEMO :: #config(RUN_EE_DEMO, true)

import ee "../expression_evaluator"
import fa "../fixed_dynamic_array"
import fa_iter "../fixed_dynamic_array/iter"

import ba "../base_iter"

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"

log_alloc: mem.Allocator

// helper to be able to log while panic allocator is active
info :: proc(fmt_str: string, args: ..any, location := #caller_location) {
	old_alloc := context.allocator
	defer context.allocator = old_alloc

	old_temp_alloc := context.temp_allocator
	defer context.temp_allocator = old_temp_alloc

	context.allocator = log_alloc
	context.temp_allocator = log_alloc

	log.infof(fmt_str, ..args, location = location)
}

when RUN_EE_DEMO {
	showcase_expression_evaluator :: proc() {
		precedence := ee.make_default_precedence_map()
		defer delete(precedence)

		precedence['^'] = 3

		eb, e := ee.parse("2 ^ (2 + foo) * 4", precedence)
		assert(e == nil)
		defer ee.destroy_expr(eb)

		operators := ee.make_default_op_proc_map()
		defer delete(operators)

		operators['^'] = proc(a: f32, b: f32) -> ee.EvalResult {return math.pow(a, b)}

		variables := map[string]ee.Number {
			"foo" = int(3),
		}
		defer delete(variables)

		f: f32 = 0.0
		f, e = ee.eval_expr(eb, variables, operators)

		assert(e == nil)

		log.info("Result:", f)
	}
}

when RUN_FDA_DEMO {
	ITEM_COUNT :: #config(ITEM_COUNT, 100)
	showcase_fixed_dynamic_array :: proc() {
		array := fa.create(int, ITEM_COUNT)
		defer fa.destroy(&array)

		old_context := context
		defer context = old_context

		context.allocator = mem.panic_allocator()
		context.temp_allocator = mem.panic_allocator()

		// append first element
		fa.append(&array, 0)

		// get the pointer the first element
		ptr := fa.get_ptr(&array, 0)

		for i in 1 ..< ITEM_COUNT {
			// look ma, no allocations!
			fa.append(&array, i)

			if i % 20 == 0 {
				info("Current Array Length: %v", fa.len(array))
			}
		}
		info("Full Array Length: %v", fa.len(array))

		// get the pointer the first element again
		ptr2 := fa.get_ptr(&array, 0)

		// no allocation or moving of memory happened
		// so the pointer should be the same
		assert(ptr == ptr2, "Pointers should be the same!")

		i := 0
		it := fa_iter.make_sync_iter(&array)
		for item in fa_iter.next(&it) {
			info("Item: %v", item)

			// remove every third item
			if i % 3 == 0 {
				// you can remove the current item through the allocator
				// this is the same as manually removing it from the array
				// this is completely safe, because the iterator synchronizes
				// the expected length of the array with the actual length before iterating
				// which makes it safe to remove the current and any later item while iterating
				fa_iter.ordered_remove_current(&it)
			}

			// technically every function, except resize, is safe to call while iterating
			// as the memory is technically still valid. This can easily lead to bugs though,
			// so be careful when doing this.
			// Also, most manipulation functions are defined in the /iter subpackage, which
			// will also make sure that you wont iterate over an element twice or miss an element
			i += 1
		}
		info("Final Array Length: %v", fa.len(array))

		fa.clear(&array)
		for i in 0 ..< ITEM_COUNT {
			fa.append(&array, i)
		}

		i = 0
		for item in fa_iter.next(&it) {
			if i % 3 == 0 {
				fa_iter.unordered_remove_current(&it)
			} else if i % 5 == 0 {
				fa_iter.append(&it, i)
			}
			i += 1
		}
		info("Final Array Length: %v", fa.len(array))
	}
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		mem.tracking_allocator_destroy(&track)
	}

	// Use a dynamic arena for the logger to be able to free
	// all logging allocations at once, thus avoiding leaks
	pool: mem.Dynamic_Arena
	mem.dynamic_arena_init(&pool)
	defer mem.dynamic_arena_destroy(&pool)
	log_alloc = mem.dynamic_arena_allocator(&pool)
	context.logger = log.create_console_logger(allocator = log_alloc)

	when RUN_FDA_DEMO {
		// showcase_fixed_dynamic_array()
	}
	when RUN_EE_DEMO {
		// showcase_expression_evaluator()
	}

	a := make([dynamic]int)
	defer delete(a)
	it := ba.make_counting_iter(100)
	for i in ba.next(&it) {
		info("Counting: %v", i)
		append(&a, i)
	}
	info("Final Array Length: %v", len(a))

	free_all(log_alloc)
}
