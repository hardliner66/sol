package iter_base

@(require) import op "../opaque"

MAX_ITERATOR_SIZE :: #config(MAX_ITERATOR_SIZE, 256)

BaseState :: struct {
	index: int,
}

index :: proc "contextless" (state: ^BaseState) -> int {
	return state.index
}

OpaqueIterator :: struct($T: typeid) {
	index:     proc "contextless" (state: ^OpaqueIterator(T)) -> int,
	is_dead:   proc "contextless" (state: ^OpaqueIterator(T)) -> bool,
	update:    proc "contextless" (state: ^OpaqueIterator(T)),
	valid:     proc "contextless" (state: ^OpaqueIterator(T)) -> bool,
	get_item:  proc "contextless" (state: ^OpaqueIterator(T)) -> ^T,
	died:      proc "contextless" (state: ^OpaqueIterator(T)),
	can_reset: proc "contextless" (state: ^OpaqueIterator(T)) -> bool,
	reset:     proc "contextless" (state: ^OpaqueIterator(T)),
	iter:      op.Opaque(MAX_ITERATOR_SIZE),
}

IteratorInterface :: struct($State: typeid, $T: typeid) {
	index:     proc "contextless" (state: ^BaseState) -> int,
	is_dead:   proc "contextless" (state: ^State) -> bool,
	update:    proc "contextless" (state: ^State),
	valid:     proc "contextless" (state: ^State) -> bool,
	get_item:  proc "contextless" (state: ^State) -> ^T,
	died:      proc "contextless" (state: ^State),
	can_reset: proc "contextless" (state: ^State) -> bool,
	reset:     proc "contextless" (state: ^State),
}

Iterator :: struct($State: typeid, $T: typeid) {
	using interface: IteratorInterface(State, T),
	state:           State,
}

state :: proc "contextless" (it: ^OpaqueIterator($T), $S: typeid) -> ^S {
	it := op.get_ptr(&it.iter, Iterator(S, T))
	return &it.state
}

from_untyped :: proc(opaque: OpaqueIterator($T), $S: typeid) -> Iterator(S, T) {
	return op.get_value(it.iter, Iterator(S, T))
}

make_iterator :: proc(it: $I/Iterator($S, $T)) -> OpaqueIterator(T) {
	return erase_type(validate_iterator(it))
}

erase_type :: proc(it: $I/Iterator($S, $T)) -> OpaqueIterator(T) {
	opaque := OpaqueIterator(T) {
		index = proc "contextless" (it: ^OpaqueIterator(T)) -> int {
			it := op.get_ptr(&it.iter, I)
			return it.index(&it.state)
		},
		is_dead = proc "contextless" (it: ^OpaqueIterator(T)) -> bool {
			it := op.get_ptr(&it.iter, I)
			return it.is_dead(&it.state)
		},
		update = proc "contextless" (it: ^OpaqueIterator(T)) {
			it := op.get_ptr(&it.iter, I)
			it.update(&it.state)
		},
		valid = proc "contextless" (it: ^OpaqueIterator(T)) -> bool {
			it := op.get_ptr(&it.iter, I)
			return it.valid(&it.state)
		},
		get_item = proc "contextless" (it: ^OpaqueIterator(T)) -> ^T {
			it := op.get_ptr(&it.iter, I)
			return it.get_item(&it.state)
		},
		died = proc "contextless" (it: ^OpaqueIterator(T)) {
			it := op.get_ptr(&it.iter, I)
			it.died(&it.state)
		},
		can_reset = proc "contextless" (it: ^OpaqueIterator(T)) -> bool {
			it := op.get_ptr(&it.iter, I)
			return it.can_reset(&it.state)
		},
		reset = proc "contextless" (it: ^OpaqueIterator(T)) {
			it := op.get_ptr(&it.iter, I)
			it.reset(&it.state)
		},
	}

	opaque.iter = op.make_opaque_sized(it, MAX_ITERATOR_SIZE)

	return opaque
}

@(private)
validate_iterator :: proc(it: $I/Iterator($S, $T)) -> I {
	it := it
	assert(it.update != nil, "update must be set")
	assert(it.valid != nil, "valid must be set")
	assert(it.get_item != nil, "get_item must be set")
	if it.index == nil {
		it.index = index
	}
	if it.died != nil {
		assert(it.is_dead != nil, "if died is set, is_dead must be set")
	} else {
		it.died = proc "contextless" (state: ^S) {
			// do nothing
		}
		it.is_dead = proc "contextless" (state: ^S) -> bool {
			return false
		}
	}
	if it.reset != nil {
		assert(it.can_reset != nil, "if reset is set, can_reset must be set")
	} else {
		it.can_reset = proc "contextless" (state: ^S) -> bool {
			return false
		}
		it.reset = proc "contextless" (state: ^S) {
		}
	}
	return it
}

next_ref :: proc "contextless" (it: ^$A/OpaqueIterator($T)) -> (result: ^T, index: int, ok: bool) {
	if it.is_dead(it) {
		return {}, -1, false
	}
	it.update(it)
	if it.valid(it) {
		return it.get_item(it), it.index(it), true
	}
	it.died(it)

	return {}, -1, false
}

next_val :: proc "contextless" (it: ^$A/OpaqueIterator($T)) -> (result: T, index: int, ok: bool) {
	if it.is_dead(it) {
		return {}, -1, false
	}
	it.update(it)
	if it.valid(it) {
		return it.get_item(it)^, it.index(it), true
	}
	it.died(it)

	return {}, -1, false
}

reset :: proc "contextless" (it: ^$A/OpaqueIterator($T)) -> bool {
	it.can_reset(it) or_return
	it.reset(it)
	return true
}
