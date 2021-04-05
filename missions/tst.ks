@LAZYGLOBAL OFF.

loadLib("0:/libraries/math.ks").
loadLib("0:/libraries/optimisation/binary-opt.ks").

function mission {
  print "*******************".
  print "*******************".
  print "*******************".
  wait 1.

  local f is {
    parameter x.
    return x.
  }.
  print binaryOpt(f, 0, 0.1, -100, 200, time:seconds + 10).
  wait until false.

  until false {
    print "****************************************************".
    print "ship:orbit: " + ship:orbit.
    print "ship:orbit:apoapsis: " + ship:orbit:apoapsis.
    print "ship:orbit:argumentofperiapsis: " + ship:orbit:argumentofperiapsis.
    print "ship:orbit:body: " + ship:orbit:body.
    print "ship:orbit:eccentricity: " + ship:orbit:eccentricity.
    print "ship:orbit:epoch: " + ship:orbit:epoch.
    print "ship:orbit:hasnextpatch: " + ship:orbit:hasnextpatch.
    print "ship:orbit:inclination: " + ship:orbit:inclination.
    print "ship:orbit:lan: " + ship:orbit:lan.
    print "ship:orbit:longitudeofascendingnode: " + ship:orbit:longitudeofascendingnode.
    print "ship:orbit:meananomalyatepoch: " + ship:orbit:meananomalyatepoch.
    print "ship:orbit:name: " + ship:orbit:name.
    print "ship:orbit:periapsis: " + ship:orbit:periapsis.
    print "ship:orbit:period: " + ship:orbit:period.
    print "ship:orbit:position: " + ship:orbit:position.
    print "ship:orbit:rstatevector: " + ship:orbit:rstatevector.
    print "ship:orbit:semimajoraxis: " + ship:orbit:semimajoraxis.
    print "ship:orbit:semiminoraxis: " + ship:orbit:semiminoraxis.
    print "ship:orbit:tostring: " + ship:orbit:tostring.
    print "ship:orbit:transition: " + ship:orbit:transition.
    print "ship:orbit:trueanomaly: " + ship:orbit:trueanomaly.
    print "ship:orbit:vstatevector: " + ship:orbit:vstatevector.
    print "****************************************************".
    print "ship:orbit:body:latitude: " + ship:orbit:body:latitude.
    print "ship:orbit:body:longitude: " + ship:orbit:body:longitude.
    print "ship:orbit:body:rotationangle: " + ship:orbit:body:rotationangle.
    print "ship:orbit:body:rotationperiod: " + ship:orbit:body:rotationperiod.
    print "****************************************************".
    print "ship:angularvel: " + ship:angularvel.
    print "ship:geoposition: " + ship:geoposition.
    print "ship:latitude: " + ship:latitude.
    print "ship:longitude: " + ship:longitude.
    print "****************************************************".
    print ship:orbit:lan - ship:body:rotationangle + ship:orbit:trueanomaly + ship:orbit:argumentofperiapsis.
    print "****************************************************".
    wait 1.
  }
}