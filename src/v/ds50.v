module main

import os
import time

struct Problem {
	id       int
	category string
	title    string
	core     string
}

fn imin(a int, b int) int {
	return if a < b { a } else { b }
}

fn imax(a int, b int) int {
	return if a > b { a } else { b }
}

fn iabs(a int) int {
	return if a < 0 { -a } else { a }
}

fn int_sqrt(n int) int {
	mut x := 0
	for (x + 1) * (x + 1) <= n {
		x++
	}
	return x
}

fn checksum(xs []int) i64 {
	mut h := i64(2166136261)
	for x in xs {
		h = h ^ (i64(x) + i64(0x9e3779b9) + (h << 6) + (h >> 2))
	}
	return if h < 0 { -h } else { h }
}

fn make_ints(n int, salt int) []int {
	mut xs := []int{len: n}
	mut x := u32(0x9e3779b9) ^ (u32(salt) * u32(2654435761))
	for i in 0 .. n {
		x = x ^ (x << 13)
		x = x ^ (x >> 17)
		x = x ^ (x << 5)
		xs[i] = int(x % u32(20001)) - 10000
	}
	return xs
}

fn make_positive(n int, salt int, modulo int) []int {
	mut xs := []int{len: n}
	mut x := u32(0x85ebca6b) ^ (u32(salt) * u32(2246822519))
	for i in 0 .. n {
		x = x * u32(1664525) + u32(1013904223)
		xs[i] = int(x % u32(modulo)) + 1
	}
	return xs
}

fn make_lower_string(n int, salt int) string {
	mut b := []u8{len: n}
	mut x := u32(0x27d4eb2d) ^ (u32(salt) * u32(3266489917))
	for i in 0 .. n {
		x = x * u32(1103515245) + u32(12345)
		b[i] = u8(`a`) + u8(x % u32(26))
	}
	return b.bytestr()
}

fn p001_binary_search(n int) i64 {
	mut nums := []int{len: n}
	for i in 0 .. n {
		nums[i] = i * 2 + 3
	}
	mut total := 0
	for q in 0 .. 32 {
		target := ((q * 7919 + n / 2) % n) * 2 + 3
		mut l := 0
		mut r := nums.len - 1
		mut ans := -1
		for l <= r {
			m := l + (r - l) / 2
			if nums[m] == target {
				ans = m
				break
			}
			if nums[m] < target {
				l = m + 1
			} else {
				r = m - 1
			}
		}
		total += ans
	}
	return i64(total)
}

fn p002_remove_element(n int) i64 {
	mut nums := make_positive(n, 2, 17)
	val := 7
	mut k := 0
	for x in nums {
		if x != val {
			nums[k] = x
			k++
		}
	}
	return i64(k) + checksum(nums[..k])
}

fn p003_sorted_squares(n int) i64 {
	mut nums := make_ints(n, 3)
	nums.sort()
	mut ans := []int{len: n}
	mut l := 0
	mut r := n - 1
	mut pos := n - 1
	for l <= r {
		a := nums[l] * nums[l]
		b := nums[r] * nums[r]
		if a > b {
			ans[pos] = a
			l++
		} else {
			ans[pos] = b
			r--
		}
		pos--
	}
	return checksum(ans)
}

fn p004_min_sub_array_len(n int) i64 {
	nums := make_positive(n, 4, 20)
	target := n * 4
	mut sum := 0
	mut left := 0
	mut best := n + 1
	for right, x in nums {
		sum += x
		for sum >= target {
			best = imin(best, right - left + 1)
			sum -= nums[left]
			left++
		}
	}
	return if best == n + 1 { i64(0) } else { i64(best) }
}

fn p005_spiral_matrix(n int) i64 {
	m := imin(96, imax(4, int_sqrt(n)))
	mut mat := []int{len: m * m}
	mut top := 0
	mut bottom := m - 1
	mut left := 0
	mut right := m - 1
	mut v := 1
	for top <= bottom && left <= right {
		for j in left .. right + 1 {
			mat[top * m + j] = v
			v++
		}
		top++
		for i in top .. bottom + 1 {
			mat[i * m + right] = v
			v++
		}
		right--
		if top <= bottom {
			for j := right; j >= left; j-- {
				mat[bottom * m + j] = v
				v++
			}
			bottom--
		}
		if left <= right {
			for i := bottom; i >= top; i-- {
				mat[i * m + left] = v
				v++
			}
			left++
		}
	}
	return checksum(mat)
}

fn p006_max_sub_array(n int) i64 {
	nums := make_ints(n, 6)
	mut best := nums[0]
	mut cur := nums[0]
	for i in 1 .. n {
		cur = imax(nums[i], cur + nums[i])
		best = imax(best, cur)
	}
	return i64(best)
}

struct Interval {
	l int
	r int
}

fn p007_merge_intervals(n int) i64 {
	mut ints := []Interval{len: n}
	for i in 0 .. n {
		a := (i * 37 + 11) % (n + 101)
		ints[i] = Interval{a, a + (i * 13) % 31 + 1}
	}
	ints.sort(a.l < b.l)
	mut merged := []Interval{cap: n}
	for inx in ints {
		if merged.len == 0 || merged[merged.len - 1].r < inx.l {
			merged << inx
		} else if inx.r > merged[merged.len - 1].r {
			merged[merged.len - 1] = Interval{merged[merged.len - 1].l, inx.r}
		}
	}
	mut total := i64(merged.len)
	for inx in merged {
		total += i64(inx.l * 31 + inx.r)
	}
	return total
}

