set ship:control:pilotmainthrottle to 0.
lock throttle to 1.
// wait until we are at Tylo
wait until ship:body = Tylo.
clearscreen.
lock steering to heading(0, 90).
// wait for burn start
local t0 is time:seconds.
local t is time:seconds.
local start is 18.87.
local end is 27.08.
until t - t0 >= start {
  print "Suicide burn start countdown: " + (start - (t - t0)) at(0, 1).
  wait 0.
  set t to time:seconds.
}
// ignite the engine
stage.
// wait for burn end
until t - t0 >= end {
  print "Suicide burn end countdown: " + (end - (t - t0)) at(0, 2).
  wait 0.
  set t to time:seconds.
}
// shut down the engine
lock throttle to 0.