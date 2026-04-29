using Printf
using Statistics

const ROOT = normpath(joinpath(@__DIR__, ".."))
const DATA_DIR = joinpath(ROOT, "data")
const FIG_DIR = joinpath(ROOT, "figures")

mkpath(DATA_DIR)
mkpath(FIG_DIR)

struct BenchRecord
    language::String
    problem_id::Int
    category::String
    title::String
    core::String
    input_size::Int
    trial::Int
    elapsed_ns::Float64
    checksum::String
end

struct SummaryRecord
    language::String
    problem_id::Int
    category::String
    title::String
    core::String
    input_size::Int
    trials::Int
    median_ns::Float64
    mean_ns::Float64
    min_ns::Float64
    max_ns::Float64
    checksum::String
end

function parse_csv_line(line::String)
    fields = String[]
    buf = IOBuffer()
    inquote = false
    i = firstindex(line)
    while i <= lastindex(line)
        ch = line[i]
        if inquote
            if ch == '"'
                nexti = nextind(line, i)
                if nexti <= lastindex(line) && line[nexti] == '"'
                    print(buf, '"')
                    i = nexti
                else
                    inquote = false
                end
            else
                print(buf, ch)
            end
        else
            if ch == '"'
                inquote = true
            elseif ch == ','
                push!(fields, String(take!(buf)))
            else
                print(buf, ch)
            end
        end
        i = nextind(line, i)
    end
    push!(fields, String(take!(buf)))
    return fields
end

function read_records(path::String)
    lines = filter(!isempty, readlines(path))
    isempty(lines) && error("empty CSV: $path")
    header = parse_csv_line(lines[1])
    idx = Dict(name => i for (i, name) in enumerate(header))
    records = BenchRecord[]
    for line in lines[2:end]
        f = parse_csv_line(line)
        push!(records, BenchRecord(
            f[idx["language"]],
            parse(Int, f[idx["problem_id"]]),
            f[idx["category"]],
            f[idx["title"]],
            f[idx["core"]],
            parse(Int, f[idx["input_size"]]),
            parse(Int, f[idx["trial"]]),
            parse(Float64, f[idx["elapsed_ns"]]),
            f[idx["checksum"]],
        ))
    end
    return records
end

function csv_value(x)
    s = string(x)
    if occursin(",", s) || occursin("\"", s) || occursin("\n", s)
        return "\"" * replace(s, "\"" => "\"\"") * "\""
    end
    return s
end

function write_csv(path::String, header, rows)
    open(path, "w") do io
        println(io, join(csv_value.(header), ","))
        for row in rows
            println(io, join(csv_value.(row), ","))
        end
    end
end

fmt_num(x) = isfinite(x) ? @sprintf("%.6f", x) : ""
fmt_ratio(x) = isfinite(x) ? @sprintf("%.6f", x) : ""

