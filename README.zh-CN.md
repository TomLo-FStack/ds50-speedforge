# DS50 Speedforge

**语言：** [English](README.md) | 简体中文

V vs Go DS50 基准测试

DS50 Speedforge 对比了 V 和 Go 在 50 个经典数据结构工作负载上的实现表现。
仓库包含基准测试源码、带资源限制的 Windows 运行脚本、原始测量数据、Julia
统计汇总、SVG 图表，以及中英文 PDF 报告。

## 报告

- [English PDF](output/pdf/v_vs_go_ds50_acm.en.pdf)
- [中文 PDF](output/pdf/v_vs_go_ds50_acm.zh-CN.pdf)
- [默认 PDF](output/pdf/v_vs_go_ds50_acm.pdf)：保留为兼容旧链接的英文文件名

当前结果摘要：

- 原始记录数：6000
- Checksum 不一致数：0
- 总体几何均值：Go 比 V 快 1.96x
- 胜负统计：Go 126，V 23，接近持平 1

## 工具链

- V 位于本地 `tools/v`，来自官方 `vlang/v` 仓库。
- Go 位于本地 `tools/go`，来自官方 Windows amd64 压缩包。
- Julia 需要在 PATH 中，用于数值分析。
- Python 和 `reportlab` 用于生成中英文 PDF 报告。

本地 `tools/` 目录已被 `.gitignore` 忽略，因为其中包含较大的下载版工具链。
如果要重新编译二进制，需要先在本地恢复对应工具链。

## 复现实验

```powershell
cd E:\v_go_ds50_benchmark
.\scripts\build.ps1
.\scripts\run_bench.ps1 -Sizes '512,2048,8192' -Trials 20 -Repeat 3 -MinMs 5 -CpuCores 1 -MemoryLimitMB 1024
julia .\analysis\analyze.jl
python .\paper\make_paper.py
```

构建和基准测试脚本都会通过 `scripts/run_limited.ps1` 启动子进程。默认配置使用
Idle 进程优先级、单 CPU 核心 affinity，以及 Windows Job Object 内存上限。
基准测试 harness 会让每条样本至少累计 `-MinMs` 毫秒后，再输出单次工作负载调用
的平均纳秒数，从而避免 Windows 短计时区间下出现 0 耗时记录。

## 输出文件

- `data/raw_results.csv`：逐 trial 原始记录，包含自适应计时的 `iterations`
- `data/summary.csv`：Julia 统计汇总
- `data/comparison.csv`：按题目和输入规模对比 Go/V 中位数
- `data/problem_summary.csv`、`data/category_summary.csv`、`data/size_summary.csv`：几何均值加速比汇总
- `figures/*.svg`：Julia 生成的图表
- `output/pdf/v_vs_go_ds50_acm.en.pdf`：英文报告
- `output/pdf/v_vs_go_ds50_acm.zh-CN.pdf`：中文报告
