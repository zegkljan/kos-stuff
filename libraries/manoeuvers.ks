@LAZYGLOBAL OFF.

// Takes the vessel off the launchpad.
// Assumes the 1st stage is the launchpad clamp, 2nd stage is the main engine.
function takeoff {
  parameter hdg is 90.

  set ship:control:pilotmainthrottle to 0.
  set throttle to 1.
  lock steering to heading(hdg, 90).
  print "ignite stage 1".
  stage.
  wait 1.
  print "ignite stage 2".
  stage.
}

// Calculates the time of burn given the required dv, thrust, initial mass and engine Isp.
function dvTime {
  parameter dv.
  parameter f.
  parameter m0.
  parameter isp.

  local g is Kerbin:mu / (Kerbin:radius ^ 2).

  return g * m0 * isp * (1 - constant:e ^ (-dv / (g * isp))) / f.
}

// Calculates the available dv given initial mass, dry mass and engine Isp.
function dvLeft {
  parameter m0.
  parameter mf.
  parameter isp.

  local g is Kerbin:mu / (Kerbin:radius ^ 2).

  return isp * g * ln(m0 / mf).
}

// Calculates equivalent combined Isp of ignited engines.
function combinedIsp {
  local engs is list().
  list engines in engs.
  local nom is 0.
  local den is 0.
  for eng in engs {
    if eng:ignition {
      set nom to nom + eng:availablethrust * 1000.
      set den to den + eng:availablethrust * 1000 / eng:isp.
    }
  }
  return nom / den.
}

// Calculates the equivalent combined force of ignited engines.
function combinedForce {
  local engs is list().
  list engines in engs.
  local tot is 0.
  for eng in engs {
    if eng:ignition {
      set tot to tot + eng:availablethrust * 1000.
    }
  }
  return tot.
}

function orbitalSpeedAtAp {
  parameter ap.
  parameter pe.
  parameter bodyR.
  parameter bodyMu.

  if ap = pe {
    return sqrt(bodyMu / (ap + bodyR)).
  }

  return sqrt(bodyMu * (2 / (bodyR + ap) - 1 / (bodyR + (ap + pe) / 2))).
}

function orbitalPeriod {
  parameter ap.
  parameter pe.
  parameter bodyR.
  parameter bodyMu.

  local a is bodyR + (ap + pe) / 2.

  return 2 * constant:pi * sqrt(a * a * a / bodyMu).
}

function timeOfFlight {
  parameter ap.
  parameter pe.
  parameter th0.
  parameter th1.
  parameter bodyR.
  parameter bodyMu.

  local e is (ap - pe) / (ap + pe + 2 * bodyR).
  local eccE0 is constant:degtorad * 2 * arctan(sqrt((1 - e) / (1 + e)) * tan(constant:radtodeg * th0 / 2)).
  local eccE1 is constant:degtorad * 2 * arctan(sqrt((1 - e) / (1 + e)) * tan(constant:radtodeg * th1 / 2)).
  local m0 is eccE0 - e * sin(constant:radtodeg * eccE0).
  local m1 is eccE0 - e * sin(constant:radtodeg * eccE1).
  local dm is m1 - m0.
  local a is bodyR + (ap + pe) / 2.
  local n is sqrt(bodyMu / (a * a * a)).
  local dt is dm / n.
  return dt.
}

// Circularizes the orbit at apoapsis.
// Includes time warp to apoapsis and steering to prograde.
function circularizeAtAp {
  clearscreen.
  print "Apoapsis circularisation sequence:".
  print "- calculating burn parameters".
  local ap is ship:obt:apoapsis.
  local apVel is velocityat(ship, time + eta:apoapsis):orbit.
  local circVel is orbitalSpeedAtAp(ap, ap, ship:body:radius, ship:body:mu).
  
  print "    v at Ap: " + apVel:mag.
  print "    solution:".
  print "      circular v at Ap: " + circVel.

  local dv is circVel - apVel:mag.
  local mTime is dvTime(dv, combinedForce(), ship:mass * 1000, combinedIsp()).
  print "      required dv: " + dv.
  print "      est. burn t: " + mTime.

  print "- steering to burn vector".
  steerToAngle(velocityat(ship, time + eta:apoapsis - mTime / 2):orbit, 0.3, 3).
  print "- waiting for burn start".
  warpto(time:seconds + eta:apoapsis - mTime).
  wait until eta:apoapsis <= mTime.
  kuniverse:timewarp:cancelwarp().
  lock steering to prograde.
  wait until eta:apoapsis <= mTime / 2.
  print "- starting burn".
  lock throttle to 1.
  wait mTime.
  lock throttle to 0.
  print "- burn done".
  wait 1.
  print "Circularisation complete.".
}

// Circularizes the orbit at periapsis.
// Includes time warp to periapsis and steering to retrograde.
function circularizeAtPe {
  clearscreen.
  print "At apoapsis, raising periapsis...".

  local pe is ship:obt:periapsis.
  local peVel is velocityat(ship, time + eta:periapsis):orbit:mag.
  local circVel is sqrt(ship:body:mu / (pe + ship:body:radius)).
  print "Velocity at Pe: " + peVel.
  print "Circular velocity at Pe: " + circVel.

  local dv is peVel - circVel.
  local mTime is dvTime(dv, combinedForce(), ship:mass * 1000, combinedIsp()).
  print "Required dV: " + dv.
  print "Est. burn time: " + mTime.

  lock steering to retrograde.
  warpto(time:seconds + eta:apoapsis - mTime).
  wait until eta:periapsis <= mTime / 2.
  lock throttle to 1.
  wait mTime.
  lock throttle to 0.
  print "Circularized.".
}

// Steers the ship to the given vector and waits for it to be within the given tolerance (in degrees) for the given holdonTime (in seconds).
function steerToAngle {
  parameter vector.
  parameter tolerance.
  parameter holdonTime.
  lock steering to vector.
  local t is time:seconds.
  until time:seconds >= t + holdonTime {
    wait 0.1.
    if vang(ship:facing:forevector, vector) > tolerance {
      set t to time:seconds.
    }
  }
}