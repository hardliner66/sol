#+feature dynamic-literals

package demo

RUN_FDA_DEMO :: #config(RUN_FDA_DEMO, true)
RUN_EE_DEMO :: #config(RUN_EE_DEMO, true)

import ee "../expression_evaluator"
import fa "../fixed_dynamic_array"

import "core:fmt"
import "core:log"

import "core:math"
import "core:mem"

when RUN_EE_DEMO {
	showcase_expression_evaluator :: proc() {
		precedence := ee.make_default_precedence_map()
		precedence['^'] = 3

		eb, e := ee.parse("2 ^ (2 + foo) * 4", precedence)
		assert(e == nil)
		defer ee.destroy_expr(eb)

		operators := ee.make_default_op_proc_map()
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
	info :: proc(
		args: ..any,
		sep := " ",
		location := #caller_location,
		alloc := context.allocator,
		temp_alloc := context.temp_allocator,
	) {
		old_alloc := context.allocator
		defer context.allocator = old_alloc

		old_temp_alloc := context.temp_allocator
		defer context.temp_allocator = old_temp_alloc

		context.allocator = alloc
		context.temp_allocator = temp_alloc

		log.info(args, sep = sep, location = location)
	}

	showcase_fixed_dynamic_array :: proc() {
		array := fa.create(f32, 10000)
		defer fa.destroy(&array)

		old_alloc := context.allocator
		defer context.allocator = old_alloc

		old_temp_alloc := context.temp_allocator
		defer context.temp_allocator = old_temp_alloc

		context.allocator = mem.panic_allocator()
		context.temp_allocator = mem.panic_allocator()

		for i in 0 ..= 9998 {
			// look ma, no allocations!
			fa.append(&array, f32(i))

			if i % 500 == 0 {
				info(
					"Array length:",
					fa.len(array),
					alloc = old_alloc,
					temp_alloc = old_temp_alloc,
				)
			}
		}
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
	log_alloc := mem.dynamic_arena_allocator(&pool)
	context.logger = log.create_console_logger(allocator = log_alloc)

	when RUN_FDA_DEMO {
		showcase_fixed_dynamic_array()
	}
	when RUN_EE_DEMO {
		showcase_expression_evaluator()
	}

	free_all(log_alloc)

}
