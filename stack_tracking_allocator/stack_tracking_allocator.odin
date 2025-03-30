#+build windows
package stack_tracking_allocator

import "base:intrinsics"
import "base:runtime"
import "core:debug/trace"
import "core:fmt"
import "core:mem"
import "core:os"
import path "core:path/filepath"
import "core:strings"
import "core:sync"
import win32 "core:sys/windows"

Context :: trace.Context
init :: trace.init
destroy :: trace.destroy
Frame :: trace.Frame

Stack_Frame :: struct {
	using fl: trace.Frame_Location,
	frame:    string,
}
Stack_Trace :: []Stack_Frame

/*
Allocation entry for the stack tracking allocator.

This structure stores the data related to an allocation.
*/
Stack_Tracking_Allocator_Entry :: struct {
	using inner: mem.Tracking_Allocator_Entry,
	// Stack trace of the allocation.
	stack_trace: Stack_Trace,
}

/*
Bad free entry for a stack tracking allocator.
*/
Stack_Tracking_Allocator_Bad_Free_Entry :: struct {
	using inner: mem.Tracking_Allocator_Bad_Free_Entry,
	// Stack trace of the bad free.
	stack_trace: Stack_Trace,
}

/*
Callback type for when stack tracking allocator runs into a bad free.
*/
Stack_Tracking_Allocator_Bad_Free_Callback :: proc(
	t: ^Stack_Tracking_Allocator,
	memory: rawptr,
	location: runtime.Source_Code_Location,
	stack_trace: Stack_Trace,
)

/*
Stack tracking allocator data.
*/
Stack_Tracking_Allocator :: struct {
	inner:             mem.Tracking_Allocator,
	allocation_map:    map[rawptr]Stack_Tracking_Allocator_Entry,
	bad_free_callback: Stack_Tracking_Allocator_Bad_Free_Callback,
	bad_free_array:    [dynamic]Stack_Tracking_Allocator_Bad_Free_Entry,
	trace_context:     ^trace.Context,
	internal_alloc:    mem.Allocator,
}

/*
Initialize the stack tracking allocator.

This procedure initializes the stack tracking allocator `t` with a backing allocator
specified with `backing_allocator`. The `internals_allocator` will used to
allocate the tracked data.
*/
stack_tracking_allocator_init :: proc(
	t: ^Stack_Tracking_Allocator,
	backing_allocator: mem.Allocator,
	trace_context: ^trace.Context,
	internal_allocator := context.allocator,
) {
	mem.tracking_allocator_init(&t.inner, backing_allocator, internal_allocator)
	t.internal_alloc = internal_allocator
	t.trace_context = trace_context
	t.allocation_map.allocator = internal_allocator
	t.bad_free_callback = stack_tracking_allocator_bad_free_callback_panic
	t.bad_free_array.allocator = internal_allocator
}

/*
Destroy the stack tracking allocator.
*/
stack_tracking_allocator_destroy :: proc(t: ^Stack_Tracking_Allocator) {
	// todo, check if slices are deleted
	delete(t.allocation_map)
	delete(t.bad_free_array)
}

/*
Clear the stack tracking allocator.

This procedure clears the tracked data from a stack tracking allocator.

**Note**: This procedure clears only the current allocation data while keeping
the totals intact.
*/
stack_tracking_allocator_clear :: proc(t: ^Stack_Tracking_Allocator) {
	mem.tracking_allocator_clear(&t.inner)
	// todo, check if slices are deleted
	sync.mutex_lock(&t.inner.mutex)
	clear(&t.allocation_map)
	clear(&t.bad_free_array)
	sync.mutex_unlock(&t.inner.mutex)
}

/*
Reset the stack tracking allocator.

Reset all of a Stack Tracking Allocator's allocation data back to zero.
*/
stack_tracking_allocator_reset :: proc(t: ^Stack_Tracking_Allocator) {
	mem.tracking_allocator_reset(&t.inner)
	sync.mutex_lock(&t.inner.mutex)
	clear(&t.allocation_map)
	clear(&t.bad_free_array)
	sync.mutex_unlock(&t.inner.mutex)
}

/*
Default behavior for a bad free: Crash with error message that says where the
bad free happened.

Override Stack_Tracking_Allocator.bad_free_callback to have something else happen. For
example, you can use stack_tracking_allocator_bad_free_callback_add_to_array to return
the stack tracking allocator to the old behavior, where the bad_free_array was used.
*/
stack_tracking_allocator_bad_free_callback_panic :: proc(
	t: ^Stack_Tracking_Allocator,
	memory: rawptr,
	location: runtime.Source_Code_Location,
	stack_trace: Stack_Trace,
) {
	runtime.print_caller_location(location)
	runtime.print_string(" Stack tracking allocator error: Bad free of pointer ")
	runtime.print_uintptr(uintptr(memory))
	runtime.print_string("\n")
	runtime.print_string("Stack Trace:\n")
	print_stack_trace(t, stack_trace)
	runtime.trap()
}

