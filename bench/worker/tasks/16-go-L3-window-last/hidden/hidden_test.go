package window

import (
	"reflect"
	"testing"
)

func TestHiddenLastFollowsNewest(t *testing.T) {
	for _, size := range []int{1, 2, 3, 5} {
		w, err := New(size)
		if err != nil {
			t.Fatal(err)
		}
		var added []float64
		for i := 1; i <= 4*size+1; i++ {
			v := float64(i * 10)
			w.Add(v)
			added = append(added, v)
			last, ok := w.Last()
			if !ok || last != v {
				t.Fatalf("size %d after %d adds: Last = %v, %v; want %v", size, i, last, ok, v)
			}
			lo := len(added) - size
			if lo < 0 {
				lo = 0
			}
			if got := w.Values(); !reflect.DeepEqual(got, added[lo:]) {
				t.Fatalf("size %d after %d adds: Values = %v, want %v", size, i, got, added[lo:])
			}
		}
	}
}

func TestHiddenSummariesAfterWrap(t *testing.T) {
	w, _ := New(3)
	for _, v := range []float64{100, 1, 2, 3} {
		w.Add(v)
	}
	if m, _ := w.Max(); m != 3 {
		t.Errorf("Max = %v", m)
	}
	if m, _ := w.Mean(); m != 2 {
		t.Errorf("Mean = %v", m)
	}
	if w.Len() != 3 || w.Size() != 3 {
		t.Errorf("Len/Size = %d/%d", w.Len(), w.Size())
	}
	empty, _ := New(2)
	if _, ok := empty.Last(); ok {
		t.Error("Last on empty window should be false")
	}
}
