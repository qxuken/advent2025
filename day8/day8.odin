package main

import "core:bytes"
import "core:fmt"
import vmem "core:mem/virtual"
import os "core:os/os2"
import "core:slice"
import "core:strconv"

main :: proc() {
	if len(os.args) < 3 {
		fmt.eprintfln("Usage: %v <file_input> <connections>", os.args[0])
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

	count, ok := strconv.parse_int(os.args[2], 10)
	if !ok {
		fmt.eprintfln("Error parsing count. Should be a number")
		os.exit(1)
	}

	vectors := make([dynamic]Vec3)
	for line in bytes.split_iterator(&data, {'\n'}) {
		t_line := line[:]
		vec: Vec3
		i := 0
		for number_buf in bytes.split_iterator(&t_line, {','}) {
			number: uint
			for b in number_buf {
				number = number * 10 + cast(uint)(b - '0')
			}
			vec[i] = number
			i += 1
		}
		append(&vectors, vec)
	}
	when ODIN_DEBUG {
		fmt.println("=== Vectors")
		fmt.println(vectors[:])
	}

	distances := make([dynamic]Vec3_Distance, 0, len(vectors) * (len(vectors) - 1) / 2)
	for vec_a, ai in vectors {
		for vec_b, bi in vectors[ai + 1:] {
			append(&distances, Vec3_Distance{ai, ai + bi + 1, vec3_distance(vec_a, vec_b)})
		}
	}
	slice.sort_by_cmp(
		distances[:],
		#force_inline proc(a: Vec3_Distance, b: Vec3_Distance) -> slice.Ordering {
			if a.distance > b.distance {
				return .Greater
			} else if a.distance < b.distance {
				return .Less
			} else {
				return .Equal
			}
		},
	)
	when ODIN_DEBUG {
		fmt.println("=== Distances")
		for d in distances {
			fmt.printfln("%v<=>%v = %v", vectors[d.a], vectors[d.b], d.distance)
		}
	}

	if count == 0 do count = len(distances)

	dsu := dsu_init(len(vectors))
	when ODIN_DEBUG do fmt.println("DSU", count)
	for d in distances[:count] {
		when ODIN_DEBUG do fmt.printfln(
			"%v:%v<=>%v:%v = %v",
			d.a,
			vectors[d.a],
			d.b,
			vectors[d.b],
			d.distance,
		)

		merged := dsu_union(&dsu, d.a, d.b)
		if merged && dsu.count == 1 {
			a := vectors[d.a]
			b := vectors[d.b]
			fmt.println("a.x * b.x =", a.x * b.x)
			break
		}
	}

	sizes_map := make(map[int]int)
	for i in 0 ..< len(vectors) {
		root := dsu_find(&dsu, i)
		sizes_map[root] = sizes_map[root] + 1
	}
	when ODIN_DEBUG do fmt.println("sizes_map =", sizes_map)

	sizes := make([dynamic]int, 0, len(sizes_map))
	for _, sz in sizes_map {
		append(&sizes, sz)
	}
	slice.reverse_sort(sizes[:])
	when ODIN_DEBUG do fmt.println("sizes =", sizes)

	mult := 1
	for i in 0 ..< min(3, len(sizes)) {
		mult *= sizes[i]
	}
	fmt.println("mult =", mult)
}

Vec3 :: [3]uint
Vec3_Distance :: struct {
	a, b:     int,
	distance: uint,
}

vec3_length2 :: #force_inline proc(a: Vec3) -> uint {
	return a.x * a.x + a.y * a.y + a.z * a.z
}

vec3_distance :: #force_inline proc(a: Vec3, b: Vec3) -> uint {
	return vec3_length2(b - a)
}

DSU :: struct {
	parent: []int,
	size:   []int,
	count:  int,
}

dsu_init :: proc(n: int, allocator := context.allocator) -> (dsu: DSU) {
	dsu.parent = make([]int, n, allocator = allocator)
	dsu.size = make([]int, n, allocator = allocator)

	for i in 0 ..< n {
		dsu.parent[i] = i
		dsu.size[i] = 1
	}
	dsu.count = n
	return
}

dsu_find :: proc(dsu: ^DSU, x: int) -> int {
	p := dsu.parent[x]
	if p != x {
		dsu.parent[x] = dsu_find(dsu, p)
	}
	return dsu.parent[x]
}

dsu_union :: proc(dsu: ^DSU, a, b: int) -> bool {
	ra := dsu_find(dsu, a)
	rb := dsu_find(dsu, b)
	if ra == rb do return false

	if dsu.size[ra] < dsu.size[rb] {
		ra, rb = rb, ra
	}

	dsu.parent[rb] = ra
	dsu.size[ra] += dsu.size[rb]
	dsu.count -= 1
	return true
}
