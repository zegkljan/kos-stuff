@LAZYGLOBAL OFF.

loadLib("0:/libraries/utils.ks").
loadLib("0:/libraries/random/norm.ks").

function greedyLS {
  parameter fitness.
  parameter absTolerance.
  parameter maximise.
  parameter lbs.
  parameter ubs.
  parameter deadline is -1.
  
  local sigmas is list().
  for i in range(lbs:length) {
    sigmas:add((ubs[i] - lbs[i]) / 10).
  }
  local improvedMult is 1.01.
  local failedMult is 0.99.

  local fit is fitness.
  if maximise {
    set fit to { parameter x. return -fitness(x). }.
  }

  // initialise
  local p is list().
  for i in range(lbs:length) {
    p:add(random() * (ubs[i] - lbs[i]) + lbs[i]).
  }
  local fp is fit(p).
  local q is p:copy().
  
  // search
  local timeout is false.
  until fp <= absTolerance {
    if deadline > 0 and time:seconds >= deadline {
      set timeout to true.
      break.
    }
    elementwise1i(p, q, {
      parameter x.
      parameter i.
      local rnd is randNorm() * sigmas[i].
      set x to x + rnd.
      if x > ubs[i] {
        set x to ubs[i].
      } else if x < lbs[i] {
        set x to lbs[i].
      }
      return x.
    }).
    local fq is fit(q).
    if fq < fp {
      set p to q:copy().
      set fp to fq.
      elementwise1inplace(sigmas, { parameter x. return x * improvedMult. }).
    } else {
      elementwise1inplace(sigmas, { parameter x. return x * failedMult. }).
    }
  }
  return list(p, timeout).
}