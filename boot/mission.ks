@LAZYGLOBAL OFF.

{
  CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
  set terminal:width to 50.
  set terminal:height to 31.
  // pre-wait
  wait 10.
  print "BOOTING".
  // copy and run loadlib
  copypath("archive:/system/loadlib.ks", "1:/loadlib.ks").
  runoncepath("1:/loadlib.ks").

  // copy and run mission
  copypath("archive:/missions/" + shipname + ".ks", "1:/__.ks").
  runoncepath("1:/__.ks").
  
  print "Finished booting.".
  // wait 5 seconds
  from { local t is 5. } until t = 0 step { set t to t - 1. } do {
    print "Waiting " + t + " s ...".
    wait 1.
  }
  // start the mission
  print "Starting mission.".
  mission().
}