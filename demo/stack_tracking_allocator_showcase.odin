package demo

when RUN_STA_DEMO {
	d :: proc() {
		// allocate something, so the allocator has something to track
		some_value := make([]int, 1000)
		_ = some_value
	}
	c :: proc() {
		d()
	}
	b :: proc() {
		c()
	}
	a :: proc() {
		b()
	}
	showcase_stack_tracking_allocator :: proc() {
		a()
	}
}
