// Package window keeps the most recent N samples of a metric in a fixed-size
// ring buffer and summarizes them.
package window

import "errors"

// Window holds up to Size() samples; adding to a full window drops the oldest.
type Window struct {
	buf   []float64
	start int // index of the oldest sample
	n     int // number of samples held
}

// New returns an empty window of the given size.
func New(size int) (*Window, error) {
	if size < 1 {
		return nil, errors.New("window: size must be at least 1")
	}
	return &Window{buf: make([]float64, size)}, nil
}

// Size is the maximum number of samples kept.
func (w *Window) Size() int { return len(w.buf) }

// Len is the number of samples currently held.
func (w *Window) Len() int { return w.n }

// Add records a sample, dropping the oldest one when the window is full.
func (w *Window) Add(v float64) {
	if w.n < len(w.buf) {
		w.buf[(w.start+w.n)%len(w.buf)] = v
		w.n++
		return
	}
	w.buf[w.start] = v
	w.start = (w.start + 1) % len(w.buf)
}

// Values returns the samples from oldest to newest.
func (w *Window) Values() []float64 {
	out := make([]float64, w.n)
	for i := range out {
		out[i] = w.buf[(w.start+i)%len(w.buf)]
	}
	return out
}

// Last returns the most recent sample, or false when the window is empty.
func (w *Window) Last() (float64, bool) {
	if w.n == 0 {
		return 0, false
	}
	return w.buf[w.n-1], true
}

// Mean returns the average of the samples, or false when empty.
func (w *Window) Mean() (float64, bool) {
	if w.n == 0 {
		return 0, false
	}
	sum := 0.0
	for _, v := range w.Values() {
		sum += v
	}
	return sum / float64(w.n), true
}

// Max returns the largest sample, or false when empty.
func (w *Window) Max() (float64, bool) {
	if w.n == 0 {
		return 0, false
	}
	vals := w.Values()
	m := vals[0]
	for _, v := range vals[1:] {
		if v > m {
			m = v
		}
	}
	return m, true
}
