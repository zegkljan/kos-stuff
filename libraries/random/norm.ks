@LAZYGLOBAL OFF.

function randNorm {
  parameter mu is 0.
  parameter sigma is 1.
  local u1 is random().
  local u2 is random().

  local mag is sigma * sqrt(-2 * ln(u1)).
  local z0 is mag * cos(u2 * 180) + mu.
  return z0.
}