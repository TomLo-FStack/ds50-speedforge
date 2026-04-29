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

## Outputs

- `data/raw_results.csv`: per-trial benchmark records, including adaptive `iterations`
- `data/summary.csv`: Julia statistical summary
- `data/comparison.csv`: Go/V median comparison by problem and input size
- `data/problem_summary.csv`, `data/category_summary.csv`, `data/size_summary.csv`: geomean speedup summaries
- `figures/*.svg`: Julia-generated figures
- `output/pdf/v_vs_go_ds50_acm.en.pdf`: English report
- `output/pdf/v_vs_go_ds50_acm.zh-CN.pdf`: Chinese report