/*
Alternative behavior for a bad free: Store in `bad_free_array`. If you use this,
then you must make sure to check Stack_Tracking_Allocator.bad_free_array at some point.
*/
stack_tracking_allocator_bad_free_callback_add_to_array :: proc(
	t: ^Stack_Tracking_Allocator,
	memory: rawptr,
	location: runtime.Source_Code_Location,
) {
	append(
		&t.bad_free_array,
		Stack_Tracking_Allocator_Bad_Free_Entry{memory = memory, location = location},
	)
}

/*
Stack tracking allocator.

The stack tracking allocator is an allocator wrapper that tracks memory allocations.
This allocator stores all the allocations in a map. Whenever a pointer that's
not inside of the map is freed, the `bad_free_array` entry is added.

Here follows an example of how to use the `Stack_Tracking_Allocator` to track
subsequent allocations in your program and report leaks. By default, the
stack tracking allocator will crash on bad frees. You can override that behavior by
overriding `track.bad_free_callback`.

Example:

	package foo

	import "core:fmt"

	main :: proc() {
		track: sta.Stack_Tracking_Allocator
		sta.stack_tracking_allocator_init(&track, context.allocator)
		defer sta.stack_tracking_allocator_destroy(&track)
		context.allocator = sta.stack_tracking_allocator(&track)

		do_stuff()

		for _, leak in track.allocation_map {
			fmt.printf("%v leaked %m\n", leak.location, leak.size)
			sta.print_stack_trace(&track, leak.stack_trace)
		}
	}
*/
@(require_results)
stack_tracking_allocator :: proc(data: ^Stack_Tracking_Allocator) -> mem.Allocator {
	return mem.Allocator{data = data, procedure = stack_tracking_allocator_proc}
}

@(private)
resolve :: proc(
	ctx: ^trace.Context,
	frame: Frame,
	allocator := context.allocator,
) -> (
	fl: Stack_Frame,
) {
	intrinsics.atomic_store(&ctx.in_resolve, true)
	defer intrinsics.atomic_store(&ctx.in_resolve, false)

	// NOTE(bill): Dbghelp is not thread-safe
	win32.AcquireSRWLockExclusive(&ctx.impl.lock)
	defer win32.ReleaseSRWLockExclusive(&ctx.impl.lock)

	data: [size_of(win32.SYMBOL_INFOW) + size_of([256]win32.WCHAR)]byte
	symbol := (^win32.SYMBOL_INFOW)(&data[0])
	symbol.SizeOfStruct = size_of(symbol^)
	symbol.MaxNameLen = 255
	addr := fmt.aprintf("0x%x", frame, allocator = allocator)
	fl.frame = addr
	if win32.SymFromAddrW(ctx.impl.hProcess, win32.DWORD64(frame), &{}, symbol) {
		fl.procedure, _ = win32.wstring_to_utf8(&symbol.Name[0], -1, allocator)
	} else {
		fmt.println(win32.GetLastError())
		fl.procedure = "<unknown>"
	}

	line: win32.IMAGEHLP_LINE64
	line.SizeOfStruct = size_of(line)
	if win32.SymGetLineFromAddrW64(ctx.impl.hProcess, win32.DWORD64(frame), &{}, &line) {
		fl.file_path, _ = win32.wstring_to_utf8(line.FileName, -1, allocator)
		fl.line = i32(line.LineNumber)
	}

	return
}

print_stack_trace :: proc(data: ^Stack_Tracking_Allocator, stack_trace: Stack_Trace) {
	old_alloc := context.allocator
	context.allocator = data.internal_alloc
	defer context.allocator = old_alloc

	runtime.print_byte('|')
	runtime.print_string(strings.repeat("=", 78))
	runtime.print_string("|\n")
	runtime.print_string("|.")
	runtime.print_string(strings.center_justify(" Stack Trace ", 76, "="))
	runtime.print_string(".|\n")
	runtime.print_string("|..")
	runtime.print_string(strings.repeat("=", 74))
	runtime.print_string("..|\n")

	for fl, i in stack_trace {
		file_path := fl.file_path
		if strings.starts_with(file_path, ODIN_ROOT) {
			file_path, _ = strings.replace(
				file_path,
				ODIN_ROOT,
				"(ODIN_ROOT)/" when path.SEPARATOR == '/' else "(ODIN_ROOT)\\",
				1,
			)
		}

		procedure := fl.procedure
		if strings.contains(procedure, ":proc(") {
			pos := strings.index(procedure, ":proc(")
			procedure = procedure[:pos]
		}

		procedure = fmt.aprintf("%s() ", procedure)

		runtime.print_string(strings.left_justify(fmt.aprintf("| #%d", i), 3, " "))
		if !strings.starts_with(file_path, "(ODIN_ROOT)") {
			err: path.Relative_Error
			file_path, err = path.rel(os.get_current_directory(), file_path)
			if err != nil {
				file_path = fl.file_path
			}
		}

		runtime.print_string(" [")
		runtime.print_string(fl.frame)
		runtime.print_string("] ")
		runtime.print_string(procedure)
		runtime.print_string("\n|---- ")
		if path.is_abs(file_path) ||
		   strings.starts_with(file_path, ".") ||
		   strings.starts_with(file_path, "(ODIN_ROOT)") {
			runtime.print_string(file_path)
		} else {
			runtime.print_byte('.')
			runtime.print_byte(path.SEPARATOR)
			runtime.print_string(file_path)
		}
		runtime.print_byte(':')
		runtime.print_u64(u64(fl.line))
		if fl.column != 0 {
			runtime.print_byte(':')
			runtime.print_u64(u64(fl.column))
		}
		runtime.print_string("\n")
	}
}

