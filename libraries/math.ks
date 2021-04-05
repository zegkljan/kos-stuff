@LAZYGLOBAL OFF.

// meaning of 'precision': the returned answer should be base^x, where
//                         x is in [power-precision/2,power+precision/2]
function _pow {
   parameter base.
   parameter power.
   parameter precision.
   if power < 0 {
       return 1 / _pow(base, -power, precision).
   }
   if power >= 10 {
       local tmp is _pow(base, power / 2, precision / 2).
       return tmp * tmp.
   }
   if power >= 1 {
       return base * _pow(base, power - 1, precision).
   }
   if precision >= 1 {
       return sqrt(base).
   }
   return sqrt(_pow(base, power * 2, precision * 2)).
}

function pow {
    parameter base.
    parameter power.

    local out is base.
    if power = round(power) {
        from {local i is 1.} until i >= power step {set i to i + 1.} do {
            set out to out * base.
        }
        return out.
    }

    return _pow(base, power, .0001).
}

function boundNorm {
  parameter x.
  parameter lb.
  parameter ub.

  local d is ub - lb.
  local i is 0.
  if x < lb {
    until x + i * d >= lb {
      set i to i + 1.
    }
    return x + i * d.
  } else if x >= ub {
    until x - i * d < ub {
      set i to i + 1.
    }
    return x - i * d.
  }
  return x.
}