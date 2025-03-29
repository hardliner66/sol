package demo

import "core:log"
import "core:mem"

log_alloc: mem.Allocator

// helper to be able to log while panic allocator is active
info :: proc(fmt_str: string, args: ..any, location := #caller_location) {
	old_alloc := context.allocator
	defer context.allocator = old_alloc

	old_temp_alloc := context.temp_allocator
	defer context.temp_allocator = old_temp_alloc

	context.allocator = log_alloc
	context.temp_allocator = log_alloc

	log.infof(fmt_str, ..args, location = location)
}
