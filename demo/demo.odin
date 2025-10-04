#+feature dynamic-literals

package demo

RUN_FDA_DEMO :: #config(RUN_FDA_DEMO, false)
RUN_EE_DEMO :: #config(RUN_EE_DEMO, false)
RUN_ITER_DEMO :: #config(RUN_ITER_DEMO, false)
RUN_OPAQUE_DEMO :: #config(RUN_OPAQUE_DEMO, false)
RUN_STA_DEMO :: #config(RUN_STA_DEMO, false)
RUN_RUSTIC_DEMO :: #config(RUN_RUSTIC_DEMO, true)

import "core:fmt"
import "core:mem"

import sta "../stack_tracking_allocator"

showcase :: proc()

run_showcase :: proc(sc: showcase, name: string, track: ^sta.Stack_Tracking_Allocator) {
	fmt.printfln("=== %s Showcase ===", name)
	fmt.println()
	old := len(track.allocation_map)
	sc()
	fmt.println()
	fmt.printfln("=== Allocations: %v ===", len(track.allocation_map) - old)
	fmt.println()
	fmt.println()
}

global_trace_ctx: sta.Context

main :: proc() {
	sta.init(&global_trace_ctx)
	defer sta.destroy(&global_trace_ctx)

	track: sta.Stack_Tracking_Allocator
	sta.stack_tracking_allocator_init(&track, context.allocator, &global_trace_ctx)
	context.allocator = sta.stack_tracking_allocator(&track)

	defer {
		if len(track.allocation_map) > 0 {
			fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
			for _, entry in track.allocation_map {
				fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				sta.print_stack_trace(&track, entry.stack_trace)
			}
		}
		if len(track.bad_free_array) > 0 {
			fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
			for entry in track.bad_free_array {
				fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
			}
		}
		sta.stack_tracking_allocator_destroy(&track)
	}

	// Use a dynamic arena for the logger to be able to free
	// all logging allocations at once, thus avoiding leaks
	pool: mem.Dynamic_Arena
	mem.dynamic_arena_init(&pool)
	defer mem.dynamic_arena_destroy(&pool)
	log_alloc = mem.dynamic_arena_allocator(&pool)

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
	when RUN_STA_DEMO {
		run_showcase(showcase_stack_tracking_allocator, "Stack Tracking Allocator", &track)
	}
	when RUN_RUSTIC_DEMO {
		run_showcase(showcase_rustic, "Rustic", &track)
	}

	free_all(log_alloc)
}
