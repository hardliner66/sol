package base_iter

Iterator :: struct($T: typeid, $State: typeid) {
	state:     State,
	increment: proc "contextless" (state: ^State),
	get_item:  proc "contextless" (state: ^State) -> T,
	valid:     proc "contextless" (state: ^State) -> bool,
}


CountingState :: struct {
	index: int,
	count: int,
}
CountingIterator :: Iterator(int, CountingState)

next :: proc "contextless" (it: ^$A/Iterator($T, $S)) -> (result: T, ok: bool) {
	it.increment(&it.state)
	it.valid(&it.state) or_return
	return it.get_item(&it.state), true
}

make_counting_iter :: proc "contextless" (count: int) -> CountingIterator {
	return {state = {-1, count}, increment = proc "contextless" (state: ^CountingState) {
			state.index += 1
		}, get_item = proc "contextless" (state: ^CountingState) -> int {
			return state.index
		}, valid = proc "contextless" (state: ^CountingState) -> bool {
			return state.index < state.count
		}}
}
