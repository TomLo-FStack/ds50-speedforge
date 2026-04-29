# DS50 Speedforge

**Language:** English | [简体中文](README.zh-CN.md)

V vs Go DS50 Benchmark

DS50 Speedforge compares V and Go implementations of 50 classic data-structure
workloads. The repository contains the benchmark sources, resource-limited
Windows runner scripts, raw measurements, Julia summaries, SVG figures, and
English/Chinese PDF reports.

## Reports

- [English PDF](output/pdf/v_vs_go_ds50_acm.en.pdf)
- [中文 PDF](output/pdf/v_vs_go_ds50_acm.zh-CN.pdf)
- [Default PDF](output/pdf/v_vs_go_ds50_acm.pdf), kept as an English-compatible legacy filename

Current result summary:

- Raw records: 6000
- Checksum mismatches: 0
- Overall geomean: Go is 1.96x faster than V
- Wins: Go 126, V 23, ties 1

## Toolchains

- V is built locally under `tools/v` from the official `vlang/v` repository.
- Go is installed locally under `tools/go` from the official Windows amd64 archive.
- Julia is expected on PATH and is used for the numerical analysis.
- Python with `reportlab` is used to generate the bilingual PDF reports.

The local `tools/` directory is intentionally ignored because it contains large
downloaded toolchains. Recreate it locally before rebuilding binaries.

## Reproduce

```powershell
cd E:\v_go_ds50_benchmark
.\scripts\build.ps1
.\scripts\run_bench.ps1 -Sizes '512,2048,8192' -Trials 20 -Repeat 3 -MinMs 5 -CpuCores 1 -MemoryLimitMB 1024
julia .\analysis\analyze.jl
python .\paper\make_paper.py
```

The build and benchmark scripts run child processes through
`scripts/run_limited.ps1`. By default this uses Idle process priority, one CPU
core, and a Windows Job Object memory ceiling. The benchmark harness reports the
average nanoseconds per workload call after accumulating at least `-MinMs`
milliseconds for each measured sample, which avoids zero-duration records on
short Windows timer intervals.

## Virtual-Memory Incident Note

During an early run, Windows reported low virtual memory at about `03:15:23`,
with `ds50_v.exe` showing roughly `53.7 GB` of virtual memory. A later run hit
the same class of failure before the benchmark harness and V implementation were
fixed. This was not a normal memory requirement of the 50-workload benchmark and
should not be interpreted as "V needs 50 GB to run DS50." It was a benchmark
implementation bug in the original V version of problem 26, "225 Stack Using
Queues".

The original V stack-via-queue implementation used a dynamic array as a queue
and repeatedly removed the first element:

```v
struct MyStack {
mut:
    q []int
}

fn (mut s MyStack) push(x int) {
    s.q << x
    for _ in 0 .. s.q.len - 1 {
        front := s.q[0]
        s.q.delete(0)
        s.q << front
    }
}

fn (mut s MyStack) pop() int {
    x := s.q[0]
    s.q.delete(0)
    return x
}
```

This is the wrong backing data structure for this workload. Removing index `0`
from a contiguous dynamic array is not a cheap queue pop. It has to preserve
element order, so the remaining tail elements must be shifted down. The workload
itself rotates the queue on every push to implement LIFO behavior. Combining
those two facts creates heavy repeated front deletion:

- one logical `push` performs up to `len(queue) - 1` queue rotations;
- each rotation performs `delete(0)`;
- each `delete(0)` may move many elements and can cause allocator churn;
- across thousands of pushes, this becomes a large quadratic data-movement
  workload with bad allocation behavior.

The visible symptom on Windows was a huge virtual-memory or commit footprint.
That number is not the same as physical RAM actively touched by useful data, but
it still matters: if a process reserves or commits too much virtual memory, it
can exhaust the system commit limit or pagefile and make the desktop unstable.
The partial `raw_v.csv` produced during the failed run stopped in the same
region of the benchmark, and a direct reproduction emitted:

```text
V panic: memory allocation failure
```

Go did not fail in the same way because the original Go version used slicing for
the front pop:

```go
s.q = s.q[1:]
```

That is still not the cleanest long-running queue representation, because it can
retain the backing array, but it does not repeatedly delete index `0` from a V
dynamic array. To keep the languages comparable and remove the artifact, both
implementations were changed to an explicit ring queue. The current V version is
bounded by a preallocated buffer and advances a head index instead of deleting
from the front:

```v
struct MyStack {
mut:
    q    []int
    head int
    size int
}

fn new_queue_stack(capacity int) MyStack {
    return MyStack{
        q: []int{len: capacity + 1}
    }
}

fn (mut s MyStack) push_back(x int) {
    idx := (s.head + s.size) % s.q.len
    s.q[idx] = x
    s.size++
}

fn (mut s MyStack) pop_front() int {
    x := s.q[s.head]
    s.head = (s.head + 1) % s.q.len
    s.size--
    return x
}

fn (mut s MyStack) push(x int) {
    s.push_back(x)
    for _ in 0 .. s.size - 1 {
        s.push_back(s.pop_front())
    }
}

fn (mut s MyStack) pop() int {
    return s.pop_front()
}
```

After this change, the same full experiment completed with `6000` raw records,
`0` zero-duration timing rows, and `0` checksum mismatches. The scripts also now
have operational guardrails:

- `scripts/run_limited.ps1` starts benchmark and build child processes at Idle
  priority;
- `-CpuCores 1` limits CPU affinity for slower but less intrusive runs;
- `-MemoryLimitMB` applies a Windows Job Object memory ceiling;
- `scripts/run_bench.ps1` checks native process exit codes and expected CSV line
  counts, so a crashed benchmark cannot silently leave a half-valid result file.

If you rerun the experiment, rebuild first with `.\scripts\build.ps1`. Running an
old `bin/ds50_v.exe` from before the ring-queue fix can reproduce the memory
spike even if the source file has already been corrected.

## Outputs

- `data/raw_results.csv`: per-trial benchmark records, including adaptive `iterations`
- `data/summary.csv`: Julia statistical summary
- `data/comparison.csv`: Go/V median comparison by problem and input size
- `data/problem_summary.csv`, `data/category_summary.csv`, `data/size_summary.csv`: geomean speedup summaries
- `figures/*.svg`: Julia-generated figures
- `output/pdf/v_vs_go_ds50_acm.en.pdf`: English report
- `output/pdf/v_vs_go_ds50_acm.zh-CN.pdf`: Chinese report