fn p008_product_except_self(n int) i64 {
	nums := make_positive(n, 8, 9)
	mut ans := []int{len: n}
	mut left := 1
	for i in 0 .. n {
		ans[i] = left
		left = int((i64(left) * i64(nums[i])) % i64(1000000007))
	}
	mut right := 1
	for i := n - 1; i >= 0; i-- {
		ans[i] = int((i64(ans[i]) * i64(right)) % i64(1000000007))
		right = int((i64(right) * i64(nums[i])) % i64(1000000007))
	}
	return checksum(ans)
}

fn p009_two_sum(n int) i64 {
	mut nums := make_ints(n, 9)
	if n > 3 {
		nums[n / 3] = 123456
		nums[2 * n / 3] = -123000
	}
	target := 456
	mut seen := map[int]int{}
	for i, x in nums {
		key := target - x
		if key in seen {
			return i64(i + seen[key] * 31)
		}
		seen[x] = i
	}
	return -1
}

fn p010_is_anagram(n int) i64 {
	s := make_lower_string(n, 10)
	mut b := s.bytes()
	mut i := 0
	mut j := b.len - 1
	for i < j {
		b[i], b[j] = b[j], b[i]
		i++
		j--
	}
	mut cnt := []int{len: 26}
	for k in 0 .. s.len {
		cnt[int(s[k] - `a`)]++
		cnt[int(b[k] - `a`)]--
	}
	for c in cnt {
		if c != 0 {
			return 0
		}
	}
	return 1
}

fn anagram_key(w string) string {
	mut cnt := []int{len: 26}
	for i in 0 .. w.len {
		cnt[int(w[i] - `a`)]++
	}
	return cnt.str()
}

fn p011_group_anagrams(n int) i64 {
	mut groups := map[string]int{}
	for i in 0 .. n {
		mut base := make_lower_string(7 + (i % 5), 110 + i % 17).bytes()
		base.sort()
		if i % 3 == 0 {
			mut l := 0
			mut r := base.len - 1
			for l < r {
				base[l], base[r] = base[r], base[l]
				l++
				r--
			}
		}
		key := anagram_key(base.bytestr())
		groups[key]++
	}
	mut total := i64(groups.len)
	for _, c in groups {
		total += i64(c * 17)
	}
	return total
}

fn p012_four_sum_count(n int) i64 {
	m := imin(360, imax(8, n / 8))
	a := make_ints(m, 1201)
	b := make_ints(m, 1202)
	c := make_ints(m, 1203)
	d := make_ints(m, 1204)
	mut cnt := map[int]int{}
	for x in a {
		for y in b {
			cnt[x + y]++
		}
	}
	mut ans := 0
	for x in c {
		for y in d {
			ans += cnt[-x - y]
		}
	}
	return i64(ans + cnt.len)
}

fn p013_three_sum(n int) i64 {
	m := imin(900, imax(12, n / 4))
	mut nums := make_ints(m, 13)
	nums.sort()
	mut ans := 0
	for i in 0 .. m {
		if i > 0 && nums[i] == nums[i - 1] {
			continue
		}
		mut l := i + 1
		mut r := m - 1
		for l < r {
			s := nums[i] + nums[l] + nums[r]
			if s == 0 {
				ans++
				l++
				r--
				for l < r && nums[l] == nums[l - 1] {
					l++
				}
				for l < r && nums[r] == nums[r + 1] {
					r--
				}
			} else if s < 0 {
				l++
			} else {
				r--
			}
		}
	}
	return i64(ans)
}

fn p014_longest_substring(n int) i64 {
	s := make_lower_string(n, 14)
	mut last := []int{len: 256, init: -1}
	mut left := 0
	mut best := 0
	for i in 0 .. s.len {
		ch := int(s[i])
		if last[ch] >= left {
			left = last[ch] + 1
		}
		last[ch] = i
		best = imax(best, i - left + 1)
	}
	return i64(best)
}

fn p015_min_window(n int) i64 {
	s := make_lower_string(n, 15) + 'algorithm'
	t := 'algo'
	mut need := []int{len: 256}
	mut missing := t.len
	for i in 0 .. t.len {
		need[int(t[i])]++
	}
	mut left := 0
	mut best := s.len + 1
	for right in 0 .. s.len {
		if need[int(s[right])] > 0 {
			missing--
		}
		need[int(s[right])]--
		for missing == 0 {
			best = imin(best, right - left + 1)
			need[int(s[left])]++
			if need[int(s[left])] > 0 {
				missing++
			}
			left++
		}
	}
	return if best == s.len + 1 { i64(0) } else { i64(best) }
}

fn p016_find_anagrams(n int) i64 {
	s := make_lower_string(n, 16) + 'abcabc'
	p := 'abc'
	mut need := []int{len: 26}
	mut win := []int{len: 26}
	for i in 0 .. p.len {
		need[int(p[i] - `a`)]++
	}
	mut ans := 0
	for i in 0 .. s.len {
		win[int(s[i] - `a`)]++
		if i >= p.len {
			win[int(s[i - p.len] - `a`)]--
		}
		if i >= p.len - 1 && win == need {
			ans += i - p.len + 1
		}
	}
	return i64(ans)
}

struct MyLinkedList {
mut:
	vals []int
	next []int
	head int
	size int
}

fn new_linked_list(capacity int) MyLinkedList {
	return MyLinkedList{
		vals: []int{cap: capacity}
		next: []int{cap: capacity}
		head: -1
	}
}

fn (mut l MyLinkedList) new_node(v int, nxt int) int {
	idx := l.vals.len
	l.vals << v
	l.next << nxt
	return idx
}

fn (mut l MyLinkedList) add_at_head(v int) {
	l.head = l.new_node(v, l.head)
	l.size++
}

