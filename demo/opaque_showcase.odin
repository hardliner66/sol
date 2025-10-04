package demo

@(require) import op "../opaque"

@(require) import "core:fmt"
@(require) import "core:mem"

when RUN_OPAQUE_DEMO {
	Some_Type :: struct {
		a: int,
		b: f32,
	}

	opaque_inline_showcase :: proc() {
		original_value := Some_Type {
			a = 42,
			b = 3.14,
		}
		o_ptr := &original_value
		opaque := op.make_opaque(original_value)
		new := op.get_value(opaque, Some_Type)
		new_ptr := &new
		old_bytes := mem.ptr_to_bytes(o_ptr, size_of(Some_Type))
		opaque_bytes := mem.ptr_to_bytes(&opaque.data, size_of(Some_Type))
		new_bytes := mem.ptr_to_bytes(new_ptr, size_of(Some_Type))
		fmt.printfln("original: %p, opaque: %p, new: %p", o_ptr, &opaque.data, new_ptr)
		for i in 0 ..< size_of(Some_Type) {
			fmt.printfln(
				"original: %d, opaque: %d, new: %d",
				old_bytes[i],
				opaque_bytes[i],
				new_bytes[i],
			)
		}
	}

	opaque_boxed_showcase :: proc() {
		original_value := Some_Type {
			a = 42,
			b = 3.14,
		}
		o_ptr := &original_value
		opaque, err := op.make_opaque_boxed(original_value)
		assert(err == nil)
		defer op.destroy_boxed_opaque(&opaque)

		new := op.get_value(opaque, Some_Type)
		new_ptr := &new
		old_bytes := mem.ptr_to_bytes(o_ptr, size_of(Some_Type))
		opaque_bytes := mem.ptr_to_bytes(raw_data(opaque.data), size_of(Some_Type))
		new_bytes := mem.ptr_to_bytes(new_ptr, size_of(Some_Type))
		fmt.printfln("original: %p, opaque: %p, new: %p", o_ptr, &opaque.data, new_ptr)
		for i in 0 ..< size_of(Some_Type) {
			fmt.printfln(
				"original: %d, opaque: %d, new: %d",
				old_bytes[i],
				opaque_bytes[i],
				new_bytes[i],
			)
		}
	}

	opaque_ptr_showcase :: proc() {
		original_value := Some_Type {
			a = 42,
			b = 3.14,
		}
		o_ptr := &original_value
		opaque := op.make_opaque_ptr(&original_value)

		new := op.get_value(opaque, Some_Type)
		new_ptr := &new
		old_bytes := mem.ptr_to_bytes(o_ptr)
		opaque_bytes := mem.ptr_to_bytes(op.get_ptr(opaque, Some_Type))
		new_bytes := mem.ptr_to_bytes(new_ptr)
		fmt.printfln(
			"original: %p, opaque: %p, new: %p",
			o_ptr,
			op.get_ptr(opaque, Some_Type),
			new_ptr,
		)
		for i in 0 ..< size_of(Some_Type) {
			fmt.printfln(
				"original: %d, opaque: %d, new: %d",
				old_bytes[i],
				opaque_bytes[i],
				new_bytes[i],
			)
		}
	}

	union_opaque_inline_showcase :: proc() {
		original_value := Some_Type {
			a = 42,
			b = 3.14,
		}
		o_ptr := &original_value
		opaque: op.Opaque(size_of(Some_Type)) = op.make_opaque(original_value)
		new := op.get_value(opaque, Some_Type)
		new_ptr := &new
		old_bytes := mem.ptr_to_bytes(o_ptr)
		opaque_bytes := mem.ptr_to_bytes(op.get_ptr(&opaque, Some_Type))
		new_bytes := mem.ptr_to_bytes(new_ptr)
		fmt.printfln(
			"original: %p, opaque: %p, new: %p",
			o_ptr,
			op.get_ptr(&opaque, Some_Type),
			new_ptr,
		)
		for i in 0 ..< size_of(Some_Type) {
			fmt.printfln(
				"original: %d, opaque: %d, new: %d",
				old_bytes[i],
				opaque_bytes[i],
				new_bytes[i],
			)
		}
	}

	union_opaque_boxed_showcase :: proc() {
		original_value := Some_Type {
			a = 42,
			b = 3.14,
		}
		o_ptr := &original_value
		o, err := op.make_opaque_boxed(original_value)
		assert(err == nil)
		defer op.destroy_boxed_opaque(&o)

		opaque: op.Opaque(size_of(Some_Type)) = o

		new := op.get_value(opaque, Some_Type)
		new_ptr := &new
		old_bytes := mem.ptr_to_bytes(o_ptr)
		opaque_bytes := mem.ptr_to_bytes(op.get_ptr(&opaque, Some_Type))
		new_bytes := mem.ptr_to_bytes(new_ptr)
		fmt.printfln(
			"original: %p, opaque: %p, new: %p",
			o_ptr,
			op.get_ptr(&opaque, Some_Type),
			new_ptr,
		)
		for i in 0 ..< size_of(Some_Type) {
			fmt.printfln(
				"original: %d, opaque: %d, new: %d",
				old_bytes[i],
				opaque_bytes[i],
				new_bytes[i],
			)
		}
	}

	union_opaque_ptr_showcase :: proc() {
		original_value := Some_Type {
			a = 42,
			b = 3.14,
		}
		o_ptr := &original_value
		opaque: op.Opaque(size_of(Some_Type)) = op.make_opaque_ptr(&original_value)

		new := op.get_value(opaque, Some_Type)
		new_ptr := &new
		old_bytes := mem.ptr_to_bytes(o_ptr)
		opaque_bytes := mem.ptr_to_bytes(op.get_ptr(&opaque, Some_Type))
		new_bytes := mem.ptr_to_bytes(new_ptr)
		fmt.printfln(
			"original: %p, opaque: %p, new: %p",
			o_ptr,
			op.get_ptr(&opaque, Some_Type),
			new_ptr,
		)
		for i in 0 ..< size_of(Some_Type) {
			fmt.printfln(
				"original: %d, opaque: %d, new: %d",
				old_bytes[i],
				opaque_bytes[i],
				new_bytes[i],
			)
		}
	}

	showcase_opaque :: proc() {
		opaque_inline_showcase()
		opaque_boxed_showcase()
		opaque_ptr_showcase()
		union_opaque_inline_showcase()
		union_opaque_boxed_showcase()
		union_opaque_ptr_showcase()
	}
}
