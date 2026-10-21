#pragma once

// Array.sort_custom(), element for element: Godot 4.6.2's SortArray introsort
// with validation on (core/templates/sort_array.h and Array::sort_custom of the
// 4.6.2-stable tag, MIT). The sort is not stable, so equal elements end up in
// the order this exact algorithm leaves them; a port that sorts the way the
// script does must use it. Fuzzed against the engine by
// tools/rules_compat/capture_vectors.gd and rules_selftest.
//
// Validation stays on as in the engine: with a comparator that is not a strict
// weak order the engine prints "bad comparison function" and stops that loop,
// and so does this copy (without the message).

#include <cstdint>
#include <utility>

namespace aurelion::rules::compat {

template <typename T, typename Less>
class GodotSortArray {
public:
	explicit GodotSortArray(Less less) :
			compare_(std::move(less)) {}

	void sort(T *array, int64_t len) const {
		if (len > 0) {
			sort_range(0, len, array);
		}
	}

private:
	static constexpr int64_t kIntrosortThreshold = 16;

	bool compare(const T &a, const T &b) const { return compare_(a, b); }

	int64_t median_of_3_index(const T *p_ptr, int64_t a_index, int64_t b_index, int64_t c_index) const {
		const T &a = p_ptr[a_index];
		const T &b = p_ptr[b_index];
		const T &c = p_ptr[c_index];
		if (compare(a, b)) {
			if (compare(b, c)) {
				return b_index;
			} else if (compare(a, c)) {
				return c_index;
			} else {
				return a_index;
			}
		} else if (compare(a, c)) {
			return a_index;
		} else if (compare(b, c)) {
			return c_index;
		} else {
			return b_index;
		}
	}

	static int64_t bitlog(int64_t n) {
		int64_t k;
		for (k = 0; n != 1; n >>= 1) {
			++k;
		}
		return k;
	}

	void push_heap(int64_t p_first, int64_t p_hole_idx, int64_t p_top_index, T p_value, T *p_array) const {
		int64_t parent = (p_hole_idx - 1) / 2;
		while (p_hole_idx > p_top_index && compare(p_array[p_first + parent], p_value)) {
			p_array[p_first + p_hole_idx] = p_array[p_first + parent];
			p_hole_idx = parent;
			parent = (p_hole_idx - 1) / 2;
		}
		p_array[p_first + p_hole_idx] = p_value;
	}

	void pop_heap(int64_t p_first, int64_t p_last, int64_t p_result, T p_value, T *p_array) const {
		p_array[p_result] = p_array[p_first];
		adjust_heap(p_first, 0, p_last - p_first, p_value, p_array);
	}

	void pop_heap(int64_t p_first, int64_t p_last, T *p_array) const {
		pop_heap(p_first, p_last - 1, p_last - 1, p_array[p_last - 1], p_array);
	}

	void adjust_heap(int64_t p_first, int64_t p_hole_idx, int64_t p_len, T p_value, T *p_array) const {
		const int64_t top_index = p_hole_idx;
		int64_t second_child = 2 * p_hole_idx + 2;
		while (second_child < p_len) {
			if (compare(p_array[p_first + second_child], p_array[p_first + (second_child - 1)])) {
				second_child--;
			}
			p_array[p_first + p_hole_idx] = p_array[p_first + second_child];
			p_hole_idx = second_child;
			second_child = 2 * (second_child + 1);
		}
		if (second_child == p_len) {
			p_array[p_first + p_hole_idx] = p_array[p_first + (second_child - 1)];
			p_hole_idx = second_child - 1;
		}
		push_heap(p_first, p_hole_idx, top_index, p_value, p_array);
	}

	void sort_heap(int64_t p_first, int64_t p_last, T *p_array) const {
		while (p_last - p_first > 1) {
			pop_heap(p_first, p_last--, p_array);
		}
	}

	void make_heap(int64_t p_first, int64_t p_last, T *p_array) const {
		if (p_last - p_first < 2) {
			return;
		}
		const int64_t len = p_last - p_first;
		int64_t parent = (len - 2) / 2;
		while (true) {
			adjust_heap(p_first, parent, len, p_array[p_first + parent], p_array);
			if (parent == 0) {
				return;
			}
			parent--;
		}
	}

