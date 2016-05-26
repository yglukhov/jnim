version       = "0.1.0"
author        = "Anatoly Galiulin"
description   = "Java bridge for Nim"
license       = "MIT"
srcDir        = "src"

requires "nim >= 0.13.1", "nimfp >= 0.1.0"

import ospaths

const BIN_DIR = "bin"
const BUILD_DIR = "build"

proc buildExe(debug: bool, bin: string, src: string) =
  switch("out", (thisDir() & "/" & bin).toExe)
  switch("nimcache", BUILD_DIR)
  if not debug:
    --forceBuild
    --define: release
    --opt: size
  else:
    --define: debug
    --debuginfo
    --debugger: native
    --linedir: on
    --stacktrace: on
    --linetrace: on
    --verbosity: 1
    
  --NimblePath: src
  --NimblePath: srcDir
    
  setCommand "c", src

proc test(name: string) =
  if not BIN_DIR.dirExists:
    BIN_DIR.mkDir
  --run
  buildExe true, "bin" / "test_" & name, "tests" / "test_" & name 

task test, "Run all tests":
  test "all"

task test_jbridge, "Run jbridge test":
  test "jbridge"

task test_jni_wrapper, "Run jni_wrapper test":
  test "jni_wrapper"

task test_jni_api, "Run jni_api test":
  test "jni_api"