get_trace :: proc(data: ^Stack_Tracking_Allocator) -> []Stack_Frame {
	old_alloc := context.allocator
	context.allocator = data.internal_alloc
	defer context.allocator = old_alloc

	frame_list := make([dynamic]Stack_Frame)
	ctx := data.trace_context
	if !trace.in_resolve(ctx) {
		buf: [64]Frame
		frames := trace.frames(ctx, 1, buf[:])
		for f in frames {
			fl := resolve(ctx, f)
			if fl.loc.file_path == "" || fl.loc.line == 0 || fl.loc.procedure == "__scrt_common_main_seh" {
				continue
			}
			append(&frame_list, fl)

		}
	}
	return frame_list[:]
}

stack_tracking_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	location := #caller_location,
) -> (
	result: []byte,
	err: mem.Allocator_Error,
) {
	track_alloc :: proc(data: ^Stack_Tracking_Allocator, entry: ^Stack_Tracking_Allocator_Entry) {
		data.inner.total_memory_allocated += i64(entry.size)
		data.inner.total_allocation_count += 1
		data.inner.current_memory_allocated += i64(entry.size)
		if data.inner.current_memory_allocated > data.inner.peak_memory_allocated {
			data.inner.peak_memory_allocated = data.inner.current_memory_allocated
		}
	}

	track_free :: proc(data: ^Stack_Tracking_Allocator, entry: ^Stack_Tracking_Allocator_Entry) {
		data.inner.total_memory_freed += i64(entry.size)
		data.inner.total_free_count += 1
		data.inner.current_memory_allocated -= i64(entry.size)
	}

	data := (^Stack_Tracking_Allocator)(allocator_data)

	sync.mutex_guard(&data.inner.mutex)

	stack_trace := get_trace(data)

	if mode == .Query_Info {
		info := (^mem.Allocator_Query_Info)(old_memory)
		if info != nil && info.pointer != nil {
			if entry, ok := data.allocation_map[info.pointer]; ok {
				info.size = entry.size
				info.alignment = entry.alignment
			}
			info.pointer = nil
		}

		return
	}

	if mode == .Free && old_memory != nil && old_memory not_in data.allocation_map {
		if data.bad_free_callback != nil {
			data.bad_free_callback(data, old_memory, location, stack_trace)
		}
	} else {
		result = data.inner.backing.procedure(
			data.inner.backing.data,
			mode,
			size,
			alignment,
			old_memory,
			old_size,
			location,
		) or_return
	}
	result_ptr := raw_data(result)

	if data.allocation_map.allocator.procedure == nil {
		data.allocation_map.allocator = context.allocator
	}

	switch mode {
	case .Alloc, .Alloc_Non_Zeroed:
		data.allocation_map[result_ptr] = Stack_Tracking_Allocator_Entry {
			memory      = result_ptr,
			size        = size,
			mode        = mode,
			alignment   = alignment,
			err         = err,
			location    = location,
			stack_trace = stack_trace,
		}
		track_alloc(data, &data.allocation_map[result_ptr])
	case .Free:
		if old_memory != nil && old_memory in data.allocation_map {
			track_free(data, &data.allocation_map[old_memory])
		}
		delete_key(&data.allocation_map, old_memory)
	case .Free_All:
		if data.inner.clear_on_free_all {
			clear_map(&data.allocation_map)
			data.inner.current_memory_allocated = 0
		}
	case .Resize, .Resize_Non_Zeroed:
		if old_memory != nil && old_memory in data.allocation_map {
			track_free(data, &data.allocation_map[old_memory])
		}
		if old_memory != result_ptr {
			delete_key(&data.allocation_map, old_memory)
		}
		data.allocation_map[result_ptr] = Stack_Tracking_Allocator_Entry {
			memory      = result_ptr,
			size        = size,
			mode        = mode,
			alignment   = alignment,
			err         = err,
			location    = location,
			stack_trace = stack_trace,
		}
		track_alloc(data, &data.allocation_map[result_ptr])

	case .Query_Features:
		set := (^mem.Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = {
				.Alloc,
				.Alloc_Non_Zeroed,
				.Free,
				.Free_All,
				.Resize,
				.Query_Features,
				.Query_Info,
			}
		}
		return nil, nil

	case .Query_Info:
		unreachable()
	}

	return
}
