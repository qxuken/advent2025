package main

import "core:fmt"
import vmem "core:mem/virtual"
import os "core:os/os2"

Map :: struct {
	value: []byte,
	size:  int,
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
		fmt.eprintfln("Error opening file: %v", os.error_string(err))
		os.exit(1)
	}

	m := new(Map)
	m.value = data
	for c in m.value {
		if c == '\r' {
			fmt.eprintln("Remove CR from data")
			os.exit(1)
		}
		if c == '\n' {
			break
		}
		m.size += 1
	}

	when ODIN_DEBUG do fmt.println("m.size =", m.size)

	stride := m.size + 1
	counter := 0

	for y in 0 ..< m.size {
		row_base := y * stride
		for x in 0 ..< m.size {
			if m.value[row_base + x] == '@' {
				counter += dfs(m, x, y)
			}
		}
	}

	when ODIN_DEBUG {
		fmt.println(string(m.value))
	}

	fmt.println("counter =", counter)
}

dfs :: proc(m: ^Map, x, y: int) -> int {
	size := m.size
	stride := size + 1
	value := m.value

	y_start := max(y - 1, 0)
	y_end := min(y + 1, size - 1)
	x_start := max(x - 1, 0)
	x_end := min(x + 1, size - 1)

	neighbor_count := 0
	for cy in y_start ..= y_end {
		row_base := cy * stride + x_start
		for cx in x_start ..= x_end {
			if cy == y && cx == x {
				row_base += 1
				continue
			}
			if value[row_base] == '@' {
				neighbor_count += 1
				if neighbor_count > 3 {
					return 0
				}
			}
			row_base += 1
		}
	}

	value[y * stride + x] = 'x'

	result := 1
	for cy in y_start ..= y_end {
		row_base := cy * stride + x_start
		for cx in x_start ..= x_end {
			if value[row_base] == '@' {
				result += dfs(m, cx, cy)
			}
			row_base += 1
		}
	}

	return result
}