fn (mut l MyLinkedList) add_at_tail(v int) {
	node := l.new_node(v, -1)
	if l.head == -1 {
		l.head = node
	} else {
		mut cur := l.head
		for l.next[cur] != -1 {
			cur = l.next[cur]
		}
		l.next[cur] = node
	}
	l.size++
}

fn (mut l MyLinkedList) add_at_index(index int, v int) {
	if index < 0 || index > l.size {
		return
	}
	if index == 0 {
		l.add_at_head(v)
		return
	}
	mut prev := l.head
	for _ in 0 .. index - 1 {
		prev = l.next[prev]
	}
	l.next[prev] = l.new_node(v, l.next[prev])
	l.size++
}

fn (mut l MyLinkedList) delete_at_index(index int) {
	if index < 0 || index >= l.size || l.head == -1 {
		return
	}
	if index == 0 {
		l.head = l.next[l.head]
		l.size--
		return
	}
	mut prev := l.head
	for _ in 0 .. index - 1 {
		prev = l.next[prev]
	}
	l.next[prev] = l.next[l.next[prev]]
	l.size--
}

fn (l MyLinkedList) get(index int) int {
	if index < 0 || index >= l.size {
		return -1
	}
	mut cur := l.head
	for _ in 0 .. index {
		cur = l.next[cur]
	}
	return l.vals[cur]
}

fn p017_design_linked_list(n int) i64 {
	m := imin(2400, n)
	mut list := new_linked_list(m * 2)
	mut total := 0
	for i in 0 .. m {
		if i % 3 == 0 {
			list.add_at_head(i)
		} else {
			list.add_at_tail(i)
		}
		if i % 7 == 0 {
			list.add_at_index(list.size / 2, i * 2)
		}
		if i % 11 == 0 && list.size > 0 {
			list.delete_at_index(list.size / 3)
		}
		if list.size > 0 {
			total += list.get((i * 17) % list.size)
		}
	}
	return i64(total + list.size)
}

fn make_list_pool(n int) ([]int, []int, int) {
	mut vals := []int{len: n}
	mut next := []int{len: n}
	for i in 0 .. n {
		vals[i] = i + 1
		next[i] = i + 1
	}
	if n > 0 {
		next[n - 1] = -1
		return vals, next, 0
	}
	return vals, next, -1
}

fn list_checksum(vals []int, next []int, head int, limit int) i64 {
	mut total := i64(0)
	mut cur := head
	mut steps := 0
	for cur != -1 && steps < limit {
		total = total * 131 + i64(vals[cur])
		cur = next[cur]
		steps++
	}
	return total + i64(steps)
}

fn p018_reverse_list(n int) i64 {
	vals, mut next, head := make_list_pool(n)
	mut prev := -1
	mut cur := head
	for cur != -1 {
		nxt := next[cur]
		next[cur] = prev
		prev = cur
		cur = nxt
	}
	return list_checksum(vals, next, prev, n)
}

fn p019_reverse_between(n int) i64 {
	mut vals, mut next, head := make_list_pool(n)
	left := n / 4 + 1
	right := 3 * n / 4
	dummy := vals.len
	vals << 0
	next << head
	mut prev := dummy
	for _ in 1 .. left {
		prev = next[prev]
	}
	cur := next[prev]
	for _ in 0 .. right - left {
		move := next[cur]
		next[cur] = next[move]
		next[move] = next[prev]
		next[prev] = move
	}
	return list_checksum(vals, next, next[dummy], n)
}

fn p020_swap_pairs(n int) i64 {
	mut vals, mut next, head := make_list_pool(n)
	dummy := vals.len
	vals << 0
	next << head
	mut prev := dummy
	for next[prev] != -1 && next[next[prev]] != -1 {
		a := next[prev]
		b := next[a]
		next[a] = next[b]
		next[b] = a
		next[prev] = b
		prev = a
	}
	return list_checksum(vals, next, next[dummy], n)
}

fn p021_remove_nth_from_end(n int) i64 {
	mut vals, mut next, head := make_list_pool(n)
	k := imax(1, n / 3)
	dummy := vals.len
	vals << 0
	next << head
	mut fast := dummy
	for _ in 0 .. k {
		fast = next[fast]
	}
	mut slow := dummy
	for next[fast] != -1 {
		fast = next[fast]
		slow = next[slow]
	}
	next[slow] = next[next[slow]]
	return list_checksum(vals, next, next[dummy], n - 1)
}

fn p022_intersection_list(n int) i64 {
	common := n / 3
	a_len := n / 2
	b_len := n / 2 + n / 7
	mut a := a_len
	mut b := b_len
	for a != b {
		a = if a == 0 { b_len + common } else { a - 1 }
		b = if b == 0 { a_len + common } else { b - 1 }
	}
	return i64(a + common)
}

fn p023_detect_cycle(n int) i64 {
	mut next := []int{len: n}
	entry := n / 3
	for i in 0 .. n - 1 {
		next[i] = i + 1
	}
	next[n - 1] = entry
	mut slow := 0
	mut fast := 0
	for {
		slow = next[slow]
		fast = next[next[fast]]
		if slow == fast {
			break
		}
	}
	fast = 0
	for slow != fast {
		slow = next[slow]
		fast = next[fast]
	}
	return i64(slow)
}

