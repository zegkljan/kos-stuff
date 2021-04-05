@LAZYGLOBAL OFF.

declare global loadedLibs to uniqueSet().

function loadLib {
  parameter lib.
  parameter libDir is "1:/libs".

  set lib to path(lib).
  set libDir to path(libDir).

  if loadedLibs:contains(lib) {
    print "Skipping reimport of " + lib.
    return.
  }

  // print "loadLib:  lib = " + lib.
  // print "loadLib:  libDir = " + libDir.

  local localLib is libDir:combine(lib:name).

  // check if the source file exists
  if not exists(lib) {
    print "loadLib:  ERROR - source file does not exist!".
    local x is 1 / 0.
  }

  // copy library to local
  // print "loadLib:  Copying " + lib + " to " + localLib + "...".
  copypath(lib, localLib).

  // check if the copied file exists
  if not exists(localLib) {
    print "Local file '" + localLib + "' does not exist.".
    local x is 1 / 0.
  }

  // run the libraries to import the functions
  print "''Importing'' " + localLib.
  runoncepath(localLib).

  // store library as loaded
  loadedLibs:add(lib).
}