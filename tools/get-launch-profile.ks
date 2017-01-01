@LAZYGLOBAL OFF.

function getWetMass {
  //return SHIP:MASS.
  return 11.3.
}

function getOrbitDryMass {
  //return SHIP:DRYMASS.
  return 1.3.
}

function getG {
  return 9.81e-3.
}

function getR {
  return SHIP:BODY:RADIUS / 1.0e3.
}

function getIsp {
  local engine is SHIP:partstagged("e0")[0].
  return 1.0 * engine:slisp.
}

function getFmax {
  local engine is SHIP:partstagged("e0")[0].
  return engine:maxthrust / 1.0e3.
}

function getDragCoeff {
  return 0.021.
}

function getRefArea {
  return 1.
}

function getScaleHeight {
  return 5.6.
}

function getAtmDensity {
  return SHIP:BODY:ATM:SEALEVELPRESSURE * 1.2230948554874.
}

{
  print "Gathering data for gravity turn computation.".
  local data is lexicon().
  set data:case to true.
  data:add("m0", getWetMass()).
  data:add("m1", getOrbitDryMass()).
  data:add("g0", getG()).
  data:add("r0", getR()).
  data:add("Isp", getIsp()).
  data:add("Fmax", getFmax()).
  data:add("cd", getDragCoeff()).
  data:add("A", getRefArea()).
  data:add("H", getScaleHeight()).
  data:add("rho", getAtmDensity()).
  data:add("h_obj", 75).
  data:add("v_obj", 2.278).
  data:add("q_obj", 0.5 * CONSTANT:PI).
  print "Data:".
  print data.

  print "Creating lock file.".
  create("archive:/launch-profiles/kostest/input.lock").
  print "Writing data.".
  writejson(data, "archive:/launch-profiles/kostest/input.json").
  print "Data written, removing lock file.".
  deletepath("archive:/launch-profiles/kostest/input.lock").
  print "Waiting for gravity turn profile...".
  until exists("archive:/launch-profiles/kostest/output.json") and not exists("archive:/launch-profiles/kostest/output.lock") {
    wait 5.
  }
  print "Gravity turn data computed, loading it.".
  local gturn is readjson("archive:/launch-profiles/kostest/output.json").
  print gturn.
}.