fn p024_valid_parentheses(n int) i64 {
	pairs := [`(`, `[`, `{`]
	mut s := []u8{cap: n * 2 + 3}
	for i in 0 .. n {
		s << pairs[i % 3]
	}
	for i := n - 1; i >= 0; i-- {
		if pairs[i % 3] == `(` {
			s << `)`
		} else if pairs[i % 3] == `[` {
			s << `]`
		} else {
			s << `}`
		}
	}
	mut stack := []u8{cap: s.len}
	for ch in s {
		if ch == `(` || ch == `[` || ch == `{` {
			stack << ch
		} else {
			if stack.len == 0 {
				return 0
			}
			top := stack.pop()
			if (ch == `)` && top != `(`) || (ch == `]` && top != `[`) || (ch == `}` && top != `{`) {
				return 0
			}
		}
	}
	return if stack.len == 0 { i64(1) } else { i64(0) }
}

struct MyQueue {
mut:
	input  []int
	output []int
}

fn (mut q MyQueue) push(x int) {
	q.input << x
}

fn (mut q MyQueue) pop() int {
	if q.output.len == 0 {
		for q.input.len > 0 {
			q.output << q.input.pop()
		}
	}
	return q.output.pop()
}

fn p025_queue_using_stacks(n int) i64 {
	mut q := MyQueue{}
	mut total := 0
	for i in 0 .. n {
		q.push(i)
		if i % 3 == 0 {
			total += q.pop()
		}
	}
	for q.input.len + q.output.len > 0 {
		total += q.pop()
	}
	return i64(total)
}

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

fn p026_stack_using_queues(n int) i64 {
	m := imin(6000, n)
	mut st := new_queue_stack(m + 1)
	mut total := 0
	for i in 0 .. m {
		st.push(i)
		if i % 4 == 0 {
			total += st.pop()
		}
	}
	for st.size > 0 {
		total += st.pop()
	}
	return i64(total)
}

struct MinStack {
mut:
	data []int
	mins []int
}

fn (mut s MinStack) push(x int) {
	s.data << x
	if s.mins.len == 0 || x <= s.mins[s.mins.len - 1] {
		s.mins << x
	}
}

fn (mut s MinStack) pop() int {
	x := s.data.pop()
	if x == s.mins[s.mins.len - 1] {
		s.mins.pop()
	}
	return x
}

fn (s MinStack) min() int {
	return s.mins[s.mins.len - 1]
}

fn p027_min_stack(n int) i64 {
	xs := make_ints(n, 27)
	mut st := MinStack{}
	mut total := 0
	for i, x in xs {
		st.push(x)
		if i % 5 == 0 {
			total += st.min()
		}
		if i % 7 == 0 && st.data.len > 0 {
			total += st.pop()
		}
	}
	return i64(total)
}

fn p028_eval_rpn(n int) i64 {
	m := imax(4, n / 8)
	mut st := []int{cap: m}
	for i in 1 .. m + 1 {
		st << (i % 97 + 1)
		if i % 3 == 0 {
			b := st.pop()
			a := st.pop()
			st << ((a + b) % 1000003)
		}
		if i % 11 == 0 && st.len >= 2 {
			b := st.pop()
			a := st.pop()
			st << ((a * b + 7) % 1000003)
		}
	}
	return checksum(st)
}

fn p029_sliding_window_max(n int) i64 {
	nums := make_ints(n, 29)
	k := imax(2, int_sqrt(n))
	mut deq := []int{cap: n}
	mut head := 0
	mut out := []int{cap: n}
	for i, x in nums {
		for head < deq.len && deq[head] <= i - k {
			head++
		}
		for head < deq.len && nums[deq[deq.len - 1]] <= x {
			deq.pop()
		}
		deq << i
		if i >= k - 1 {
			out << nums[deq[head]]
		}
	}
	return checksum(out)
}

fn p030_daily_temperatures(n int) i64 {
	mut temps := make_positive(n, 30, 70)
	for i in 0 .. temps.len {
		temps[i] += 30
	}
	mut ans := []int{len: n}
	mut st := []int{cap: n}
	for i, x in temps {
		for st.len > 0 && x > temps[st[st.len - 1]] {
			j := st.pop()
			ans[j] = i - j
		}
		st << i
	}
	return checksum(ans)
}

fn p031_largest_rectangle(n int) i64 {
	h := make_positive(n, 31, 1000)
	mut st := [-1]
	mut best := 0
	for i in 0 .. n + 1 {
		cur := if i < n { h[i] } else { 0 }
		for st[st.len - 1] != -1 && cur < h[st[st.len - 1]] {
			idx := st.pop()
			best = imax(best, h[idx] * (i - st[st.len - 1] - 1))
		}
		st << i
	}
	return i64(best)
}

struct IntHeap {
mut:
	data []int
}

fn (mut h IntHeap) push(x int) {
	h.data << x
	mut i := h.data.len - 1
	for i > 0 {
		p := (i - 1) / 2
		if h.data[p] <= h.data[i] {
			break
		}
		h.data[p], h.data[i] = h.data[i], h.data[p]
		i = p
	}
}

fn (mut h IntHeap) pop() int {
	root := h.data[0]
	last := h.data.pop()
	if h.data.len > 0 {
		h.data[0] = last
		mut i := 0
		for {
			l := i * 2 + 1
			r := l + 1
			mut small := i
			if l < h.data.len && h.data[l] < h.data[small] {
				small = l
			}
			if r < h.data.len && h.data[r] < h.data[small] {
				small = r
			}
			if small == i {
				break
			}
			h.data[i], h.data[small] = h.data[small], h.data[i]
			i = small
		}
	}
	return root
}

fn (h IntHeap) size() int {
	return h.data.len
}

fn (h IntHeap) peek() int {
	return h.data[0]
}

fn p032_kth_largest(n int) i64 {
	nums := make_ints(n, 32)
	k := imax(1, n / 10)
	mut h := IntHeap{}
	for x in nums {
		h.push(x)
		if h.size() > k {
			h.pop()
		}
	}
	return i64(h.peek())
}

