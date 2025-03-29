#+feature dynamic-literals

package demo

RUN_FDA_DEMO :: #config(RUN_FDA_DEMO, true)
RUN_EE_DEMO :: #config(RUN_EE_DEMO, true)
RUN_ITER_DEMO :: #config(RUN_ITER_DEMO, true)
RUN_OPAQUE_DEMO :: #config(RUN_OPAQUE_DEMO, true)

USE_BASE_ITER :: #config(USE_BASE_ITER, false)

import "core:fmt"
import "core:log"
import "core:math"
import "core:mem"

showcase :: proc()

run_showcase :: proc(sc: showcase, name: string, track: ^mem.Tracking_Allocator) {
	log.info("=== %s Showcase ===", name)
	log.info()
	old := len(track.allocation_map)
	sc()
	log.info()
	log.info("=== Allocations: %v ===", len(track.allocation_map) - old)
	log.info()
	log.info()
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
		run_showcase(showcase_fixed_dynamic_array, "Fixed Dynamic Array", &track)
	}
	when RUN_EE_DEMO {
		run_showcase(showcase_expression_evaluator, "Expression Evaluator", &track)
	}
	when RUN_ITER_DEMO {
		run_showcase(showcase_base_iter, "Base Iterator", &track)
	}
	when RUN_OPAQUE_DEMO {
		run_showcase(showcase_opaque, "Opaque", &track)
	}

	free_all(log_alloc)
}