function xml_escape(s::String)
    return replace(s, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")
end

function speedup_text(ratio::Float64)
    if !isfinite(ratio)
        return "n/a"
    elseif ratio >= 1.0
        return @sprintf("%.2fx Go", ratio)
    else
        return @sprintf("%.2fx V", 1.0 / ratio)
    end
end

function geomean_ratio(values)
    valid = [v for v in values if isfinite(v) && v > 0]
    isempty(valid) && return NaN
    return exp(mean(log.(valid)))
end

function write_speedup_svg(path::String, items, title::String)
    rows = [(String(label), Float64(ratio)) for (label, ratio) in items if isfinite(ratio) && ratio > 0]
    height = max(220, 70 + 28 * length(rows))
    width = 980
    label_w = 285
    chart_x = label_w + 20
    chart_w = width - chart_x - 120
    center = chart_x + chart_w / 2
    half = chart_w / 2
    maxabs = maximum([0.25; abs.(log2.([ratio for (_, ratio) in rows]))])

    open(path, "w") do io
        println(io, """<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">""")
        println(io, """<rect width="100%" height="100%" fill="#ffffff"/>""")
        println(io, """<text x="24" y="34" font-family="Arial, sans-serif" font-size="20" font-weight="700" fill="#222">$(xml_escape(title))</text>""")
        println(io, """<text x="$chart_x" y="58" font-family="Arial, sans-serif" font-size="12" fill="#555">left: V faster, right: Go faster (log2 scale)</text>""")
        println(io, """<line x1="$center" y1="70" x2="$center" y2="$(height - 28)" stroke="#555" stroke-width="1"/>""")
        println(io, """<text x="$(center + 5)" y="68" font-family="Arial, sans-serif" font-size="11" fill="#555">1.00x</text>""")

        for (i, (label, ratio)) in enumerate(rows)
            y = 82 + (i - 1) * 28
            value = log2(ratio)
            bar = abs(value) / maxabs * half
            if value >= 0
                x = center
                color = "#2b6cb0"
            else
                x = center - bar
                color = "#c05621"
            end
            println(io, """<text x="24" y="$(y + 12)" font-family="Arial, sans-serif" font-size="12" fill="#222">$(xml_escape(label))</text>""")
            println(io, """<rect x="$x" y="$y" width="$bar" height="16" rx="2" fill="$color"/>""")
            println(io, """<text x="$(chart_x + chart_w + 12)" y="$(y + 12)" font-family="Arial, sans-serif" font-size="12" fill="#222">$(speedup_text(ratio))</text>""")
        end
        println(io, "</svg>")
    end
end

raw_path = joinpath(DATA_DIR, "raw_results.csv")
records = read_records(raw_path)

groups = Dict{Tuple{String, Int, Int}, Vector{BenchRecord}}()
for r in records
    key = (r.language, r.problem_id, r.input_size)
    push!(get!(groups, key, BenchRecord[]), r)
end

summary = SummaryRecord[]
for key in sort(collect(keys(groups)); by = x -> (x[2], x[3], x[1]))
    rs = groups[key]
    elapsed = [r.elapsed_ns for r in rs]
    r0 = rs[1]
    checksums = unique(r.checksum for r in rs)
    checksum = length(checksums) == 1 ? checksums[1] : join(checksums, "|")
    push!(summary, SummaryRecord(
        r0.language, r0.problem_id, r0.category, r0.title, r0.core, r0.input_size,
        length(rs), median(elapsed), mean(elapsed), minimum(elapsed), maximum(elapsed), checksum,
    ))
end

write_csv(joinpath(DATA_DIR, "summary.csv"),
    ["language", "problem_id", "category", "title", "core", "input_size", "trials", "median_ns", "mean_ns", "min_ns", "max_ns", "checksum"],
    ([s.language, s.problem_id, s.category, s.title, s.core, s.input_size, s.trials,
      fmt_num(s.median_ns), fmt_num(s.mean_ns), fmt_num(s.min_ns), fmt_num(s.max_ns), s.checksum] for s in summary))

by_lang_problem_size = Dict((s.language, s.problem_id, s.input_size) => s for s in summary)
problem_sizes = sort(unique((s.problem_id, s.input_size) for s in summary))

comparison_rows = []
ratios_by_problem = Dict{Int, Vector{Float64}}()
ratios_by_category = Dict{String, Vector{Float64}}()
ratios_by_size = Dict{Int, Vector{Float64}}()
titles = Dict{Int, String}()
categories = Dict{Int, String}()
go_wins = 0
v_wins = 0
ties = 0
checksum_mismatches = 0

for (pid, size) in problem_sizes
    global go_wins, v_wins, ties, checksum_mismatches
    go_key = ("go", pid, size)
    v_key = ("v", pid, size)
    if haskey(by_lang_problem_size, go_key) && haskey(by_lang_problem_size, v_key)
        go = by_lang_problem_size[go_key]
        v = by_lang_problem_size[v_key]
        ratio = go.median_ns > 0 && v.median_ns > 0 ? v.median_ns / go.median_ns : NaN
        checksum_match = go.checksum == v.checksum
        checksum_mismatches += checksum_match ? 0 : 1
        faster = "tie"
        if isfinite(ratio)
            if ratio > 1.02
                faster = "go"
                go_wins += 1
            elseif ratio < 0.98
                faster = "v"
                v_wins += 1
            else
                ties += 1
            end
            push!(get!(ratios_by_problem, pid, Float64[]), ratio)
            push!(get!(ratios_by_category, go.category, Float64[]), ratio)
            push!(get!(ratios_by_size, size, Float64[]), ratio)
        else
            ties += 1
        end
        titles[pid] = go.title
        categories[pid] = go.category
        push!(comparison_rows, [pid, go.category, go.title, size, fmt_num(go.median_ns), fmt_num(v.median_ns),
            fmt_ratio(ratio), faster, checksum_match])
    end
end

write_csv(joinpath(DATA_DIR, "comparison.csv"),
    ["problem_id", "category", "title", "input_size", "go_median_ns", "v_median_ns", "go_speedup_over_v", "faster", "checksum_match"],
    comparison_rows)

problem_rows = []
for pid in sort(collect(keys(ratios_by_problem)))
    ratio = geomean_ratio(ratios_by_problem[pid])
    push!(problem_rows, [pid, categories[pid], titles[pid], fmt_ratio(ratio), speedup_text(ratio)])
end
write_csv(joinpath(DATA_DIR, "problem_summary.csv"),
    ["problem_id", "category", "title", "go_speedup_over_v_geomean", "winner"],
    problem_rows)

category_rows = []
for cat in sort(collect(keys(ratios_by_category)))
    ratio = geomean_ratio(ratios_by_category[cat])
    push!(category_rows, [cat, length(ratios_by_category[cat]), fmt_ratio(ratio), speedup_text(ratio)])
end
write_csv(joinpath(DATA_DIR, "category_summary.csv"),
    ["category", "measurements", "go_speedup_over_v_geomean", "winner"],
    category_rows)

size_rows = []
for size in sort(collect(keys(ratios_by_size)))
    ratio = geomean_ratio(ratios_by_size[size])
    push!(size_rows, [size, length(ratios_by_size[size]), fmt_ratio(ratio), speedup_text(ratio)])
end
write_csv(joinpath(DATA_DIR, "size_summary.csv"),
    ["input_size", "measurements", "go_speedup_over_v_geomean", "winner"],
    size_rows)

overall_ratio = geomean_ratio(vcat(values(ratios_by_problem)...))
open(joinpath(DATA_DIR, "overall_summary.txt"), "w") do io
    println(io, "records=$(length(records))")
    println(io, "summary_rows=$(length(summary))")
    println(io, "comparison_rows=$(length(comparison_rows))")
    println(io, "go_speedup_over_v_geomean=$(fmt_ratio(overall_ratio))")
    println(io, "overall_winner=$(speedup_text(overall_ratio))")
    println(io, "go_wins=$go_wins")
    println(io, "v_wins=$v_wins")
    println(io, "ties=$ties")
    println(io, "checksum_mismatches=$checksum_mismatches")
end

category_items = sort([(row[1], parse(Float64, row[3])) for row in category_rows], by = x -> x[2], rev = true)
problem_items = sort([("$(row[1]) $(row[3])", parse(Float64, row[4])) for row in problem_rows], by = x -> x[2], rev = true)
size_items = sort([("n=$(row[1])", parse(Float64, row[3])) for row in size_rows], by = x -> x[1])

write_speedup_svg(joinpath(FIG_DIR, "category_speedup.svg"), category_items, "Geomean Speedup by Category")
write_speedup_svg(joinpath(FIG_DIR, "problem_speedup.svg"), problem_items, "Geomean Speedup by Problem")
write_speedup_svg(joinpath(FIG_DIR, "size_speedup.svg"), size_items, "Geomean Speedup by Input Size")

println("Wrote:")
println("  $(joinpath(DATA_DIR, "summary.csv"))")
println("  $(joinpath(DATA_DIR, "comparison.csv"))")
println("  $(joinpath(DATA_DIR, "problem_summary.csv"))")
println("  $(joinpath(DATA_DIR, "category_summary.csv"))")
println("  $(joinpath(DATA_DIR, "size_summary.csv"))")
println("  $(joinpath(DATA_DIR, "overall_summary.txt"))")
println("  $(joinpath(FIG_DIR, "category_speedup.svg"))")
println("  $(joinpath(FIG_DIR, "problem_speedup.svg"))")
println("  $(joinpath(FIG_DIR, "size_speedup.svg"))")