fn p033_top_k_frequent(n int) i64 {
	nums := make_positive(n, 33, imax(8, n / 8))
	mut freq := map[int]int{}
	for x in nums {
		freq[x]++
	}
	k := imin(20, freq.len)
	mut h := IntHeap{}
	for val, c in freq {
		h.push(c * 100000 + val)
		if h.size() > k {
			h.pop()
		}
	}
	mut total := 0
	for h.size() > 0 {
		total += h.pop()
	}
	return i64(total)
}

struct MedianFinder {
mut:
	lo IntHeap
	hi IntHeap
}

fn (mut m MedianFinder) add(x int) {
	m.lo.push(-x)
	if m.lo.size() > 0 && m.hi.size() > 0 && -m.lo.peek() > m.hi.peek() {
		a := -m.lo.pop()
		b := m.hi.pop()
		m.lo.push(-b)
		m.hi.push(a)
	}
	if m.lo.size() > m.hi.size() + 1 {
		m.hi.push(-m.lo.pop())
	}
	if m.hi.size() > m.lo.size() {
		m.lo.push(-m.hi.pop())
	}
}

fn (m MedianFinder) median2() int {
	if m.lo.size() == m.hi.size() {
		return -m.lo.peek() + m.hi.peek()
	}
	return -2 * m.lo.peek()
}

fn p034_median_finder(n int) i64 {
	xs := make_ints(n, 34)
	mut m := MedianFinder{}
	mut total := 0
	for i, x in xs {
		m.add(x)
		if i % 17 == 0 {
			total += m.median2()
		}
	}
	return i64(total)
}

fn p035_level_order(n int) i64 {
	vals := make_positive(n, 35, 1000)
	mut total := 0
	mut q := [0]
	mut head := 0
	for head < q.len {
		i := q[head]
		head++
		if i >= n {
			continue
		}
		total += vals[i]
		q << 2 * i + 1
		q << 2 * i + 2
	}
	return i64(total)
}

fn p036_max_depth(n int) i64 {
	mut depth := 0
	mut nodes := 1
	for nodes <= n {
		depth++
		nodes <<= 1
	}
	return i64(depth)
}

fn height_balanced(n int, idx int) int {
	if idx >= n {
		return 0
	}
	l := height_balanced(n, idx * 2 + 1)
	if l == -1 {
		return -1
	}
	r := height_balanced(n, idx * 2 + 2)
	if r == -1 || iabs(l - r) > 1 {
		return -1
	}
	return imax(l, r) + 1
}

fn p037_is_balanced(n int) i64 {
	return if height_balanced(n, 0) >= 0 { i64(1) } else { i64(0) }
}

fn invert_checksum(mut vals []int, idx int) i64 {
	if idx >= vals.len {
		return 0
	}
	l := idx * 2 + 1
	r := idx * 2 + 2
	if l < vals.len && r < vals.len {
		vals[l], vals[r] = vals[r], vals[l]
	}
	return i64(vals[idx]) + 3 * invert_checksum(mut vals, l) + 5 * invert_checksum(mut vals, r)
}

fn p038_invert_tree(n int) i64 {
	mut vals := make_positive(n, 38, 1000)
	return invert_checksum(mut vals, 0)
}

fn mirror(vals []int, n int, a int, b int) bool {
	if a >= n || b >= n {
		return a >= n && b >= n
	}
	return vals[a] == vals[b] && mirror(vals, n, 2 * a + 1, 2 * b + 2)
		&& mirror(vals, n, 2 * a + 2, 2 * b + 1)
}

fn p039_symmetric_tree(n int) i64 {
	mut vals := []int{len: n}
	for i in 0 .. n {
		mut d := 0
		mut x := i + 1
		for x > 1 {
			d++
			x >>= 1
		}
		vals[i] = d
	}
	return if mirror(vals, n, 1, 2) { i64(1) } else { i64(0) }
}

fn path_sum(vals []int, idx int, target int) bool {
	if idx >= vals.len {
		return false
	}
	next_target := target - vals[idx]
	l := idx * 2 + 1
	r := idx * 2 + 2
	if l >= vals.len && r >= vals.len {
		return next_target == 0
	}
	return path_sum(vals, l, next_target) || path_sum(vals, r, next_target)
}

fn p040_path_sum(n int) i64 {
	vals := make_positive(n, 40, 13)
	mut target := 0
	mut i := 0
	for i < n {
		target += vals[i]
		i = i * 2 + 1
	}
	return if path_sum(vals, 0, target) { i64(target) } else { i64(0) }
}

fn build_pre_in(lo int, hi int, mut pre []int, mut inorder []int) {
	if lo > hi {
		return
	}
	mid := (lo + hi) / 2
	pre << mid
	build_pre_in(lo, mid - 1, mut pre, mut inorder)
	inorder << mid
	build_pre_in(mid + 1, hi, mut pre, mut inorder)
}

fn build_tree_checksum(pre []int, pl int, pr int, il int, ir int, pos map[int]int) i64 {
	if pl > pr {
		return 0
	}
	root := pre[pl]
	k := pos[root]
	left := k - il
	return i64(root) + 3 * build_tree_checksum(pre, pl + 1, pl + left, il, k - 1, pos) +
		5 * build_tree_checksum(pre, pl + left + 1, pr, k + 1, ir, pos)
}

fn p041_build_tree(n int) i64 {
	m := imin(4095, n)
	mut pre := []int{}
	mut inorder := []int{}
	build_pre_in(0, m - 1, mut pre, mut inorder)
	mut pos := map[int]int{}
	for i, v in inorder {
		pos[v] = i
	}
	return build_tree_checksum(pre, 0, pre.len - 1, 0, inorder.len - 1, pos)
}

