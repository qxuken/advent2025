package main

import "core:bytes"
import "core:fmt"
import "core:mem"
import vmem "core:mem/virtual"
import os "core:os/os2"
import "core:strconv"

dprintln :: #force_inline proc(args: ..any) {
	when ODIN_DEBUG {
		fmt.println(..args)
	}
}

dprint :: #force_inline proc(args: ..any) {
	when ODIN_DEBUG {
		fmt.print(..args)
	}
}


dprintfln :: #force_inline proc(fmt_s: string, args: ..any) {
	when ODIN_DEBUG {
		fmt.printfln(fmt_s, ..args)
	}
}

main :: proc() {
	if len(os.args) < 2 {
		fmt.eprintfln("Usage: %v <file_input>", os.args[0])
		os.exit(1)
	}

	arena: vmem.Arena
	if err := vmem.arena_init_growing(&arena, reserved = 40 * mem.Gigabyte); err != nil {
		fmt.eprintfln("Allocation Error %v", err)
		os.exit(1)
	}
	defer vmem.arena_destroy(&arena)
	context.allocator = vmem.arena_allocator(&arena)

	data, err := os.read_entire_file(os.args[1], context.allocator)
	if err != nil {
		fmt.eprintfln("Error reading file: %v", os.error_string(err))
		os.exit(1)
	}

	acc := 0
	for line in bytes.split_iterator(&data, {'\n'}) {
		buttons := make([dynamic]Vec10)
		{
			line := line
			for button_buf in bytes.split_iterator(&line, {'('}) {
				end := bytes.index_byte(button_buf[:], ')')
				if end == -1 do continue
				button: Vec10
				slice := button_buf[:end]
				for num_buf in bytes.split_iterator(&slice, {','}) {
					num, ok := strconv.parse_uint(string(num_buf), 10)
					assert(ok)
					button[num] = 1
				}
				append(&buttons, button)
			}
		}
		target: Vec10
		{
			line := line
			start := bytes.index_byte(line, '{') + 1
			assert(start > 0)
			offset := bytes.index_byte(line[start:], '}')
			assert(offset > 0)
			i := 0
			slice := line[start:start + offset]
			for buf in bytes.split_iterator(&slice, {','}) {
				num, ok := strconv.parse_uint(string(buf), 10)
				assert(ok)
				target[i] = num
				i += 1
			}
		}
		solution := solve_min_press(target, buttons)
		fmt.println("solution =", solution)
		assert(solution > 0)
		acc += solution
	}
	fmt.println("acc =", acc)
}

Vec10 :: [10]uint
VEC10_EMPTY: Vec10

solve_min_press :: proc(target: Vec10, buttons: [dynamic]Vec10) -> int {
	defer delete(buttons)
	dprintfln("target = %v buttons = %v", target, buttons)
	if target == VEC10_EMPTY do return 0

	state := make([dynamic]Vec10)
	defer delete(state)
	seen := make(map[Vec10]struct{})
	defer delete(seen)
	seen[VEC10_EMPTY] = {}
	for s in buttons {
		if s == target do return 1
		seen[s] = {}
		append(&state, s)
	}

	new_state := make([dynamic]Vec10)
	defer delete(new_state)
	step := 1
	for {
		clear(&new_state)
		step += 1
		if len(state) == 0 do break
		for s in state {
			btn_loop: for btn in buttons {
				new_s := s + btn
				if new_s == target do return step
				if new_s in seen do continue
				seen[new_s] = {}
				for i in 0 ..< 10 {
					if new_s[i] > target[i] do continue btn_loop
				}
				append(&new_state, new_s)
			}
		}
		state, new_state = new_state, state
		dprintln(step, len(state))
	}
	return -1
}
