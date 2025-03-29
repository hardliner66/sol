package demo

import op "../opaque"

import "core:log"
import "core:mem"

when RUN_OPAQUE_DEMO {
	SomeType :: struct {
		a: int,
		b: f32,
	}
	showcase_opaque :: proc() {
		original_value := SomeType {
			a = 42,
			b = 3.14,
		}
		o_ptr := &original_value
		opaque := op.make_opaque(original_value)
		new := op.get_value(opaque, SomeType)
		new_ptr := &new
		old_bytes := mem.ptr_to_bytes(o_ptr, size_of(SomeType))
		opaque_bytes := mem.ptr_to_bytes(&opaque.data, size_of(SomeType))
		new_bytes := mem.ptr_to_bytes(new_ptr, size_of(SomeType))
		log.debugf("original: %p, opaque: %p, new: %p", o_ptr, &opaque.data, new_ptr)
		for i in 0 ..< size_of(SomeType) {
			log.debugf(
				"original: %d, opaque: %d, new: %d",
				old_bytes[i],
				opaque_bytes[i],
				new_bytes[i],
			)
		}
	}
}
