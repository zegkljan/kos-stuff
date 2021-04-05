@LAZYGLOBAL OFF.

function identity {
  parameter x.
  return x.
}

function swap {
  parameter l.
  parameter a.
  parameter b.
  local t is l[a].
  set l[a] to l[b].
  set l[b] to t.
}

function quicksort {
  parameter lst.
  parameter keyf is identity@.
  parameter low is 0.
  parameter high is lst:length - 1.

  local partition is {
    parameter l.
    parameter lo.
    parameter hi.

    local pivot is l[hi].
    local i is lo.
    for j in range(lo, hi) {
      if keyf(l[j]) < keyf(pivot) {
        swap(l, i, j).
        set i to i + 1.
      }
    }
    swap(l, i, hi).
    return i.
  }.

  if low < high {
    local p is partition(lst, low, high).
    quicksort(lst, keyf, low, p - 1).
    quicksort(lst, keyf, p + 1, high).
  }
}

function elementwise1inplace {
  parameter l.
  parameter fcn.

  for i in range(l:length) {
    set l[i] to fcn(l[i]).
  }
}

function elementwise1inplacei {
  parameter l.
  parameter fcn.

  for i in range(l:length) {
    set l[i] to fcn(l[i], i).
  }
}

function elementwise1i {
  parameter l.
  parameter dest.
  parameter fcn.

  for i in range(l:length) {
    set dest[i] to fcn(l[i], i).
  }
}

function elementwise2 {
  parameter a.
  parameter b.
  parameter dest.
  parameter fcn.

  for i in range(dest:length) {
    set dest[i] to fcn(a[i], b[i]).
  }
}

function itemgetter {
  parameter i.
  local f is {
    parameter x.
    return x[i].
  }.
  return f.
}

function genlist {
  parameter n.
  parameter v.
  local l is list().
  until l:length >= n {
    l:add(v).
  }
  return l.
}