fn p042_lowest_common_ancestor(n int) i64 {
	mut a := n * 2 / 3
	mut b := n * 3 / 4
	for a != b {
		if a > b {
			a = (a - 1) / 2
		} else {
			b = (b - 1) / 2
		}
	}
	return i64(a)
}

fn fill_bst(mut vals []int) {
	mut stack := []int{}
	mut cur := 0
	mut value := 1
	for stack.len > 0 || cur < vals.len {
		for cur < vals.len {
			stack << cur
			cur = cur * 2 + 1
		}
		cur = stack.pop()
		vals[cur] = value
		value++
		cur = cur * 2 + 2
	}
}

fn validate_bst(vals []int, idx int, lo int, hi int) bool {
	if idx >= vals.len {
		return true
	}
	v := vals[idx]
	if v <= lo || v >= hi {
		return false
	}
	return validate_bst(vals, idx * 2 + 1, lo, v) && validate_bst(vals, idx * 2 + 2, v, hi)
}

fn p043_validate_bst(n int) i64 {
	mut vals := []int{len: n}
	fill_bst(mut vals)
	return if validate_bst(vals, 0, -1, n + 2) { i64(1) } else { i64(0) }
}

fn p044_kth_smallest(n int) i64 {
	mut k := imax(1, n / 2)
	mut stack := []int{}
	mut cur := 0
	for stack.len > 0 || cur < n {
		for cur < n {
			stack << cur
			cur = cur * 2 + 1
		}
		cur = stack.pop()
		k--
		if k == 0 {
			return i64(cur)
		}
		cur = cur * 2 + 2
	}
	return -1
}

fn p045_num_islands(n int) i64 {
	side := imin(180, imax(8, int_sqrt(n)))
	mut grid := []u8{len: side * side}
	for i in 0 .. grid.len {
		if (i * 37 + i / side * 17) % 11 < 6 {
			grid[i] = 1
		}
	}
	dirs := [1, 0, -1, 0, 1]
	mut islands := 0
	mut stack := []int{cap: side * side}
	for i in 0 .. grid.len {
		if grid[i] == 0 {
			continue
		}
		islands++
		grid[i] = 0
		stack << i
		for stack.len > 0 {
			p := stack.pop()
			r := p / side
			c := p % side
			for d in 0 .. 4 {
				nr := r + dirs[d]
				nc := c + dirs[d + 1]
				if nr >= 0 && nr < side && nc >= 0 && nc < side {
					q := nr * side + nc
					if grid[q] == 1 {
						grid[q] = 0
						stack << q
					}
				}
			}
		}
	}
	return i64(islands)
}

fn make_courses(n int) (int, [][]int) {
	courses := imin(6000, imax(16, n / 2))
	mut pre := [][]int{cap: courses * 2}
	for i in 1 .. courses {
		pre << [i, (i - 1) / 2]
		if i > 3 && i % 5 == 0 {
			pre << [i, i - 3]
		}
	}
	return courses, pre
}

fn topo(courses int, pre [][]int) []int {
	mut g := [][]int{len: courses}
	mut indeg := []int{len: courses}
	for e in pre {
		to := e[0]
		from := e[1]
		g[from] << to
		indeg[to]++
	}
	mut q := []int{cap: courses}
	for i, d in indeg {
		if d == 0 {
			q << i
		}
	}
	mut order := []int{cap: courses}
	mut head := 0
	for head < q.len {
		u := q[head]
		head++
		order << u
		for v in g[u] {
			indeg[v]--
			if indeg[v] == 0 {
				q << v
			}
		}
	}
	return order
}

fn p046_course_schedule(n int) i64 {
	c, pre := make_courses(n)
	return if topo(c, pre).len == c { i64(1) } else { i64(0) }
}

fn p047_course_schedule_ii(n int) i64 {
	c, pre := make_courses(n)
	return checksum(topo(c, pre))
}

struct Dsu {
mut:
	parent []int
	rank   []int
}

fn new_dsu(n int) Dsu {
	mut p := []int{len: n + 1}
	for i in 0 .. p.len {
		p[i] = i
	}
	return Dsu{
		parent: p
		rank:   []int{len: n + 1}
	}
}

fn (mut d Dsu) find(x0 int) int {
	mut x := x0
	for d.parent[x] != x {
		d.parent[x] = d.parent[d.parent[x]]
		x = d.parent[x]
	}
	return x
}

fn (mut d Dsu) union(a int, b int) bool {
	mut ra := d.find(a)
	mut rb := d.find(b)
	if ra == rb {
		return false
	}
	if d.rank[ra] < d.rank[rb] {
		ra, rb = rb, ra
	}
	d.parent[rb] = ra
	if d.rank[ra] == d.rank[rb] {
		d.rank[ra]++
	}
	return true
}

fn p048_redundant_connection(n int) i64 {
	m := imin(10000, imax(3, n))
	mut d := new_dsu(m)
	for i in 2 .. m + 1 {
		d.union(i - 1, i)
	}
	if !d.union(1, m) {
		return i64(1 + m * 31)
	}
	return 0
}

struct TrieNode {
mut:
	child []int
	end   bool
}

fn new_trie_node() TrieNode {
	return TrieNode{
		child: []int{len: 26}
	}
}

struct Trie {
mut:
	nodes []TrieNode
}

fn new_trie() Trie {
	return Trie{
		nodes: [new_trie_node()]
	}
}

fn (mut t Trie) insert(w string) {
	mut cur := 0
	for i in 0 .. w.len {
		c := int(w[i] - `a`)
		if t.nodes[cur].child[c] == 0 {
			t.nodes << new_trie_node()
			t.nodes[cur].child[c] = t.nodes.len - 1
		}
		cur = t.nodes[cur].child[c]
	}
	t.nodes[cur].end = true
}

