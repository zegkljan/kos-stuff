@LAZYGLOBAL OFF.

loadLib("0:/libraries/manoeuvers.ks").
loadLib("0:/libraries/math.ks").
loadLib("0:/libraries/optimisation/binary-opt.ks").

function mission {
  set terminal:width to 50.

  // launch
  launchToOrbit().

  // post-launch bookkeeping
  print "Post-launch sequence:".
  print "- unfolding panels...".
  wait 1.
  panels on.
  wait 10.
  print "      done.".
  //print "- activating antenna..."
  //antenna:getmodule("ModuleRTAntenna"):doevent("activate").
  print "Post-lanuch sequence complete.".
  wait 5.

  // wait one orbit back to apoapsis
  print "Warping for 1 orbit.".
  warpto(time:seconds + ship:orbit:period).
  wait ship:orbit:period.

  // deorbit
  
  print "Deorbiting sequence:".
  // calculate deorbit maneouvre
  local correction is 58 + 0/60 + 0/3600.
  print "- calculating deorbit maneouvre...".
  local deorbit is calculateDeorbit(-(74 + 33/60 + 27/3600) + correction, 30000).
  local deorbitTime is deorbit["time"].
  local deorbitDv is deorbit["dv"].
  local deorbitBurnTime is deorbit["burn-time"].
  add node(deorbitTime, 0, 0, -deorbitDv).
  
  print "    solution:".
  print "      ETA: " + (deorbitTime - time:seconds).
  print "       dv: " + deorbitDv.
  print "       tb: " + deorbitBurnTime.
  print "- steering to burn vector...".
  local burnvector is -velocityat(ship, deorbitTime):orbit:normalized.
  steerToAngle(burnvector, 0.1, 5).
  lock steering to burnvector.

  print "- warping to 1 min before deorbit burn".
  warpto(deorbitTime - 30).
  when time:seconds >= deorbitTime - 30 then {
    kuniverse:timewarp:cancelwarp().
  }
  wait until time:seconds >= deorbitTime - 30.
  print "- steering to retrograde...".
  steerToAngle(retrograde:forevector, 1, 5).
  lock steering to retrograde:forevector.
  print "- waiting for burn start...".
  wait deorbitTime - time:seconds - deorbitBurnTime / 2.
  print "- firing engine...".
  lock throttle to 1.
  wait deorbitBurnTime.
  lock throttle to 0.
  remove nextNode.
  wait 1.
  print "- ditching engine...".
  stage.
  wait 3.
  print "- pre-steering to surface retrograde...".
  local res is binaryOpt({
    parameter x. return 70000 - ship:body:altitudeof(positionat(ship, x)).
  }, 100, time:seconds, time:seconds + eta:periapsis, time:seconds + 5, false).
  steerToAngle(-velocityAt(ship, res[0]):surface, 1, 10).
  print "- waiting for reentry...".
  wait 5.
  warpto(time:seconds + eta:periapsis).
  wait until ship:altitude <= 72000.
  kuniverse:timewarp:cancelwarp().
  wait 2.
  print "- closing panels...".
  panels off.
  wait 1.
  print "- steering to surface retrograde...".
  lock steering to srfRetrograde.
  wait 5.
  print "- arming parachute...".
  wait 1.
  when not chutessafe then {
    chutessafe on.
    if not chutes {
      return true.
    }
    wait 1.
    unlock all.
  }
  wait 1.
  print "Deorbit sequence complete. Waiting to land.".
  wait 5.
  CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Close Terminal").
  wait until false.
}

