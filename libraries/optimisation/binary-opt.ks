@LAZYGLOBAL OFF.

loadLib("0:/libraries/utils.ks").

function binaryOpt {
  parameter f.
  parameter absTolerance.
  parameter lb.
  parameter ub.
  parameter deadline is -1.
  parameter verbose is false.
  
  local x is 0.

  until deadline > 0 and time:seconds >= deadline {
    set x to (lb + ub) / 2.
    local y is f(x).
    if verbose {
      print "ub: " + ub + " lb: " + lb + " x: " + x + " y: " + y.
    }
    if abs(y) <= absTolerance {
      return list(x, false).
    }
    if y < 0 {
      set lb to x.
    } else {
      set ub to x.
    }
  }
  return list(x, true).
}