	void partial_sort(int64_t p_first, int64_t p_last, int64_t p_middle, T *p_array) const {
		make_heap(p_first, p_middle, p_array);
		for (int64_t i = p_middle; i < p_last; i++) {
			if (compare(p_array[i], p_array[p_first])) {
				pop_heap(p_first, p_middle, i, p_array[i], p_array);
			}
		}
		sort_heap(p_first, p_middle, p_array);
	}

	int64_t partitioner(int64_t p_first, int64_t p_last, int64_t p_pivot, T *p_array) const {
		const int64_t unmodified_first = p_first;
		const int64_t unmodified_last = p_last;
		const T *pivot_element_location = &p_array[p_pivot];
		while (true) {
			while (p_first != p_pivot && compare(p_array[p_first], *pivot_element_location)) {
				if (p_first == unmodified_last - 1) {
					break; // ERR_BAD_COMPARE
				}
				p_first++;
			}
			p_last--;
			while (p_last != p_pivot && compare(*pivot_element_location, p_array[p_last])) {
				if (p_last == unmodified_first) {
					break; // ERR_BAD_COMPARE
				}
				p_last--;
			}
			if (p_first >= p_last) {
				return p_first;
			}
			if (pivot_element_location == &p_array[p_first]) {
				pivot_element_location = &p_array[p_last];
			} else if (pivot_element_location == &p_array[p_last]) {
				pivot_element_location = &p_array[p_first];
			}
			std::swap(p_array[p_first], p_array[p_last]);
			p_first++;
		}
	}

	void introsort(int64_t p_first, int64_t p_last, T *p_array, int64_t p_max_depth) const {
		while (p_last - p_first > kIntrosortThreshold) {
			if (p_max_depth == 0) {
				partial_sort(p_first, p_last, p_last, p_array);
				return;
			}
			p_max_depth--;
			const int64_t cut = partitioner(
					p_first,
					p_last,
					median_of_3_index(p_array, p_first, p_first + (p_last - p_first) / 2, p_last - 1),
					p_array);
			introsort(cut, p_last, p_array, p_max_depth);
			p_last = cut;
		}
	}

	void unguarded_linear_insert(int64_t p_last, T p_value, T *p_array) const {
		int64_t next = p_last - 1;
		while (compare(p_value, p_array[next])) {
			if (next == 0) {
				break; // ERR_BAD_COMPARE
			}
			p_array[p_last] = p_array[next];
			p_last = next;
			next--;
		}
		p_array[p_last] = p_value;
	}

	void linear_insert(int64_t p_first, int64_t p_last, T *p_array) const {
		T val = p_array[p_last];
		if (compare(val, p_array[p_first])) {
			for (int64_t i = p_last; i > p_first; i--) {
				p_array[i] = p_array[i - 1];
			}
			p_array[p_first] = val;
		} else {
			unguarded_linear_insert(p_last, val, p_array);
		}
	}

	void insertion_sort(int64_t p_first, int64_t p_last, T *p_array) const {
		if (p_first == p_last) {
			return;
		}
		for (int64_t i = p_first + 1; i != p_last; i++) {
			linear_insert(p_first, i, p_array);
		}
	}

	void unguarded_insertion_sort(int64_t p_first, int64_t p_last, T *p_array) const {
		for (int64_t i = p_first; i != p_last; i++) {
			unguarded_linear_insert(i, p_array[i], p_array);
		}
	}

	void final_insertion_sort(int64_t p_first, int64_t p_last, T *p_array) const {
		if (p_last - p_first > kIntrosortThreshold) {
			insertion_sort(p_first, p_first + kIntrosortThreshold, p_array);
			unguarded_insertion_sort(p_first + kIntrosortThreshold, p_last, p_array);
		} else {
			insertion_sort(p_first, p_last, p_array);
		}
	}

	void sort_range(int64_t p_first, int64_t p_last, T *p_array) const {
		if (p_first != p_last) {
			introsort(p_first, p_last, p_array, bitlog(p_last - p_first) * 2);
			final_insertion_sort(p_first, p_last, p_array);
		}
	}

	Less compare_;
};

template <typename T, typename Less>
void sort_custom(T *array, int64_t len, Less less) {
	GodotSortArray<T, Less>(std::move(less)).sort(array, len);
}

} // namespace aurelion::rules::compat