fn (t Trie) search(w string) bool {
	mut cur := 0
	for i in 0 .. w.len {
		c := int(w[i] - `a`)
		if t.nodes[cur].child[c] == 0 {
			return false
		}
		cur = t.nodes[cur].child[c]
	}
	return t.nodes[cur].end
}

fn p049_trie(n int) i64 {
	mut trie := new_trie()
	mut total := 0
	for i in 0 .. n {
		w := make_lower_string(6 + i % 9, 4900 + i)
		trie.insert(w)
		if i % 4 == 0 && trie.search(w) {
			total++
		}
	}
	return i64(total + trie.nodes.len)
}

struct Fenwick {
mut:
	bit []int
	arr []int
}

fn new_fenwick(xs []int) Fenwick {
	mut f := Fenwick{
		bit: []int{len: xs.len + 1}
		arr: xs.clone()
	}
	for i, x in xs {
		f.add(i + 1, x)
	}
	return f
}

fn (mut f Fenwick) add(i0 int, delta int) {
	mut i := i0
	for i < f.bit.len {
		f.bit[i] += delta
		i += i & -i
	}
}

fn (mut f Fenwick) update(i int, val int) {
	delta := val - f.arr[i]
	f.arr[i] = val
	f.add(i + 1, delta)
}

fn (f Fenwick) prefix(i0 int) int {
	mut i := i0
	mut s := 0
	for i > 0 {
		s += f.bit[i]
		i -= i & -i
	}
	return s
}

fn (f Fenwick) sum_range(l int, r int) int {
	return f.prefix(r + 1) - f.prefix(l)
}

fn p050_num_array(n int) i64 {
	xs := make_positive(n, 50, 100)
	mut f := new_fenwick(xs)
	mut total := 0
	for i in 0 .. n {
		if i % 3 == 0 {
			f.update(i, (i * 17) % 101)
		} else {
			mut l := (i * 37) % n
			mut r := (l + i % 97) % n
			if l > r {
				l, r = r, l
			}
			total += f.sum_range(l, r)
		}
	}
	return i64(total)
}

fn run_problem(id int, n int) i64 {
	return match id {
		1 { p001_binary_search(n) }
		2 { p002_remove_element(n) }
		3 { p003_sorted_squares(n) }
		4 { p004_min_sub_array_len(n) }
		5 { p005_spiral_matrix(n) }
		6 { p006_max_sub_array(n) }
		7 { p007_merge_intervals(n) }
		8 { p008_product_except_self(n) }
		9 { p009_two_sum(n) }
		10 { p010_is_anagram(n) }
		11 { p011_group_anagrams(n) }
		12 { p012_four_sum_count(n) }
		13 { p013_three_sum(n) }
		14 { p014_longest_substring(n) }
		15 { p015_min_window(n) }
		16 { p016_find_anagrams(n) }
		17 { p017_design_linked_list(n) }
		18 { p018_reverse_list(n) }
		19 { p019_reverse_between(n) }
		20 { p020_swap_pairs(n) }
		21 { p021_remove_nth_from_end(n) }
		22 { p022_intersection_list(n) }
		23 { p023_detect_cycle(n) }
		24 { p024_valid_parentheses(n) }
		25 { p025_queue_using_stacks(n) }
		26 { p026_stack_using_queues(n) }
		27 { p027_min_stack(n) }
		28 { p028_eval_rpn(n) }
		29 { p029_sliding_window_max(n) }
		30 { p030_daily_temperatures(n) }
		31 { p031_largest_rectangle(n) }
		32 { p032_kth_largest(n) }
		33 { p033_top_k_frequent(n) }
		34 { p034_median_finder(n) }
		35 { p035_level_order(n) }
		36 { p036_max_depth(n) }
		37 { p037_is_balanced(n) }
		38 { p038_invert_tree(n) }
		39 { p039_symmetric_tree(n) }
		40 { p040_path_sum(n) }
		41 { p041_build_tree(n) }
		42 { p042_lowest_common_ancestor(n) }
		43 { p043_validate_bst(n) }
		44 { p044_kth_smallest(n) }
		45 { p045_num_islands(n) }
		46 { p046_course_schedule(n) }
		47 { p047_course_schedule_ii(n) }
		48 { p048_redundant_connection(n) }
		49 { p049_trie(n) }
		50 { p050_num_array(n) }
		else { i64(0) }
	}
}

fn checksum_one(id int, n int, repeat int) i64 {
	mut total := i64(0)
	for r in 0 .. repeat {
		total = total ^ run_problem(id, n + (r % 3))
	}
	return total
}

fn run_one(id int, n int, repeat int, min_ns u64) (u64, i64, int) {
	sum := checksum_one(id, n, repeat)
	mut iterations := 0
	mut sink := i64(0)
	start := time.sys_mono_now()
	max_iterations := repeat * 1000000
	for {
		for r in 0 .. repeat {
			sink = sink ^ run_problem(id, n + ((iterations + r) % 3))
		}
		iterations += repeat
		elapsed := time.sys_mono_now() - start
		if elapsed >= min_ns || iterations >= max_iterations {
			mut avg := elapsed
			if iterations > 0 {
				avg = elapsed / u64(iterations)
			}
			if avg == 0 {
				avg = 1
			}
			return avg, sum + (sink & i64(0)), iterations
		}
	}
	return u64(1), sum + (sink & i64(0)), iterations
}

