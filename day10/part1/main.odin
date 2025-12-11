package main

import "core:bytes"
import "core:fmt"
import vmem "core:mem/virtual"
import os "core:os/os2"

dprintln :: #force_inline proc(args: ..any) {
	when ODIN_DEBUG {
		fmt.println(..args)
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
	if err := vmem.arena_init_static(&arena); err != nil {
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
		i: int
		target: uint
		assert(line[i] == '[')
		for i < len(line) && line[i] != ']' {
			target <<= 1
			if line[i] == '#' do target += 1
			i += 1
		}
		size := i - 2
		buttons := make([dynamic]uint)
		for i < len(line) && line[i] != '{' {
			button: uint
			for line[i] == ']' || line[i] == ' ' || line[i] == '(' || line[i] == ')' do i += 1
			if line[i] == '{' do break
			for i < len(line) && '0' <= line[i] && line[i] <= '9' {
				button += (1 << (cast(u8)size - (line[i] - '0')))
				i += 1
				if line[i] == ',' do i += 1
			}
			append(&buttons, button)
		}
		solution := solve_min_press(target, buttons)
		dprintln("solved =", solution)
		assert(solution > 0)
		acc += solution
	}
	fmt.println("acc =", acc)
}

solve_min_press :: proc(target: uint, buttons: [dynamic]uint) -> int {
	dprintfln("target = %v(%#b) buttons = %v", target, target, buttons)
	if target == 0 do return 0

	state := make([dynamic]uint)
	seen := make(map[uint]struct{})
	seen[0] = {}
	for s in buttons {
		if s == target do return 1
		seen[s] = {}
		append(&state, s)
	}

	new_state := make([dynamic]uint)
	step := 1
	for {
		clear(&new_state)
		step += 1
		dprintln("step =", step, state)
		assert(len(state) > 0)
		for s in state {
			for btn in buttons {
				new_s := s ~ btn
				dprintfln("%#8b = %#8b~%#8b", new_s, s, btn)
				if new_s == target do return step
				if new_s in seen do continue
				seen[new_s] = {}
				append(&new_state, new_s)
			}
		}
		clear(&state)
		for s in new_state {
			append(&state, s)
		}
	}
	return -1
}
