use std::{
    cmp::Ordering,
    env,
    fs::{self, OpenOptions},
    io::{self, BufWriter, Read, Write},
    ops::{Add, Index, IndexMut},
    sync::{Arc, Mutex},
};

use advent2025::{debug_println, perf};
use ahash::{AHashMap, AHashSet};
use bytemuck::NoUninit;
use derive_hash_fast::derive_hash_fast_bytemuck;
use mimalloc::MiMalloc;
use rayon::prelude::*;

#[global_allocator]
static GLOBAL: MiMalloc = MiMalloc;

const VEC10_EMPTY: Vec10 = Vec10([0; 10]);

#[repr(C)]
#[derive(Debug, Default, Clone, Copy, NoUninit)]
struct Vec10([u16; 10]);

derive_hash_fast_bytemuck!(Vec10);

impl Vec10 {
    fn iter(&self) -> std::slice::Iter<'_, u16> {
        self.0.iter()
    }
}

impl PartialOrd for Vec10 {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl PartialEq for Vec10 {
    fn eq(&self, other: &Self) -> bool {
        self.iter().enumerate().all(|(i, &v)| other.0[i] == v)
    }
}

impl Ord for Vec10 {
    fn cmp(&self, other: &Self) -> Ordering {
        let mut res = Ordering::Equal;
        for i in 0..10 {
            match self[i].cmp(&other[i]) {
                Ordering::Equal => continue,
                Ordering::Greater => return Ordering::Greater,
                Ordering::Less => res = Ordering::Less,
            }
        }
        res
    }
}

impl Eq for Vec10 {}

impl Add for Vec10 {
    type Output = Self;
    fn add(mut self, rhs: Self) -> Self::Output {
        for (i, v) in rhs.iter().enumerate() {
            self[i] += v;
        }
        self
    }
}

impl Index<usize> for Vec10 {
    type Output = u16;

    fn index(&self, idx: usize) -> &Self::Output {
        &self.0[idx]
    }
}

impl IndexMut<usize> for Vec10 {
    fn index_mut(&mut self, idx: usize) -> &mut Self::Output {
        &mut self.0[idx]
    }
}

#[derive(Debug, Clone)]
struct Task {
    id: usize,
    target: Vec10,
    buttons: Vec<Vec10>,
}

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    let Some(file_path) = args.get(1) else {
        eprintln!(
            "Usage: {} <file_input>",
            args.first().map(|s| s.as_str()).unwrap_or("program")
        );
        return Err(io::Error::other("file_input missing"));
    };
    let cpus = num_cpus::get();
    debug_println!("cpus = {cpus}");
    rayon::ThreadPoolBuilder::new()
        .num_threads(cpus)
        .build_global()
        .unwrap();
    let mut outfile = OpenOptions::new()
        .read(true)
        .create(true)
        .append(true)
        .open("output.txt")?;
    let done_tasks = {
        let mut buf = String::new();
        outfile.read_to_string(&mut buf)?;
        buf.lines()
            .map(|line| line.split_once(',').unwrap())
            .map(|(line, res)| {
                (
                    line.parse::<usize>().unwrap(),
                    res.parse::<usize>().unwrap(),
                )
            })
            .collect::<AHashMap<usize, usize>>()
    };
    let writer = Arc::new(Mutex::new(BufWriter::new(outfile)));
    debug_println!("{done_tasks:?}");

    perf!("entire", {
        let data = perf!("read", {
            let mut file = fs::File::open(file_path)?;
            let mut buf = String::new();
            file.read_to_string(&mut buf)?;
            buf.replace("-", " ")
        });

        let tasks = perf!("parse", {
            data.lines()
                .enumerate()
                .filter(|(i, _)| !done_tasks.contains_key(i))
                .map(|(id, l)| {
                    let buttons = l
                        .split('(')
                        .skip(1)
                        .map(|b| b.chars().take_while(|&c| c != ')').collect::<String>())
                        .map(|b| {
                            b.split(',').fold(Vec10::default(), |mut acc, it| {
                                let num = it.parse::<usize>().expect("Must be a number");
                                acc[num] = 1;
                                acc
                            })
                        })
                        .collect();

                    let target = l
                        .split_once('{')
                        .map(|(_, right)| right)
                        .map(|t| t.chars().take_while(|&c| c != '}').collect::<String>())
                        .map(|t| {
                            t.split(',')
                                .enumerate()
                                .fold(Vec10::default(), |mut acc, (i, it)| {
                                    let num = it.parse::<u16>().expect("Must be a number");
                                    acc[i] = num;
                                    acc
                                })
                        })
                        .expect("Should be a target");
                    Task {
                        id,
                        target,
                        buttons,
                    }
                })
                .collect::<Vec<_>>()
        });
        debug_println!("{tasks:?}");
        let solution: u64 = perf!("full_solution", {
            tasks
                .into_iter()
                .map(|t| {
                    let id = t.id;
                    let res = perf!("solution", { solve_min_press(t) });
                    let mut writer = writer.lock().unwrap();
                    writeln!(writer, "{id},{res}").unwrap();
                    writer.flush().unwrap();
                    res
                })
                .sum()
        });
        println!("solution = {solution}");
    });
    Ok(())
}

fn solve_min_press(task: Task) -> u64 {
    debug_println!("target = {:?} buttons = {:?}", &task.target, &task.buttons);
    if task.target == VEC10_EMPTY {
        return 0;
    }

    let mut state = task.buttons.clone();
    let mut seen: AHashSet<Vec10> = state.iter().copied().collect();
    let mut step = 1u64;
    while !state.is_empty() {
        perf!(&format!("#{step:<5} search({})", state.len()), {
            if seen.contains(&task.target) {
                println!("{:?} solution {}", task.target, step);
                return step;
            }
        });
        step += 1;
        state = perf!(&format!("       expand({})", state.len()), {
            state
                .into_par_iter()
                .flat_map_iter(|it| task.buttons.iter().map(move |btn| *btn + it))
                .filter(|it| *it <= task.target)
                .collect()
        });

        state = perf!(&format!("       reduce({})", state.len()), {
            seen.reserve(state.len());
            state.into_iter().filter(|v| seen.insert(*v)).collect()
        });
    }
    unreachable!()
}
