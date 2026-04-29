package main

import (
	"container/heap"
	"flag"
	"fmt"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
)

type Problem struct {
	ID       int
	Category string
	Title    string
	Core     string
	Run      func(int) int
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func abs(a int) int {
	if a < 0 {
		return -a
	}
	return a
}

func checksum(xs []int) int {
	h := 2166136261
	for _, x := range xs {
		h ^= x + 0x9e3779b9 + (h << 6) + (h >> 2)
	}
	if h < 0 {
		return -h
	}
	return h
}

func makeInts(n int, salt int) []int {
	xs := make([]int, n)
	x := uint32(0x9e3779b9 ^ uint32(salt*2654435761))
	for i := range xs {
		x ^= x << 13
		x ^= x >> 17
		x ^= x << 5
		xs[i] = int(x%20001) - 10000
	}
	return xs
}

func makePositive(n int, salt int, mod int) []int {
	xs := make([]int, n)
	x := uint32(0x85ebca6b ^ uint32(salt*2246822519))
	for i := range xs {
		x = x*1664525 + 1013904223
		xs[i] = int(x%uint32(mod)) + 1
	}
	return xs
}

func makeLowerString(n int, salt int) string {
	var b strings.Builder
	b.Grow(n)
	x := uint32(0x27d4eb2d ^ uint32(salt*3266489917))
	for i := 0; i < n; i++ {
		x = x*1103515245 + 12345
		b.WriteByte(byte('a' + x%26))
	}
	return b.String()
}

func p001BinarySearch(n int) int {
	nums := make([]int, n)
	for i := range nums {
		nums[i] = i*2 + 3
	}
	total := 0
	for q := 0; q < 32; q++ {
		target := ((q*7919+n/2)%n)*2 + 3
		l, r := 0, len(nums)-1
		ans := -1
		for l <= r {
			m := l + (r-l)/2
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
	return total
}

func p002RemoveElement(n int) int {
	nums := makePositive(n, 2, 17)
	val := 7
	k := 0
	for _, x := range nums {
		if x != val {
			nums[k] = x
			k++
		}
	}
	return k + checksum(nums[:k])
}

func p003SortedSquares(n int) int {
	nums := makeInts(n, 3)
	sort.Ints(nums)
	ans := make([]int, n)
	l, r, pos := 0, n-1, n-1
	for l <= r {
		a, b := nums[l]*nums[l], nums[r]*nums[r]
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

func p004MinSubArrayLen(n int) int {
	nums := makePositive(n, 4, 20)
	target := n * 4
	sum, left, best := 0, 0, n+1
	for right, x := range nums {
		sum += x
		for sum >= target {
			best = min(best, right-left+1)
			sum -= nums[left]
			left++
		}
	}
	if best == n+1 {
		return 0
	}
	return best
}

func p005SpiralMatrix(n int) int {
	m := min(96, max(4, intSqrt(n)))
	mat := make([]int, m*m)
	top, bottom, left, right := 0, m-1, 0, m-1
	v := 1
	for top <= bottom && left <= right {
		for j := left; j <= right; j++ {
			mat[top*m+j] = v
			v++
		}
		top++
		for i := top; i <= bottom; i++ {
			mat[i*m+right] = v
			v++
		}
		right--
		if top <= bottom {
			for j := right; j >= left; j-- {
				mat[bottom*m+j] = v
				v++
			}
			bottom--
		}
		if left <= right {
			for i := bottom; i >= top; i-- {
				mat[i*m+left] = v
				v++
			}
			left++
		}
	}
	return checksum(mat)
}

func p006MaxSubArray(n int) int {
	nums := makeInts(n, 6)
	best, cur := nums[0], nums[0]
	for i := 1; i < n; i++ {
		cur = max(nums[i], cur+nums[i])
		best = max(best, cur)
	}
	return best
}

type Interval struct {
	L int
	R int
}

func p007MergeIntervals(n int) int {
	ints := make([]Interval, n)
	for i := 0; i < n; i++ {
		a := (i*37 + 11) % (n + 101)
		ints[i] = Interval{a, a + (i*13)%31 + 1}
	}
	sort.Slice(ints, func(i, j int) bool {
		if ints[i].L == ints[j].L {
			return ints[i].R < ints[j].R
		}
		return ints[i].L < ints[j].L
	})
	merged := make([]Interval, 0, n)
	for _, in := range ints {
		if len(merged) == 0 || merged[len(merged)-1].R < in.L {
			merged = append(merged, in)
		} else if in.R > merged[len(merged)-1].R {
			merged[len(merged)-1].R = in.R
		}
	}
	total := len(merged)
	for _, in := range merged {
		total += in.L*31 + in.R
	}
	return total
}

func p008ProductExceptSelf(n int) int {
	nums := makePositive(n, 8, 9)
	ans := make([]int, n)
	left := 1
	for i := 0; i < n; i++ {
		ans[i] = left
		left = (left * nums[i]) % 1000000007
	}
	right := 1
	for i := n - 1; i >= 0; i-- {
		ans[i] = (ans[i] * right) % 1000000007
		right = (right * nums[i]) % 1000000007
	}
	return checksum(ans)
}

func p009TwoSum(n int) int {
	nums := makeInts(n, 9)
	if n > 3 {
		nums[n/3] = 123456
		nums[2*n/3] = -123000
	}
	target := 456
	seen := map[int]int{}
	for i, x := range nums {
		if j, ok := seen[target-x]; ok {
			return i + j*31
		}
		seen[x] = i
	}
	return -1
}

func p010IsAnagram(n int) int {
	s := makeLowerString(n, 10)
	b := []byte(s)
	for i, j := 0, len(b)-1; i < j; i, j = i+1, j-1 {
		b[i], b[j] = b[j], b[i]
	}
	cnt := [26]int{}
	for i := 0; i < len(s); i++ {
		cnt[s[i]-'a']++
		cnt[b[i]-'a']--
	}
	for _, c := range cnt {
		if c != 0 {
			return 0
		}
	}
	return 1
}

func p011GroupAnagrams(n int) int {
	words := make([]string, n)
	for i := range words {
		base := []byte(makeLowerString(7+(i%5), 110+i%17))
		sort.Slice(base, func(a, b int) bool { return base[a] < base[b] })
		if i%3 == 0 {
			for l, r := 0, len(base)-1; l < r; l, r = l+1, r-1 {
				base[l], base[r] = base[r], base[l]
			}
		}
		words[i] = string(base)
	}
	groups := map[[26]int]int{}
	for _, w := range words {
		key := [26]int{}
		for i := 0; i < len(w); i++ {
			key[w[i]-'a']++
		}
		groups[key]++
	}
	total := len(groups)
	for _, c := range groups {
		total += c * 17
	}
	return total
}

func p012FourSumCount(n int) int {
	m := min(360, max(8, n/8))
	a, b := makeInts(m, 1201), makeInts(m, 1202)
	c, d := makeInts(m, 1203), makeInts(m, 1204)
	cnt := make(map[int]int, m*m)
	for _, x := range a {
		for _, y := range b {
			cnt[x+y]++
		}
	}
	ans := 0
	for _, x := range c {
		for _, y := range d {
			ans += cnt[-x-y]
		}
	}
	return ans + len(cnt)
}

func p013ThreeSum(n int) int {
	m := min(900, max(12, n/4))
	nums := makeInts(m, 13)
	sort.Ints(nums)
	ans := 0
	for i := 0; i < m; i++ {
		if i > 0 && nums[i] == nums[i-1] {
			continue
		}
		l, r := i+1, m-1
		for l < r {
			s := nums[i] + nums[l] + nums[r]
			if s == 0 {
				ans++
				l++
				r--
				for l < r && nums[l] == nums[l-1] {
					l++
				}
				for l < r && nums[r] == nums[r+1] {
					r--
				}
			} else if s < 0 {
				l++
			} else {
				r--
			}
		}
	}
	return ans
}

func p014LongestSubstring(n int) int {
	s := makeLowerString(n, 14)
	last := [256]int{}
	for i := range last {
		last[i] = -1
	}
	left, best := 0, 0
	for i := 0; i < len(s); i++ {
		ch := s[i]
		if last[ch] >= left {
			left = last[ch] + 1
		}
		last[ch] = i
		best = max(best, i-left+1)
	}
	return best
}

func p015MinWindow(n int) int {
	s := makeLowerString(n, 15) + "algorithm"
	t := "algo"
	need := [256]int{}
	missing := len(t)
	for i := 0; i < len(t); i++ {
		need[t[i]]++
	}
	left, best := 0, len(s)+1
	for right := 0; right < len(s); right++ {
		if need[s[right]] > 0 {
			missing--
		}
		need[s[right]]--
		for missing == 0 {
			best = min(best, right-left+1)
			need[s[left]]++
			if need[s[left]] > 0 {
				missing++
			}
			left++
		}
	}
	if best == len(s)+1 {
		return 0
	}
	return best
}

func p016FindAnagrams(n int) int {
	s := makeLowerString(n, 16) + "abcabc"
	p := "abc"
	need, win := [26]int{}, [26]int{}
	for i := 0; i < len(p); i++ {
		need[p[i]-'a']++
	}
	ans := 0
	for i := 0; i < len(s); i++ {
		win[s[i]-'a']++
		if i >= len(p) {
			win[s[i-len(p)]-'a']--
		}
		if i >= len(p)-1 && win == need {
			ans += i - len(p) + 1
		}
	}
	return ans
}

type MyLinkedList struct {
	vals []int
	next []int
	head int
	size int
}

func NewLinkedList(capacity int) MyLinkedList {
	return MyLinkedList{vals: make([]int, 0, capacity), next: make([]int, 0, capacity), head: -1}
}

func (l *MyLinkedList) newNode(v int, nxt int) int {
	idx := len(l.vals)
	l.vals = append(l.vals, v)
	l.next = append(l.next, nxt)
	return idx
}

func (l *MyLinkedList) AddAtHead(v int) {
	l.head = l.newNode(v, l.head)
	l.size++
}

func (l *MyLinkedList) AddAtTail(v int) {
	node := l.newNode(v, -1)
	if l.head == -1 {
		l.head = node
	} else {
		cur := l.head
		for l.next[cur] != -1 {
			cur = l.next[cur]
		}
		l.next[cur] = node
	}
	l.size++
}

func (l *MyLinkedList) AddAtIndex(index int, v int) {
	if index < 0 || index > l.size {
		return
	}
	if index == 0 {
		l.AddAtHead(v)
		return
	}
	prev := l.head
	for i := 0; i < index-1; i++ {
		prev = l.next[prev]
	}
	l.next[prev] = l.newNode(v, l.next[prev])
	l.size++
}

func (l *MyLinkedList) DeleteAtIndex(index int) {
	if index < 0 || index >= l.size || l.head == -1 {
		return
	}
	if index == 0 {
		l.head = l.next[l.head]
		l.size--
		return
	}
	prev := l.head
	for i := 0; i < index-1; i++ {
		prev = l.next[prev]
	}
	l.next[prev] = l.next[l.next[prev]]
	l.size--
}

func (l *MyLinkedList) Get(index int) int {
	if index < 0 || index >= l.size {
		return -1
	}
	cur := l.head
	for i := 0; i < index; i++ {
		cur = l.next[cur]
	}
	return l.vals[cur]
}

func p017DesignLinkedList(n int) int {
	m := min(2400, n)
	list := NewLinkedList(m * 2)
	total := 0
	for i := 0; i < m; i++ {
		if i%3 == 0 {
			list.AddAtHead(i)
		} else {
			list.AddAtTail(i)
		}
		if i%7 == 0 {
			list.AddAtIndex(list.size/2, i*2)
		}
		if i%11 == 0 && list.size > 0 {
			list.DeleteAtIndex(list.size / 3)
		}
		if list.size > 0 {
			total += list.Get((i * 17) % list.size)
		}
	}
	return total + list.size
}

func makeListPool(n int) ([]int, []int, int) {
	vals := make([]int, n)
	next := make([]int, n)
	for i := 0; i < n; i++ {
		vals[i] = i + 1
		next[i] = i + 1
	}
	if n > 0 {
		next[n-1] = -1
		return vals, next, 0
	}
	return vals, next, -1
}

func listChecksum(vals []int, next []int, head int, limit int) int {
	total, cur, steps := 0, head, 0
	for cur != -1 && steps < limit {
		total = total*131 + vals[cur]
		cur = next[cur]
		steps++
	}
	return total + steps
}

func p018ReverseList(n int) int {
	vals, next, head := makeListPool(n)
	prev, cur := -1, head
	for cur != -1 {
		nxt := next[cur]
		next[cur] = prev
		prev = cur
		cur = nxt
	}
	return listChecksum(vals, next, prev, n)
}

func p019ReverseBetween(n int) int {
	vals, next, head := makeListPool(n)
	left, right := n/4+1, 3*n/4
	dummy := len(vals)
	vals = append(vals, 0)
	next = append(next, head)
	prev := dummy
	for i := 1; i < left; i++ {
		prev = next[prev]
	}
	cur := next[prev]
	for i := 0; i < right-left; i++ {
		move := next[cur]
		next[cur] = next[move]
		next[move] = next[prev]
		next[prev] = move
	}
	return listChecksum(vals, next, next[dummy], n)
}

func p020SwapPairs(n int) int {
	vals, next, head := makeListPool(n)
	dummy := len(vals)
	vals = append(vals, 0)
	next = append(next, head)
	prev := dummy
	for next[prev] != -1 && next[next[prev]] != -1 {
		a := next[prev]
		b := next[a]
		next[a] = next[b]
		next[b] = a
		next[prev] = b
		prev = a
	}
	return listChecksum(vals, next, next[dummy], n)
}

func p021RemoveNthFromEnd(n int) int {
	vals, next, head := makeListPool(n)
	k := max(1, n/3)
	dummy := len(vals)
	vals = append(vals, 0)
	next = append(next, head)
	fast := dummy
	for i := 0; i < k; i++ {
		fast = next[fast]
	}
	slow := dummy
	for next[fast] != -1 {
		fast = next[fast]
		slow = next[slow]
	}
	next[slow] = next[next[slow]]
	return listChecksum(vals, next, next[dummy], n-1)
}

func p022IntersectionList(n int) int {
	common := n / 3
	aLen, bLen := n/2, n/2+n/7
	a, b := aLen, bLen
	for a != b {
		if a == 0 {
			a = bLen + common
		} else {
			a--
		}
		if b == 0 {
			b = aLen + common
		} else {
			b--
		}
	}
	return a + common
}

func p023DetectCycle(n int) int {
	next := make([]int, n)
	entry := n / 3
	for i := 0; i < n-1; i++ {
		next[i] = i + 1
	}
	next[n-1] = entry
	slow, fast := 0, 0
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
	return slow
}

func p024ValidParentheses(n int) int {
	pairs := []byte{'(', '[', '{'}
	close := map[byte]byte{')': '(', ']': '[', '}': '{'}
	s := make([]byte, 0, n+3)
	for i := 0; i < n; i++ {
		s = append(s, pairs[i%3])
	}
	for i := n - 1; i >= 0; i-- {
		switch pairs[i%3] {
		case '(':
			s = append(s, ')')
		case '[':
			s = append(s, ']')
		default:
			s = append(s, '}')
		}
	}
	stack := make([]byte, 0, len(s))
	for _, ch := range s {
		if ch == '(' || ch == '[' || ch == '{' {
			stack = append(stack, ch)
		} else {
			if len(stack) == 0 || stack[len(stack)-1] != close[ch] {
				return 0
			}
			stack = stack[:len(stack)-1]
		}
	}
	if len(stack) == 0 {
		return 1
	}
	return 0
}

type MyQueue struct {
	in  []int
	out []int
}

func (q *MyQueue) Push(x int) { q.in = append(q.in, x) }
func (q *MyQueue) Pop() int {
	if len(q.out) == 0 {
		for len(q.in) > 0 {
			q.out = append(q.out, q.in[len(q.in)-1])
			q.in = q.in[:len(q.in)-1]
		}
	}
	x := q.out[len(q.out)-1]
	q.out = q.out[:len(q.out)-1]
	return x
}

func p025QueueUsingStacks(n int) int {
	q := MyQueue{}
	total := 0
	for i := 0; i < n; i++ {
		q.Push(i)
		if i%3 == 0 {
			total += q.Pop()
		}
	}
	for len(q.in)+len(q.out) > 0 {
		total += q.Pop()
	}
	return total
}

type MyStack struct {
	q    []int
	head int
	size int
}

func NewQueueStack(capacity int) MyStack {
	return MyStack{q: make([]int, capacity+1)}
}

func (s *MyStack) pushBack(x int) {
	idx := (s.head + s.size) % len(s.q)
	s.q[idx] = x
	s.size++
}

func (s *MyStack) popFront() int {
	x := s.q[s.head]
	s.head = (s.head + 1) % len(s.q)
	s.size--
	return x
}

func (s *MyStack) Push(x int) {
	s.pushBack(x)
	for i := 0; i < s.size-1; i++ {
		s.pushBack(s.popFront())
	}
}
func (s *MyStack) Pop() int {
	return s.popFront()
}

func p026StackUsingQueues(n int) int {
	m := min(6000, n)
	st := NewQueueStack(m + 1)
	total := 0
	for i := 0; i < m; i++ {
		st.Push(i)
		if i%4 == 0 {
			total += st.Pop()
		}
	}
	for st.size > 0 {
		total += st.Pop()
	}
	return total
}

type MinStack struct {
	data []int
	mins []int
}

func (s *MinStack) Push(x int) {
	s.data = append(s.data, x)
	if len(s.mins) == 0 || x <= s.mins[len(s.mins)-1] {
		s.mins = append(s.mins, x)
	}
}
func (s *MinStack) Pop() int {
	x := s.data[len(s.data)-1]
	s.data = s.data[:len(s.data)-1]
	if x == s.mins[len(s.mins)-1] {
		s.mins = s.mins[:len(s.mins)-1]
	}
	return x
}
func (s *MinStack) Min() int { return s.mins[len(s.mins)-1] }

func p027MinStack(n int) int {
	xs := makeInts(n, 27)
	st := MinStack{}
	total := 0
	for i, x := range xs {
		st.Push(x)
		if i%5 == 0 {
			total += st.Min()
		}
		if i%7 == 0 && len(st.data) > 0 {
			total += st.Pop()
		}
	}
	return total
}

func p028EvalRPN(n int) int {
	m := max(4, n/8)
	st := make([]int, 0, m)
	for i := 1; i <= m; i++ {
		st = append(st, i%97+1)
		if i%3 == 0 {
			b := st[len(st)-1]
			a := st[len(st)-2]
			st = st[:len(st)-2]
			st = append(st, (a+b)%1000003)
		}
		if i%11 == 0 && len(st) >= 2 {
			b := st[len(st)-1]
			a := st[len(st)-2]
			st = st[:len(st)-2]
			st = append(st, (a*b+7)%1000003)
		}
	}
	return checksum(st)
}

func p029SlidingWindowMax(n int) int {
	nums := makeInts(n, 29)
	k := max(2, intSqrt(n))
	deq := make([]int, 0, n)
	out := make([]int, 0, n)
	for i, x := range nums {
		for len(deq) > 0 && deq[0] <= i-k {
			deq = deq[1:]
		}
		for len(deq) > 0 && nums[deq[len(deq)-1]] <= x {
			deq = deq[:len(deq)-1]
		}
		deq = append(deq, i)
		if i >= k-1 {
			out = append(out, nums[deq[0]])
		}
	}
	return checksum(out)
}

func p030DailyTemperatures(n int) int {
	t := makePositive(n, 30, 70)
	for i := range t {
		t[i] += 30
	}
	ans := make([]int, n)
	st := make([]int, 0, n)
	for i, x := range t {
		for len(st) > 0 && x > t[st[len(st)-1]] {
			j := st[len(st)-1]
			st = st[:len(st)-1]
			ans[j] = i - j
		}
		st = append(st, i)
	}
	return checksum(ans)
}

func p031LargestRectangle(n int) int {
	h := makePositive(n, 31, 1000)
	st := []int{-1}
	best := 0
	for i := 0; i <= n; i++ {
		cur := 0
		if i < n {
			cur = h[i]
		}
		for st[len(st)-1] != -1 && cur < h[st[len(st)-1]] {
			idx := st[len(st)-1]
			st = st[:len(st)-1]
			best = max(best, h[idx]*(i-st[len(st)-1]-1))
		}
		st = append(st, i)
	}
	return best
}

type IntHeap []int

func (h IntHeap) Len() int           { return len(h) }
func (h IntHeap) Less(i, j int) bool { return h[i] < h[j] }
func (h IntHeap) Swap(i, j int)      { h[i], h[j] = h[j], h[i] }
func (h *IntHeap) Push(x any)        { *h = append(*h, x.(int)) }
func (h *IntHeap) Pop() any {
	old := *h
	x := old[len(old)-1]
	*h = old[:len(old)-1]
	return x
}

func p032KthLargest(n int) int {
	nums := makeInts(n, 32)
	k := max(1, n/10)
	h := IntHeap{}
	heap.Init(&h)
	for _, x := range nums {
		heap.Push(&h, x)
		if h.Len() > k {
			heap.Pop(&h)
		}
	}
	return h[0]
}

func p033TopKFrequent(n int) int {
	nums := makePositive(n, 33, max(8, n/8))
	freq := map[int]int{}
	for _, x := range nums {
		freq[x]++
	}
	k := min(20, len(freq))
	h := IntHeap{}
	heap.Init(&h)
	for val, c := range freq {
		packed := c*100000 + val
		heap.Push(&h, packed)
		if h.Len() > k {
			heap.Pop(&h)
		}
	}
	total := 0
	for h.Len() > 0 {
		total += heap.Pop(&h).(int)
	}
	return total
}

type MedianFinder struct {
	lo IntHeap
	hi IntHeap
}

func (m *MedianFinder) Add(x int) {
	heap.Push(&m.lo, -x)
	if m.lo.Len() > 0 && m.hi.Len() > 0 && -m.lo[0] > m.hi[0] {
		a := -heap.Pop(&m.lo).(int)
		b := heap.Pop(&m.hi).(int)
		heap.Push(&m.lo, -b)
		heap.Push(&m.hi, a)
	}
	if m.lo.Len() > m.hi.Len()+1 {
		heap.Push(&m.hi, -heap.Pop(&m.lo).(int))
	}
	if m.hi.Len() > m.lo.Len() {
		heap.Push(&m.lo, -heap.Pop(&m.hi).(int))
	}
}
func (m *MedianFinder) Median2() int {
	if m.lo.Len() == m.hi.Len() {
		return -m.lo[0] + m.hi[0]
	}
	return -2 * m.lo[0]
}

func p034MedianFinder(n int) int {
	xs := makeInts(n, 34)
	m := MedianFinder{}
	heap.Init(&m.lo)
	heap.Init(&m.hi)
	total := 0
	for i, x := range xs {
		m.Add(x)
		if i%17 == 0 {
			total += m.Median2()
		}
	}
	return total
}

func p035LevelOrder(n int) int {
	vals := makePositive(n, 35, 1000)
	total := 0
	q := []int{0}
	for len(q) > 0 {
		i := q[0]
		q = q[1:]
		if i >= n {
			continue
		}
		total += vals[i]
		q = append(q, 2*i+1, 2*i+2)
	}
	return total
}

func p036MaxDepth(n int) int {
	depth := 0
	for nodes := 1; nodes <= n; nodes <<= 1 {
		depth++
	}
	return depth
}

func heightBalanced(n int, idx int) int {
	if idx >= n {
		return 0
	}
	l := heightBalanced(n, idx*2+1)
	if l == -1 {
		return -1
	}
	r := heightBalanced(n, idx*2+2)
	if r == -1 || abs(l-r) > 1 {
		return -1
	}
	return max(l, r) + 1
}

func p037IsBalanced(n int) int {
	if heightBalanced(n, 0) >= 0 {
		return 1
	}
	return 0
}

func invertChecksum(vals []int, idx int) int {
	if idx >= len(vals) {
		return 0
	}
	l, r := idx*2+1, idx*2+2
	if l < len(vals) && r < len(vals) {
		vals[l], vals[r] = vals[r], vals[l]
	}
	return vals[idx] + 3*invertChecksum(vals, l) + 5*invertChecksum(vals, r)
}

func p038InvertTree(n int) int {
	vals := makePositive(n, 38, 1000)
	return invertChecksum(vals, 0)
}

func p039SymmetricTree(n int) int {
	vals := make([]int, n)
	for i := range vals {
		d := 0
		for x := i + 1; x > 1; x >>= 1 {
			d++
		}
		vals[i] = d
	}
	var mirror func(int, int) bool
	mirror = func(a, b int) bool {
		if a >= n || b >= n {
			return a >= n && b >= n
		}
		return vals[a] == vals[b] && mirror(2*a+1, 2*b+2) && mirror(2*a+2, 2*b+1)
	}
	if mirror(1, 2) {
		return 1
	}
	return 0
}

func pathSum(vals []int, idx int, target int) bool {
	if idx >= len(vals) {
		return false
	}
	target -= vals[idx]
	l, r := idx*2+1, idx*2+2
	if l >= len(vals) && r >= len(vals) {
		return target == 0
	}
	return pathSum(vals, l, target) || pathSum(vals, r, target)
}

func p040PathSum(n int) int {
	vals := makePositive(n, 40, 13)
	target := 0
	for i := 0; i < n; i = i*2 + 1 {
		target += vals[i]
	}
	if pathSum(vals, 0, target) {
		return target
	}
	return 0
}

func buildPreIn(lo, hi int, pre *[]int, in *[]int) {
	if lo > hi {
		return
	}
	mid := (lo + hi) / 2
	*pre = append(*pre, mid)
	buildPreIn(lo, mid-1, pre, in)
	*in = append(*in, mid)
	buildPreIn(mid+1, hi, pre, in)
}

func buildTreeChecksum(pre []int, pl int, pr int, il int, ir int, pos map[int]int) int {
	if pl > pr {
		return 0
	}
	root := pre[pl]
	k := pos[root]
	left := k - il
	return root + 3*buildTreeChecksum(pre, pl+1, pl+left, il, k-1, pos) + 5*buildTreeChecksum(pre, pl+left+1, pr, k+1, ir, pos)
}

func p041BuildTree(n int) int {
	m := min(4095, n)
	pre, in := []int{}, []int{}
	buildPreIn(0, m-1, &pre, &in)
	pos := make(map[int]int, m)
	for i, v := range in {
		pos[v] = i
	}
	return buildTreeChecksum(pre, 0, len(pre)-1, 0, len(in)-1, pos)
}

func p042LowestCommonAncestor(n int) int {
	a, b := n*2/3, n*3/4
	for a != b {
		if a > b {
			a = (a - 1) / 2
		} else {
			b = (b - 1) / 2
		}
	}
	return a
}

func fillBST(vals []int, idx int, next *int) {
	if idx >= len(vals) {
		return
	}
	fillBST(vals, idx*2+1, next)
	vals[idx] = *next
	*next++
	fillBST(vals, idx*2+2, next)
}

func validateBST(vals []int, idx int, lo int, hi int) bool {
	if idx >= len(vals) {
		return true
	}
	v := vals[idx]
	if v <= lo || v >= hi {
		return false
	}
	return validateBST(vals, idx*2+1, lo, v) && validateBST(vals, idx*2+2, v, hi)
}

func p043ValidateBST(n int) int {
	vals := make([]int, n)
	x := 1
	fillBST(vals, 0, &x)
	if validateBST(vals, 0, -1, n+2) {
		return 1
	}
	return 0
}

func kthInorder(n int, idx int, k *int) int {
	if idx >= n {
		return -1
	}
	if v := kthInorder(n, idx*2+1, k); v != -1 {
		return v
	}
	*k--
	if *k == 0 {
		return idx
	}
	return kthInorder(n, idx*2+2, k)
}

func p044KthSmallest(n int) int {
	k := max(1, n/2)
	return kthInorder(n, 0, &k)
}

func p045NumIslands(n int) int {
	side := min(180, max(8, intSqrt(n)))
	grid := make([]byte, side*side)
	for i := range grid {
		if (i*37+i/side*17)%11 < 6 {
			grid[i] = 1
		}
	}
	dirs := []int{1, 0, -1, 0, 1}
	islands := 0
	stack := make([]int, 0, side*side)
	for i := range grid {
		if grid[i] == 0 {
			continue
		}
		islands++
		grid[i] = 0
		stack = append(stack, i)
		for len(stack) > 0 {
			p := stack[len(stack)-1]
			stack = stack[:len(stack)-1]
			r, c := p/side, p%side
			for d := 0; d < 4; d++ {
				nr, nc := r+dirs[d], c+dirs[d+1]
				if nr >= 0 && nr < side && nc >= 0 && nc < side {
					q := nr*side + nc
					if grid[q] == 1 {
						grid[q] = 0
						stack = append(stack, q)
					}
				}
			}
		}
	}
	return islands
}

func makeCourses(n int) (int, [][]int) {
	courses := min(6000, max(16, n/2))
	pre := make([][]int, 0, courses*2)
	for i := 1; i < courses; i++ {
		pre = append(pre, []int{i, (i - 1) / 2})
		if i > 3 && i%5 == 0 {
			pre = append(pre, []int{i, i - 3})
		}
	}
	return courses, pre
}

func topo(courses int, pre [][]int) []int {
	g := make([][]int, courses)
	indeg := make([]int, courses)
	for _, e := range pre {
		to, from := e[0], e[1]
		g[from] = append(g[from], to)
		indeg[to]++
	}
	q := make([]int, 0, courses)
	for i, d := range indeg {
		if d == 0 {
			q = append(q, i)
		}
	}
	order := make([]int, 0, courses)
	for head := 0; head < len(q); head++ {
		u := q[head]
		order = append(order, u)
		for _, v := range g[u] {
			indeg[v]--
			if indeg[v] == 0 {
				q = append(q, v)
			}
		}
	}
	return order
}

func p046CourseSchedule(n int) int {
	c, pre := makeCourses(n)
	if len(topo(c, pre)) == c {
		return 1
	}
	return 0
}

func p047CourseScheduleII(n int) int {
	c, pre := makeCourses(n)
	return checksum(topo(c, pre))
}

type DSU struct {
	parent []int
	rank   []int
}

func NewDSU(n int) DSU {
	p := make([]int, n+1)
	r := make([]int, n+1)
	for i := range p {
		p[i] = i
	}
	return DSU{p, r}
}
func (d *DSU) Find(x int) int {
	for d.parent[x] != x {
		d.parent[x] = d.parent[d.parent[x]]
		x = d.parent[x]
	}
	return x
}
func (d *DSU) Union(a, b int) bool {
	ra, rb := d.Find(a), d.Find(b)
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

func p048RedundantConnection(n int) int {
	m := min(10000, max(3, n))
	d := NewDSU(m)
	for i := 2; i <= m; i++ {
		d.Union(i-1, i)
	}
	if !d.Union(1, m) {
		return 1 + m*31
	}
	return 0
}

type TrieNode struct {
	child [26]int
	end   bool
}

func p049Trie(n int) int {
	nodes := []TrieNode{{}}
	insert := func(w string) {
		cur := 0
		for i := 0; i < len(w); i++ {
			c := int(w[i] - 'a')
			if nodes[cur].child[c] == 0 {
				nodes = append(nodes, TrieNode{})
				nodes[cur].child[c] = len(nodes) - 1
			}
			cur = nodes[cur].child[c]
		}
		nodes[cur].end = true
	}
	search := func(w string) bool {
		cur := 0
		for i := 0; i < len(w); i++ {
			c := int(w[i] - 'a')
			if nodes[cur].child[c] == 0 {
				return false
			}
			cur = nodes[cur].child[c]
		}
		return nodes[cur].end
	}
	total := 0
	for i := 0; i < n; i++ {
		w := makeLowerString(6+i%9, 4900+i)
		insert(w)
		if i%4 == 0 && search(w) {
			total++
		}
	}
	return total + len(nodes)
}

type Fenwick struct {
	bit []int
	arr []int
}

func NewFenwick(xs []int) Fenwick {
	f := Fenwick{bit: make([]int, len(xs)+1), arr: append([]int(nil), xs...)}
	for i, x := range xs {
		f.add(i+1, x)
	}
	return f
}
func (f *Fenwick) add(i int, delta int) {
	for i < len(f.bit) {
		f.bit[i] += delta
		i += i & -i
	}
}
func (f *Fenwick) Update(i int, val int) {
	d := val - f.arr[i]
	f.arr[i] = val
	f.add(i+1, d)
}
func (f *Fenwick) Prefix(i int) int {
	s := 0
	for i > 0 {
		s += f.bit[i]
		i -= i & -i
	}
	return s
}
func (f *Fenwick) SumRange(l, r int) int {
	return f.Prefix(r+1) - f.Prefix(l)
}

func p050NumArray(n int) int {
	xs := makePositive(n, 50, 100)
	f := NewFenwick(xs)
	total := 0
	for i := 0; i < n; i++ {
		if i%3 == 0 {
			f.Update(i, (i*17)%101)
		} else {
			l := (i * 37) % n
			r := (l + i%97) % n
			if l > r {
				l, r = r, l
			}
			total += f.SumRange(l, r)
		}
	}
	return total
}

func intSqrt(n int) int {
	x := 0
	for (x+1)*(x+1) <= n {
		x++
	}
	return x
}

var problems = []Problem{
	{1, "Array", "704 Binary Search", "binary boundaries", p001BinarySearch},
	{2, "Array", "27 Remove Element", "two pointers", p002RemoveElement},
	{3, "Array", "977 Squares of Sorted Array", "two pointers", p003SortedSquares},
	{4, "Array", "209 Minimum Size Subarray Sum", "sliding window", p004MinSubArrayLen},
	{5, "Array/Matrix", "59 Spiral Matrix II", "simulation", p005SpiralMatrix},
	{6, "Array", "53 Maximum Subarray", "dynamic maintenance", p006MaxSubArray},
	{7, "Array", "56 Merge Intervals", "sort and merge", p007MergeIntervals},
	{8, "Array", "238 Product Except Self", "prefix suffix products", p008ProductExceptSelf},
	{9, "Hash", "1 Two Sum", "hash lookup", p009TwoSum},
	{10, "Hash", "242 Valid Anagram", "counting hash", p010IsAnagram},
	{11, "Hash", "49 Group Anagrams", "hash key design", p011GroupAnagrams},
	{12, "Hash", "454 4Sum II", "grouped hash", p012FourSumCount},
	{13, "Hash/TwoPointer", "15 3Sum", "sort dedupe two pointers", p013ThreeSum},
	{14, "String", "3 Longest Substring", "sliding window set", p014LongestSubstring},
	{15, "String", "76 Minimum Window", "sliding window counts", p015MinWindow},
	{16, "String", "438 Find Anagrams", "fixed window", p016FindAnagrams},
	{17, "LinkedList", "707 Design Linked List", "linked operations", p017DesignLinkedList},
	{18, "LinkedList", "206 Reverse Linked List", "iterative reverse", p018ReverseList},
	{19, "LinkedList", "92 Reverse Linked List II", "local reverse", p019ReverseBetween},
	{20, "LinkedList", "24 Swap Nodes in Pairs", "pointer reconnect", p020SwapPairs},
	{21, "LinkedList", "19 Remove Nth From End", "fast slow pointers", p021RemoveNthFromEnd},
	{22, "LinkedList", "160 Intersection Linked List", "two pointer sync", p022IntersectionList},
	{23, "LinkedList", "142 Linked List Cycle II", "fast slow entry", p023DetectCycle},
	{24, "Stack", "20 Valid Parentheses", "stack matching", p024ValidParentheses},
	{25, "Stack/Queue", "232 Queue Using Stacks", "two stacks", p025QueueUsingStacks},
	{26, "Stack/Queue", "225 Stack Using Queues", "queue rotation", p026StackUsingQueues},
	{27, "Stack", "155 Min Stack", "auxiliary stack", p027MinStack},
	{28, "Stack", "150 Evaluate RPN", "expression stack", p028EvalRPN},
	{29, "Queue", "239 Sliding Window Maximum", "monotone queue", p029SlidingWindowMax},
	{30, "MonotonicStack", "739 Daily Temperatures", "monotone stack", p030DailyTemperatures},
	{31, "MonotonicStack", "84 Largest Rectangle", "advanced monotone stack", p031LargestRectangle},
	{32, "Heap", "215 Kth Largest", "min heap", p032KthLargest},
	{33, "Heap/Hash", "347 Top K Frequent", "hash and heap", p033TopKFrequent},
	{34, "Heap", "295 Median Finder", "two heaps", p034MedianFinder},
	{35, "BinaryTree", "102 Level Order", "BFS queue", p035LevelOrder},
	{36, "BinaryTree", "104 Maximum Depth", "DFS recursion", p036MaxDepth},
	{37, "BinaryTree", "110 Balanced Binary Tree", "bottom up recursion", p037IsBalanced},
	{38, "BinaryTree", "226 Invert Binary Tree", "tree recursion", p038InvertTree},
	{39, "BinaryTree", "101 Symmetric Tree", "dual recursion", p039SymmetricTree},
	{40, "BinaryTree", "112 Path Sum", "DFS backtracking", p040PathSum},
	{41, "BinaryTree", "105 Build Tree", "recursive construction", p041BuildTree},
	{42, "BinaryTree", "236 Lowest Common Ancestor", "postorder logic", p042LowestCommonAncestor},
	{43, "BST", "98 Validate BST", "inorder bounds", p043ValidateBST},
	{44, "BST", "230 Kth Smallest", "inorder traversal", p044KthSmallest},
	{45, "Graph", "200 Number of Islands", "grid DFS", p045NumIslands},
	{46, "Graph", "207 Course Schedule", "topological sort", p046CourseSchedule},
	{47, "Graph", "210 Course Schedule II", "topological output", p047CourseScheduleII},
	{48, "UnionFind", "684 Redundant Connection", "cycle detection", p048RedundantConnection},
	{49, "Trie", "208 Implement Trie", "prefix tree", p049Trie},
	{50, "Fenwick", "307 Range Sum Query Mutable", "point update range query", p050NumArray},
}

var benchSink int

func checksumOne(p Problem, n int, repeat int) int {
	total := 0
	for r := 0; r < repeat; r++ {
		total ^= p.Run(n + (r % 3))
	}
	return total
}

func runOne(p Problem, n int, repeat int, minNs int64) (int64, int, int) {
	sum := checksumOne(p, n, repeat)
	iterations := 0
	sink := 0
	start := time.Now()
	maxIterations := repeat * 1000000
	for {
		for r := 0; r < repeat; r++ {
			sink ^= p.Run(n + ((iterations + r) % 3))
		}
		iterations += repeat
		elapsed := time.Since(start).Nanoseconds()
		if elapsed >= minNs || iterations >= maxIterations {
			benchSink ^= sink
			if iterations <= 0 {
				iterations = 1
			}
			avg := elapsed / int64(iterations)
			if avg <= 0 {
				avg = 1
			}
			return avg, sum, iterations
		}
	}
}

func main() {
	trials := flag.Int("trials", 15, "number of measured trials")
	sizesCSV := flag.String("sizes", "512,2048,8192", "comma-separated logical sizes")
	repeat := flag.Int("repeat", 1, "function repetitions per trial")
	minMs := flag.Int("min-ms", 5, "minimum timed milliseconds per measured trial")
	flag.Parse()
	if *repeat < 1 {
		*repeat = 1
	}
	if *minMs < 0 {
		*minMs = 0
	}
	minNs := int64(*minMs) * int64(time.Millisecond)
	sizes := []int{}
	for _, part := range strings.Split(*sizesCSV, ",") {
		v, err := strconv.Atoi(strings.TrimSpace(part))
		if err != nil || v <= 0 {
			fmt.Fprintf(os.Stderr, "invalid size: %s\n", part)
			os.Exit(2)
		}
		sizes = append(sizes, v)
	}
	fmt.Println("language,problem_id,category,title,core,input_size,trial,elapsed_ns,iterations,checksum")
	for _, p := range problems {
		for _, n := range sizes {
			for t := 0; t < *trials; t++ {
				ns, sum, iterations := runOne(p, n, *repeat, minNs)
				fmt.Printf("go,%d,%q,%q,%q,%d,%d,%d,%d,%d\n", p.ID, p.Category, p.Title, p.Core, n, t, ns, iterations, sum)
			}
		}
	}
}
