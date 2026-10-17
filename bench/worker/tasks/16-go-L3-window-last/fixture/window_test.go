package window

import (
	"reflect"
	"testing"
)

func mustNew(t *testing.T, size int) *Window {
	t.Helper()
	w, err := New(size)
	if err != nil {
		t.Fatal(err)
	}
	return w
}

func TestNewRejectsZero(t *testing.T) {
	if _, err := New(0); err == nil {
		t.Fatal("New(0) should fail")
	}
}

func TestEmpty(t *testing.T) {
	w := mustNew(t, 3)
	if _, ok := w.Last(); ok {
		t.Error("Last on empty window should be false")
	}
	if _, ok := w.Mean(); ok {
		t.Error("Mean on empty window should be false")
	}
}

func TestValuesDropOldest(t *testing.T) {
	w := mustNew(t, 3)
	for _, v := range []float64{1, 2, 3, 4, 5} {
		w.Add(v)
	}
	if got := w.Values(); !reflect.DeepEqual(got, []float64{3, 4, 5}) {
		t.Errorf("Values = %v", got)
	}
	if w.Len() != 3 {
		t.Errorf("Len = %d", w.Len())
	}
}

func TestSummaries(t *testing.T) {
	w := mustNew(t, 4)
	for _, v := range []float64{10, 30, 20} {
		w.Add(v)
	}
	if last, _ := w.Last(); last != 20 {
		t.Errorf("Last = %v", last)
	}
	if mean, _ := w.Mean(); mean != 20 {
		t.Errorf("Mean = %v", mean)
	}
	if max, _ := w.Max(); max != 30 {
		t.Errorf("Max = %v", max)
	}
}
