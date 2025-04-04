package demo

import ba "../iter"

when RUN_ITER_DEMO {
	CountingState :: struct {
		using base:     ba.BaseState,
		count:          int,
		original_count: int,
		tmp:            int,
	}
	CountingIterator :: ba.TypedIterator(CountingState, int)

	make_counting_iter :: proc(count: int) -> ba.Iterator(int) {
		update :: proc "contextless" (state: ^CountingState) {
			state.index += 1
		}
		get_item :: proc "contextless" (state: ^CountingState) -> ^int {
			state.tmp = state.index
			return &state.tmp
		}
		is_valid :: proc "contextless" (state: ^CountingState) -> bool {
			return state.index < state.count
		}
		can_reset :: proc "contextless" (state: ^CountingState) -> bool {
			return true
		}
		reset :: proc "contextless" (state: ^CountingState) {
			state.index = -1
			state.count = state.original_count
		}

		return ba.make_iterator(
			CountingIterator {
				update = update,
				get_item = get_item,
				is_valid = is_valid,
				can_reset = can_reset,
				reset = reset,
				state = CountingState{{-1}, count, count, 0},
			},
		)
	}

	showcase_base_iter :: proc() {
		// create a counting iterator
		it := make_counting_iter(5)

		// iterate over the first 5 numbers
		for i in ba.next_val(&it) {
			info("Counting: %v", i)
		}

		// reset the iterator to start from 0 again
		ba.reset(&it)

		// iterate over the first 5 numbers again
		for i in ba.next_val(&it) {
			info("Counting: %v", i)
		}
	}
}
