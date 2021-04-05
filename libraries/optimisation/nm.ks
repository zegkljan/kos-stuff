@LAZYGLOBAL OFF.

loadLib("0:/libraries/utils.ks").

function nm {
  parameter fitness.
  parameter absTolerance.
  parameter maximise.
  parameter lowBound.
  parameter highBound.
  parameter alpha is 1.
  parameter gamma is 2.
  parameter rho is 0.5.
  parameter sigma is 0.5.

  local fit is fitness.
  if maximise {
    set fit to { parameter x. return -fitness(x). }.
  }

  local reflection is {
    parameter x0.
    parameter xn1.
    return x0 + alpha * (x0 - xn1).
  }.
  local expansion is {
    parameter x0.
    parameter xr.
    return x0 + gamma * (xr - x0).
  }.
  local contraction is {
    parameter x0.
    parameter xn1.
    return x0 + rho * (xn1 - x0).
  }.
  local shrinkage is {
    parameter x1.
    parameter xi.
    return x1 + sigma * (xi - x1).
  }.

  // initialise
  local n is lowBound:length.
  local simplex is list().
  for i in range(n + 1) {
    local p is list().
    for j in range(n) {
      p:add(random() * (highBound[j] - lowBound[j]) + lowBound[j]).
    }
    local f is fit(p).
    simplex:add(list(p, f)).
  }

  local centroid is list().
  local reflected is list().
  local expanded is list().
  local contracted is list().
  for i in range(n) {
    centroid:add(0).
    reflected:add(0).
    expanded:add(0).
    contracted:add(0).
  }
  until false {
    // sort simplex
    quicksort(simplex, itemgetter(1)).
    print simplex.

    if simplex[0][1] <= absTolerance {
      return simplex[0][0].
    }

    // find centroid
    for i in range(n) {
      for j in range(n) {
        set centroid[j] to centroid[j] + simplex[i][0][j].
      }
    }
    for i in range(n) {
      set centroid[i] to centroid[i] / n.
    }

    // reflection
    elementwise2(centroid, simplex[n][0], reflected, reflection).
    local fr is fit(reflected).
    if simplex[0][1] <= fr and fr <= simplex[n - 1][1] {
      set simplex[n] to list(reflected:copy(), fr).
    } else {
      // expansion
      if fr <= simplex[0][1] {
        elementwise2(centroid, reflected, expanded, expansion).
        local fe is fit(expanded).
        if fe < fr {
          set simplex[n] to list(expanded:copy(), fe).
        } else {
          set simplex[n] to list(reflected:copy(), fr).
        }
      } else {
        // contraction
        elementwise2(centroid, simplex[n][0], contracted, contraction).
        local fc is fit(contracted).
        if fc < simplex[n][1] {
          set simplex[n] to list(contracted:copy(), fc).
        } else {
          // shrinkage
          for i in range(1, n + 1) {
            elementwise2(simplex[0][0], simplex[i][0], simplex[i][0], shrinkage).
          }
        }
      }
    }
  }
}