fn arg_value(name string, default string) string {
	for i in 1 .. os.args.len {
		if os.args[i] == name && i + 1 < os.args.len {
			return os.args[i + 1]
		}
		prefix := name + '='
		if os.args[i].starts_with(prefix) {
			return os.args[i][prefix.len..]
		}
	}
	return default
}

fn parse_sizes(s string) []int {
	mut sizes := []int{}
	for part in s.split(',') {
		v := part.trim_space().int()
		if v > 0 {
			sizes << v
		}
	}
	return sizes
}

fn main() {
	trials := imax(1, arg_value('-trials', '15').int())
	repeat := imax(1, arg_value('-repeat', '1').int())
	min_ms := imax(0, arg_value('-min-ms', '5').int())
	min_ns := u64(min_ms) * u64(1000000)
	sizes := parse_sizes(arg_value('-sizes', '512,2048,8192'))
	problems := [
		Problem{1, 'Array', '704 Binary Search', 'binary boundaries'},
		Problem{2, 'Array', '27 Remove Element', 'two pointers'},
		Problem{3, 'Array', '977 Squares of Sorted Array', 'two pointers'},
		Problem{4, 'Array', '209 Minimum Size Subarray Sum', 'sliding window'},
		Problem{5, 'Array/Matrix', '59 Spiral Matrix II', 'simulation'},
		Problem{6, 'Array', '53 Maximum Subarray', 'dynamic maintenance'},
		Problem{7, 'Array', '56 Merge Intervals', 'sort and merge'},
		Problem{8, 'Array', '238 Product Except Self', 'prefix suffix products'},
		Problem{9, 'Hash', '1 Two Sum', 'hash lookup'},
		Problem{10, 'Hash', '242 Valid Anagram', 'counting hash'},
		Problem{11, 'Hash', '49 Group Anagrams', 'hash key design'},
		Problem{12, 'Hash', '454 4Sum II', 'grouped hash'},
		Problem{13, 'Hash/TwoPointer', '15 3Sum', 'sort dedupe two pointers'},
		Problem{14, 'String', '3 Longest Substring', 'sliding window set'},
		Problem{15, 'String', '76 Minimum Window', 'sliding window counts'},
		Problem{16, 'String', '438 Find Anagrams', 'fixed window'},
		Problem{17, 'LinkedList', '707 Design Linked List', 'linked operations'},
		Problem{18, 'LinkedList', '206 Reverse Linked List', 'iterative reverse'},
		Problem{19, 'LinkedList', '92 Reverse Linked List II', 'local reverse'},
		Problem{20, 'LinkedList', '24 Swap Nodes in Pairs', 'pointer reconnect'},
		Problem{21, 'LinkedList', '19 Remove Nth From End', 'fast slow pointers'},
		Problem{22, 'LinkedList', '160 Intersection Linked List', 'two pointer sync'},
		Problem{23, 'LinkedList', '142 Linked List Cycle II', 'fast slow entry'},
		Problem{24, 'Stack', '20 Valid Parentheses', 'stack matching'},
		Problem{25, 'Stack/Queue', '232 Queue Using Stacks', 'two stacks'},
		Problem{26, 'Stack/Queue', '225 Stack Using Queues', 'queue rotation'},
		Problem{27, 'Stack', '155 Min Stack', 'auxiliary stack'},
		Problem{28, 'Stack', '150 Evaluate RPN', 'expression stack'},
		Problem{29, 'Queue', '239 Sliding Window Maximum', 'monotone queue'},
		Problem{30, 'MonotonicStack', '739 Daily Temperatures', 'monotone stack'},
		Problem{31, 'MonotonicStack', '84 Largest Rectangle', 'advanced monotone stack'},
		Problem{32, 'Heap', '215 Kth Largest', 'min heap'},
		Problem{33, 'Heap/Hash', '347 Top K Frequent', 'hash and heap'},
		Problem{34, 'Heap', '295 Median Finder', 'two heaps'},
		Problem{35, 'BinaryTree', '102 Level Order', 'BFS queue'},
		Problem{36, 'BinaryTree', '104 Maximum Depth', 'DFS recursion'},
		Problem{37, 'BinaryTree', '110 Balanced Binary Tree', 'bottom up recursion'},
		Problem{38, 'BinaryTree', '226 Invert Binary Tree', 'tree recursion'},
		Problem{39, 'BinaryTree', '101 Symmetric Tree', 'dual recursion'},
		Problem{40, 'BinaryTree', '112 Path Sum', 'DFS backtracking'},
		Problem{41, 'BinaryTree', '105 Build Tree', 'recursive construction'},
		Problem{42, 'BinaryTree', '236 Lowest Common Ancestor', 'postorder logic'},
		Problem{43, 'BST', '98 Validate BST', 'inorder bounds'},
		Problem{44, 'BST', '230 Kth Smallest', 'inorder traversal'},
		Problem{45, 'Graph', '200 Number of Islands', 'grid DFS'},
		Problem{46, 'Graph', '207 Course Schedule', 'topological sort'},
		Problem{47, 'Graph', '210 Course Schedule II', 'topological output'},
		Problem{48, 'UnionFind', '684 Redundant Connection', 'cycle detection'},
		Problem{49, 'Trie', '208 Implement Trie', 'prefix tree'},
		Problem{50, 'Fenwick', '307 Range Sum Query Mutable', 'point update range query'},
	]
	println('language,problem_id,category,title,core,input_size,trial,elapsed_ns,iterations,checksum')
	for p in problems {
		for n in sizes {
			for t in 0 .. trials {
				elapsed, sum, iterations := run_one(p.id, n, repeat, min_ns)
				println('v,${p.id},"${p.category}","${p.title}","${p.core}",${n},${t},${elapsed},${iterations},${sum}')
			}
		}
	}
}