function launchToOrbit {
  //local antenna is ship:partstagged("omni-antenna")[0].
    
  local aeroSafe is 40000.
  local atmoSafe is 71000.
  local targetOrbit is 80000.
  local inclination is 0.
  local hdg is 90 - inclination.
  local twr is 1.3.
  local twrMin is 1.4.
  local twrMax is 3.0.
  local preQmaxTwrMax is 1.6.
  local targetQmax is 0.20.

  takeoff(hdg).

  when ship:altitude > aeroSafe then {
    print "aero safe at " + aeroSafe.
    toggle ag1.
  }

  local Qmax is 0.
  local hitQmax is false.
  until ship:apoapsis > targetOrbit {
    clearscreen.
    checkStaging().
    local avThr is ship:availablethrust.
    local alt is ship:altitude.
    local ap is ship:apoapsis.
    local m is ship:mass.
    local q is ship:q.


    local altRatio is (1 - alt / targetOrbit).
    local apRatio is (1 - ap / targetOrbit).
    local effectiveRatio is pow(mean(altRatio, apRatio), 2).
    local pitch is max(3, effectiveRatio * 90).
    local currentTwr is ((avThr * throttle) / m / 10).
    if Qmax < q {
      set Qmax to q.
    }
    if q < Qmax {
      if not hitQmax {
        set twrMin to currentTwr.
        set hitQmax to true.
      }
      local qpart is pow(1 - q / Qmax, 1).
      local pitchpart is (1 - effectiveRatio).
      print "Q twr ratio:     " + qpart.
      print "Pitch twr ratio: " + pitchpart.
      set twr to twrMin + (twrMax - twrMin) * (qpart * pitchpart).
    } else {
      set twr to twrMin + (preQmaxTwrMax - twrMin) * (1 - q / targetQmax).
    }
    local thr is 10 * m * twr / avThr.
    lock throttle to thr.
    lock steering to heading(hdg, pitch).
    print "Mass: " + m.
    print "Available thrust: " + avThr.
    print "Current thrust: " + (avThr * throttle).
    print "Current TWR: " + currentTwr.
    print "Q:    " + q.
    print "Qmax: " + Qmax.
    print "Altitude ratio:  " + altRatio.
    print "Ap ratio:        " + apRatio.
    print "Effective ratio: " + effectiveRatio.
    print "Altitude: " + alt.
    print "Pitch: " + pitch.
    wait 0.1.
  }
  print "apoapsis set".

  lock throttle to 0.
  lock steering to prograde.
  wait until ship:altitude > atmoSafe.
  kuniverse:timewarp:cancelwarp().

  wait 5.
  circularizeAtAp().
  wait 5.
  unlock steering.
}

function calculateDeorbit {
  parameter targetLng.
  parameter targetPe.
  
  local tz is time:seconds.
  
  local engs is list().
  list engines in engs.
  local dv is velocityAt(ship, time + eta:apoapsis):orbit:mag - orbitalSpeedAtAp(orbit:apoapsis, targetPe, orbit:body:radius, orbit:body:mu).
  local burnTime is dvTime(dv, engs[0]:availablethrust, ship:mass, engs[0]:isp).
  local hp is orbitalPeriod(orbit:apoapsis, targetPe, orbit:body:radius, orbit:body:mu) / 2.
  local op is ship:orbit:period.

  local apLng is targetLng.
  if apLng < 0 {
    set apLng to apLng + 180.
  } else {
    set apLng to apLng - 180.
  }
  set apLng to apLng + 360 / orbit:body:rotationperiod * hp.
  if apLng > 180 {
    set apLng to apLng - 360.
  }

  local ff is {
    parameter targ.
    parameter t0.
    parameter delay.

    local tmin is t0 + delay.
    local tminLng is ship:body:geoPositionOf(positionAt(ship, tmin)):lng. 
    local vr is 360 / ship:body:rotationperiod.
    local offset is tminLng - vr * (tmin - t0).
    if offset < -180 {
      set offset to offset + 360.
    }
    print "offset: " + offset.

    print "targ: " + targ.
    if targ - offset < 0 {
      set targ to targ + 360.
    }
    print "adj. targ: " + targ.

    local f to {
      parameter t.

      local rotDiff is vr * (t - t0).

      local y is ship:body:geoPositionOf(positionAt(ship, t)):lng.

      if t = tmin {
        set y to tminLng.
      }

      set y to y - rotDiff.
      local y1 to y.
      if y1 < -180 {
        set y1 to y + 360.
      }
      
      local y2 to y - offset.

      local y3 is y2.
      if y2 < 0 {
        set y3 to y2 + 360.
      }

      local y4 is y3 + offset.
      local y5 is y4 - targ.

      //print "t: " + floor(t, 1) + "; y: " + y + "; y1: " + y1 + "; y2: " + y2 + "; y3: " + y3 + "; y4: " + y4 + "; y5: " + y5.
      return y5.
    }.
    return f.
  }.
  local f is ff(apLng, tz, 60).
  if f(tz + 60 + op) < 0 {
    set f to ff(targetLng, tz, 60 + op / 2 + 1).
  }

  print "apLng: " + apLng.
  local res is binaryOpt(f, 0.3, tz + 60, tz + 60 + op - 1, time:seconds + 1).
  
  local deTime is res[0].
  return lexicon("time", deTime, "dv", dv, "burn-time", burnTime).
}

function checkStaging {
  if ship:maxthrust < 0.1 {
    lock throttle to 0.
    stage.
    wait 0.5.
  }
}

function relsum {
  parameter a.
  parameter b.
  return (a + b) / (1 + a * b).
}

function mean {
  parameter a.
  parameter b.
  return (a + b) / 2.
}
