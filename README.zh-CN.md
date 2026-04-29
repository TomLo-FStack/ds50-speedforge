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

## 虚拟内存暴涨事故说明

早期一次运行中，Windows 在大约 `03:15:23` 报告系统虚拟内存不足，并显示
`ds50_v.exe` 占用了约 `53.7 GB` 虚拟内存。之后又出现过一次同类爆内存现象。
这个现象不是 DS50 这 50 个工作负载的正常内存需求，也不应该被解读成“V 跑这组
基准测试需要 50GB 内存”。根因是最初 V 版第 26 题，也就是
“225 Stack Using Queues / 用队列实现栈”的队列底层实现选错了数据结构。

最初的 V 代码把动态数组当作队列使用，并且在循环里反复删除第一个元素：

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

这段代码的问题在于：连续动态数组并不适合做“从头部弹出”的队列。对一个需要
保持元素顺序的动态数组来说，删除下标 `0` 通常不是 O(1) 操作。它需要把后面的
元素整体向前移动，必要时还会触发运行时的分配、复制或容量调整。第 26 题的算法
本身又要求每次 `push` 之后旋转队列，从而把新元素移动到队头，以模拟栈的 LIFO
行为。两个因素叠加后，内存和时间成本会急剧放大：

- 一个逻辑 `push` 最多会执行 `len(queue) - 1` 次队列旋转；
- 每次旋转都会调用一次 `delete(0)`；
- 每次 `delete(0)` 都可能移动大量尾部元素，并造成 allocator churn；
- 当输入规模达到几千、benchmark 又反复运行时，这会变成非常重的二次数据搬移；
- 这种搬移和分配模式不代表题目本身的算法成本，而是底层容器选型造成的额外负担。

Windows 报告的 `53.7 GB` 是虚拟内存/提交量一类指标，不等价于进程真正持有并
有效使用了 53.7GB 物理内存。但这仍然是严重问题：当一个进程保留或提交过大的
虚拟地址空间时，会消耗系统 commit limit 或 pagefile，最终可能让系统报低虚拟
内存，甚至影响桌面响应。失败时 `raw_v.csv` 只留下半截结果，位置也正好停在这
一段 benchmark 附近。后来直接复现时，V 运行时给出的错误是：

```text
V panic: memory allocation failure
```

Go 最初没有以同样方式爆掉，是因为旧 Go 代码的头部弹出写法是切片前移：

```go
s.q = s.q[1:]
```

这也不是完美的长期队列实现，因为它可能保留底层数组；但它不会像 V 版
`delete(0)` 那样在每次头删时直接搬移动数组内容。为了让两种语言的对比更公平，
并且彻底消除这个实现伪影，当前 Go 和 V 两份代码都改成了显式环形队列。当前 V
实现会预先分配有界缓冲区，并通过 `head` 和 `size` 移动逻辑队头，不再删除数组
头部元素：

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

修复后，同一套正式实验可以完整跑完，最终得到 `6000` 条原始记录、`0` 条 0 耗时
计时记录、`0` 个 checksum 不一致项。除了改代码，还加了运行层面的保护措施：

- `scripts/run_limited.ps1` 会以 Idle 优先级启动 benchmark 和编译子进程；
- `-CpuCores 1` 把 CPU affinity 限制到单核，宁愿慢也尽量不抢占电脑资源；
- `-MemoryLimitMB` 通过 Windows Job Object 设置内存上限；
- `scripts/run_bench.ps1` 会检查 native 进程退出码和 CSV 期望行数，benchmark
  崩溃时不会再静默留下半有效结果。

如果要重新跑实验，请先执行 `.\scripts\build.ps1`。如果误用了修复前留下的旧
`bin/ds50_v.exe`，即使源码已经改好，仍然可能复现这次虚拟内存暴涨问题。

## 输出文件

- `data/raw_results.csv`：逐 trial 原始记录，包含自适应计时的 `iterations`
- `data/summary.csv`：Julia 统计汇总
- `data/comparison.csv`：按题目和输入规模对比 Go/V 中位数
- `data/problem_summary.csv`、`data/category_summary.csv`、`data/size_summary.csv`：几何均值加速比汇总
- `figures/*.svg`：Julia 生成的图表
- `output/pdf/v_vs_go_ds50_acm.en.pdf`：英文报告
- `output/pdf/v_vs_go_ds50_acm.zh-CN.pdf`：中文报告
