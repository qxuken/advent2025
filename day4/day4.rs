use advent2025::debug_println;
use std::{env, fs, io};

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    let Some(file_path) = args.get(1) else {
        eprintln!(
            "Usage: {} <file_input>",
            args.first().map(|s| s.as_str()).unwrap_or("day4")
        );
        return Err(io::Error::other("file_input missing"));
    };

    let mut data = fs::read(file_path)?;

    let mut size = 0usize;
    for &b in &data {
        if b == b'\r' {
            eprintln!("Remove CR from data");
            return Err(io::Error::other("input has CR"));
        }
        if b == b'\n' {
            break;
        }
        size += 1;
    }

    debug_println!("m.size = {}", size);

    let stride = size + 1;
    let mut counter: i32 = 0;

    for y in 0..size {
        let row_base = y * stride;
        for x in 0..size {
            let idx = row_base + x;
            if data[idx] == b'@' {
                counter += dfs(&mut data, size, stride, x, y);
            }
        }
    }

    // Optional: dump final map in debug builds
    debug_println!("{}", String::from_utf8_lossy(&data));
    println!("counter = {counter}");

    Ok(())
}

fn dfs(map: &mut [u8], size: usize, stride: usize, x: usize, y: usize) -> i32 {
    let y_start = y.saturating_sub(1);
    let y_end = (y + 1).min(size - 1);
    let x_start = x.saturating_sub(1);
    let x_end = (x + 1).min(size - 1);

    let mut neighbor_count = 0;
    for cy in y_start..=y_end {
        let mut idx = cy * stride + x_start;
        for cx in x_start..=x_end {
            if cy == y && cx == x {
                idx += 1;
                continue;
            }
            if map[idx] == b'@' {
                neighbor_count += 1;
                if neighbor_count > 3 {
                    return 0;
                }
            }
            idx += 1;
        }
    }

    map[y * stride + x] = b'x';

    let mut result = 1;
    for cy in y_start..=y_end {
        let mut idx = cy * stride + x_start;
        for cx in x_start..=x_end {
            if map[idx] == b'@' {
                result += dfs(map, size, stride, cx, cy);
            }
            idx += 1;
        }
    }

    result
}
