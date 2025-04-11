package iter_base

Base_State :: struct {
	index: int,
}

Iterator_Interface :: struct($T: typeid) {
	get_index: proc(it: ^Iterator_Interface(T)) -> int,
	is_dead:   proc(it: ^Iterator_Interface(T)) -> bool,
	update:    proc(it: ^Iterator_Interface(T)),
	is_valid:  proc(it: ^Iterator_Interface(T)) -> bool,
	get_item:  proc(it: ^Iterator_Interface(T)) -> ^T,
	can_reset: proc(it: ^Iterator_Interface(T)) -> bool,
	reset:     proc(it: ^Iterator_Interface(T)),
}

Typed_Iterator_Interface :: struct($State: typeid, $T: typeid) {
	/// OPTIONAL
	/// Retrieves the current index of the iterator
	/// This gets returned to the user when calling next_val or next_ref
	/// so it can be used as an index in the for loop
	/// DEFAULT: returns the index from the base state
	get_index: proc(it: ^Typed_Iterator(State, T)) -> int,
	/// OPTIONAL
	/// Checks if the iterator is dead.
	/// An iterator is considered dead, when it has been determined that
	/// is no longer valid and cannot be used anymore. Not even after a reset.
	/// DEFAULT: returns false
	is_dead:   proc(it: ^Typed_Iterator(State, T)) -> bool,
	/// REQUIRED
	/// Advances the the iterator by updating its internal state
	update:    proc(it: ^Typed_Iterator(State, T)),
	/// REQUIRED
	/// Checks if the iterator is in a valid state to return an item.
	is_valid:  proc(it: ^Typed_Iterator(State, T)) -> bool,
	/// REQUIRED
	/// Returns a pointer to the current item of the iterator.
	/// We need to return a pointer here,
	/// otherwise iterating with reference semantics wouldn't work
	get_item:  proc(it: ^Typed_Iterator(State, T)) -> ^T,
	/// OPTIONAL
	/// Returns if the iterator can be reset, so it can be reused.
	/// DEFAULT: returns false
	can_reset: proc(it: ^Typed_Iterator(State, T)) -> bool,
	/// OPTIONAL
	/// Changes the internal state of the iterator,
	/// so it can be used again
	/// DEFAULT: does nothing
	reset:     proc(it: ^Typed_Iterator(State, T)),
}

Typed_Iterator :: struct($State: typeid, $T: typeid) {
	using iface: Iterator_Interface(T),
	state:       State,
}

make_iterator :: proc(it: $I/Typed_Iterator($S, $T)) -> I {
	return validate_iterator(it)
}

build_interface :: proc(it: $I/Typed_Iterator_Interface($S, $T)) -> Iterator_Interface(T) {
	return transmute(Iterator_Interface(T))(it)
}

from_typed :: proc(it: ^$I/Typed_Iterator($S, $T)) -> ^Iterator_Interface(T) {
	return (^Iterator_Interface(T))(it)
}

to_typed :: proc(it: ^Iterator_Interface($T), $S: typeid) -> ^Typed_Iterator(S, T) {
	return (^Typed_Iterator(S, T))(it)
}

@(private)
validate_iterator :: proc(it: $I/Typed_Iterator($S, $T)) -> I {
	it := it
	assert(it.update != nil, "update must be set")
	assert(it.is_valid != nil, "valid must be set")
	assert(it.get_item != nil, "get_item must be set")
	if it.get_index == nil {
		it.get_index = proc(it: ^Iterator_Interface(T)) -> int {
			return (^I)(it).state.index
		}
	}
	if it.is_dead == nil {
		it.is_dead = proc(it: ^Iterator_Interface(T)) -> bool {
			return false
		}
	}
	if it.reset != nil {
		assert(it.can_reset != nil, "if reset is set, can_reset must be set")
	} else {
		it.can_reset = proc(it: ^Iterator_Interface(T)) -> bool {
			return false
		}
		it.reset = proc(it: ^Iterator_Interface(T)) {
		}
	}
	return it
}

next_ref_untyped :: proc(it: ^$I/Iterator_Interface($T)) -> (result: ^T, index: int, ok: bool) {
	if it.is_dead(it) {
		return {}, -1, false
	}
	it.update(it)
	if it.is_valid(it) {
		return it.get_item(it), it.get_index(it), true
	}

	return {}, -1, false
}

next_ref_typed :: proc(it: ^$I/Typed_Iterator($S, $T)) -> (result: ^T, index: int, ok: bool) {
	if it.is_dead(it) {
		return {}, -1, false
	}
	it.update(it)
	if it.is_valid(it) {
		return it.get_item(it), it.get_index(it), true
	}

	return {}, -1, false
}

next_ref :: proc {
	next_ref_untyped,
	next_ref_typed,
}

next_val_untyped :: proc(it: ^$I/Iterator_Interface($T)) -> (result: T, index: int, ok: bool) {
	tmp: ^T
	tmp, index = next_ref(it) or_return
	return tmp^, index, true
}

next_val_typed :: proc(it: ^$I/Typed_Iterator($S, $T)) -> (result: T, index: int, ok: bool) {
	tmp: ^T
	tmp, index = next_ref(it) or_return
	return tmp^, index, true
}

next_val :: proc {
	next_val_untyped,
	next_val_typed,
}

reset_untyped :: proc(it: ^$I/Iterator_Interface($T)) -> bool {
	it.can_reset(it) or_return
	it.reset(it)
	return true
}

reset_typed :: proc(it: ^$I/Typed_Iterator($S, $T)) -> bool {
	it.can_reset(it) or_return
	it.reset(it)
	return true
}

reset :: proc {
	reset_untyped,
	reset_typed,
}
