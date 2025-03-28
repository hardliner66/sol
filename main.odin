#+feature dynamic-literals

package main

import ee "./expression_evaluator"
import fda "./fixed_dynamic_array"

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"

showcase_expression_evaluator :: proc() {
	operators := ee.DefaultOpProcMap
	precedence := ee.DefaultPrecedenceMap

	operators['^'] = proc(a: f32, b: f32) -> f32 {return math.pow(a, b)}
	precedence['^'] = 3

	variables := map[string]ee.Number {
		"foo" = int(3),
	}
	defer delete(variables)

	eb, e := ee.parse("2 ^ (2 + foo) * 4", precedence)
	assert(e == nil)
	defer ee.destroy_expr(eb)

	f: f32 = 0.0
	f, e = ee.eval_expr(eb, variables, operators)

	assert(e == nil)

	log.info("Result:", f)
}

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

show_case_fixed_dynamic_array :: proc() {
	array := fda.create(f32, 10000)
	defer fda.destroy(&array)

	old_alloc := context.allocator
	defer context.allocator = old_alloc

	old_temp_alloc := context.temp_allocator
	defer context.temp_allocator = old_temp_alloc

	context.allocator = mem.panic_allocator()
	context.temp_allocator = mem.panic_allocator()

	for i in 0 ..= 9998 {
		// look ma, no allocations!
		fda.append(&array, f32(i))

		if i % 500 == 0 {
			info("Array length:", fda.len(array), alloc = old_alloc, temp_alloc = old_temp_alloc)
		}
	}
}

main :: proc() {
	when ODIN_DEBUG {
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
	}

	pool: mem.Dynamic_Arena
	mem.dynamic_arena_init(&pool)
	defer mem.dynamic_arena_destroy(&pool)
	log_alloc := mem.dynamic_arena_allocator(&pool)
	context.logger = log.create_console_logger(allocator = log_alloc)

	if false {
		show_case_fixed_dynamic_array()
	}
	showcase_expression_evaluator()

	free_all(log_alloc)

}
