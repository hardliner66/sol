package demo

import ba "../iter"

when RUN_ITER_DEMO {
	Counting_State :: struct {
		using base:     ba.Base_State,
		count:          int,
		original_count: int,
		tmp:            int,
	}
	Counting_Iterator :: ba.State_Aware_Iterator(Counting_State, int)

	make_counting_iter :: proc(count: int) -> ba.State_Aware_Iterator(Counting_State, int) {
		TII :: ba.State_Aware_Iterator_Interface(Counting_State, int)
		TI :: ba.State_Aware_Iterator(Counting_State, int)
		update :: proc(it: ^TI) {
			it.state.index += 1
		}
		get_item :: proc(it: ^TI) -> ^int {
			it.state.tmp = it.state.index
			return &it.state.tmp
		}
		is_valid :: proc(it: ^TI) -> bool {
			return it.state.index < it.state.count
		}
		can_reset :: proc(it: ^TI) -> bool {
			return true
		}
		reset :: proc(it: ^TI) {
			it.state.index = -1
			it.state.count = it.state.original_count
		}

		return ba.make_iterator(
			Counting_Iterator {
				interface = ba.build_interface(
					TII {
						update = update,
						get_item = get_item,
						is_valid = is_valid,
						can_reset = can_reset,
						reset = reset,
					},
				),
				state = {{-1}, count, count, 0},
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
