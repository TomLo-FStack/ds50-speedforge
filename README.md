# DS50 Speedforge

V vs Go DS50 Benchmark

This project contains ACM-style implementations of 50 classic data-structure problems in V and Go, a shared benchmark harness, Julia analysis scripts, generated figures, and an ACM-style PDF report.

## Toolchains

- V is built locally under `tools/v` from the official `vlang/v` repository.
- Go is installed locally under `tools/go` from the official Windows amd64 archive.
- Julia is expected on PATH and is used for the numerical analysis.

## Reproduce

```powershell
cd E:\v_go_ds50_benchmark
.\scripts\build.ps1
.\scripts\run_bench.ps1 -Sizes '512,2048,8192' -Trials 20 -Repeat 3 -MinMs 5 -CpuCores 1 -MemoryLimitMB 1024
julia .\analysis\analyze.jl
python .\paper\make_paper.py
```

The build and benchmark scripts run child processes through `scripts/run_limited.ps1`.
By default this uses Idle process priority, one CPU core, and a Windows Job Object
memory ceiling. The benchmark harness reports the average nanoseconds per workload
call after accumulating at least `-MinMs` milliseconds for each measured sample,
which avoids zero-duration records on short Windows timer intervals.

Outputs:

- `data/raw_results.csv`: per-trial benchmark records, including adaptive `iterations`
- `data/summary.csv`: Julia statistical summary
- `data/comparison.csv`: Go/V median comparison by problem and input size
- `data/problem_summary.csv`, `data/category_summary.csv`, `data/size_summary.csv`: geomean speedup summaries
- `figures/*.svg`: Julia-generated figures
- `output/pdf/v_vs_go_ds50_acm.pdf`: final report
