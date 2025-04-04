package iter_base

@(require) import op "../opaque"

MAX_ITERATOR_SIZE :: #config(MAX_ITERATOR_SIZE, 256)

BaseState :: struct {
	index: int,
}

Iterator :: struct($T: typeid) {
	get_index: proc "contextless" (state: ^Iterator(T)) -> int,
	is_dead:   proc "contextless" (state: ^Iterator(T)) -> bool,
	update:    proc "contextless" (state: ^Iterator(T)),
	is_valid:  proc "contextless" (state: ^Iterator(T)) -> bool,
	get_item:  proc "contextless" (state: ^Iterator(T)) -> ^T,
	can_reset: proc "contextless" (state: ^Iterator(T)) -> bool,
	reset:     proc "contextless" (state: ^Iterator(T)),
	inner:     op.OpaqueInline(MAX_ITERATOR_SIZE),
}

IteratorInterface :: struct($State: typeid, $T: typeid) {
	/// OPTIONAL
	/// Retrieves the current index of the iterator
	/// This gets returned to the user when calling next_val or next_ref
	/// so it can be used as an index in the for loop
	/// DEFAULT: returns the index from the base state
	get_index: proc "contextless" (state: ^BaseState) -> int,
	/// OPTIONAL
	/// Checks if the iterator is dead.
	/// An iterator is considered dead, when it has been determined that
	/// is no longer valid and cannot be used anymore. Not even after a reset.
	/// DEFAULT: returns false
	is_dead:   proc "contextless" (state: ^State) -> bool,
	/// REQUIRED
	/// Advances the the iterator by updating its internal state
	update:    proc "contextless" (state: ^State),
	/// REQUIRED
	/// Checks if the iterator is in a valid state to return an item.
	is_valid:  proc "contextless" (state: ^State) -> bool,
	/// REQUIRED
	/// Returns a pointer to the current item of the iterator.
	/// We need to return a pointer here,
	/// otherwise iterating with reference semantics wouldn't work
	get_item:  proc "contextless" (state: ^State) -> ^T,
	/// OPTIONAL
	/// Returns if the iterator can be reset, so it can be reused.
	/// DEFAULT: returns false
	can_reset: proc "contextless" (state: ^State) -> bool,
	/// OPTIONAL
	/// Changes the internal state of the iterator,
	/// so it can be used again
	/// DEFAULT: does nothing
	reset:     proc "contextless" (state: ^State),
}

TypedIterator :: struct($State: typeid, $T: typeid) {
	using interface: IteratorInterface(State, T),
	state:           State,
}

state :: proc "contextless" (it: ^Iterator($T), $S: typeid) -> ^S {
	it := op.get_ptr(&it.inner, TypedIterator(S, T))
	return &it.state
}

from_untyped :: proc(opaque: Iterator($T), $S: typeid) -> TypedIterator(S, T) {
	return op.get_value(it.inner, TypedIterator(S, T))
}

make_iterator :: proc(it: $I/TypedIterator($S, $T)) -> Iterator(T) {
	return erase_type(validate_iterator(it))
}

erase_type :: proc(it: $I/TypedIterator($S, $T)) -> Iterator(T) {
	opaque := Iterator(T) {
		get_index = proc "contextless" (it: ^Iterator(T)) -> int {
			it := op.get_ptr(&it.inner, I)
			return it.get_index(&it.state)
		},
		is_dead = proc "contextless" (it: ^Iterator(T)) -> bool {
			it := op.get_ptr(&it.inner, I)
			return it.is_dead(&it.state)
		},
		update = proc "contextless" (it: ^Iterator(T)) {
			it := op.get_ptr(&it.inner, I)
			it.update(&it.state)
		},
		is_valid = proc "contextless" (it: ^Iterator(T)) -> bool {
			it := op.get_ptr(&it.inner, I)
			return it.is_valid(&it.state)
		},
		get_item = proc "contextless" (it: ^Iterator(T)) -> ^T {
			it := op.get_ptr(&it.inner, I)
			return it.get_item(&it.state)
		},
		can_reset = proc "contextless" (it: ^Iterator(T)) -> bool {
			it := op.get_ptr(&it.inner, I)
			return it.can_reset(&it.state)
		},
		reset = proc "contextless" (it: ^Iterator(T)) {
			it := op.get_ptr(&it.inner, I)
			it.reset(&it.state)
		},
	}

	opaque.inner = op.make_opaque_sized(it, MAX_ITERATOR_SIZE)

	return opaque
}

@(private)
validate_iterator :: proc(it: $I/TypedIterator($S, $T)) -> I {
	it := it
	assert(it.update != nil, "update must be set")
	assert(it.is_valid != nil, "valid must be set")
	assert(it.get_item != nil, "get_item must be set")
	if it.get_index == nil {
		it.get_index = proc "contextless" (state: ^BaseState) -> int {
			return state.index
		}
	}
	if it.is_dead == nil {
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

next_ref :: proc "contextless" (it: ^$A/Iterator($T)) -> (result: ^T, index: int, ok: bool) {
	if it.is_dead(it) {
		return {}, -1, false
	}
	it.update(it)
	if it.is_valid(it) {
		return it.get_item(it), it.get_index(it), true
	}

	return {}, -1, false
}

next_val :: proc "contextless" (it: ^$A/Iterator($T)) -> (result: T, index: int, ok: bool) {
	tmp: ^T
	tmp, index = next_ref(it) or_return
	result = tmp^
	return
}

reset :: proc "contextless" (it: ^$A/Iterator($T)) -> bool {
	it.can_reset(it) or_return
	it.reset(it)
	return true
}
