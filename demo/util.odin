package demo

import "core:fmt"
import "core:mem"

log_alloc: mem.Allocator

// helper to be able to log while panic allocator is active
info :: proc(fmt_str: string, args: ..any) {
	old_alloc := context.allocator
	defer context.allocator = old_alloc

	old_temp_alloc := context.temp_allocator
	defer context.temp_allocator = old_temp_alloc

	context.allocator = log_alloc
	context.temp_allocator = log_alloc

	fmt.printfln(fmt_str, ..args)
}
