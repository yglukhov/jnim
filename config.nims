srcDir        = "src"

import ospaths

const BIN_DIR = "bin"
const BUILD_DIR = "build"

template dep(name: untyped): untyped =
  exec "nim " & astToStr(name)

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

  --threads: on
    
  --NimblePath: src
  --NimblePath: srcDir
    
  setCommand "c", src

proc test(name: string) =
  if not BIN_DIR.dirExists:
    BIN_DIR.mkDir
  --run
  buildExe true, "bin" / "test_" & name, "tests" / "test_" & name 

proc javac(file: string, outDir: string) =
  exec "javac".toExe & " -d " & outDir & " -cp " & outDir & " " & file

task int_test_bootstrap, "Prepare test environment":
  BUILD_DIR.mkDir
  javac "src/support/io/github/vegansk/jnim/NativeInvocationHandler.java", BUILD_DIR

  javac "tests/java/TestClass.java", BUILD_DIR
  javac "tests/java/ConstructorTestClass.java", BUILD_DIR
  javac "tests/java/MethodTestClass.java", BUILD_DIR
  javac "tests/java/PropsTestClass.java", BUILD_DIR
  javac "tests/java/InnerTestClass.java", BUILD_DIR
  javac "tests/java/ExceptionTestClass.java", BUILD_DIR
  javac "tests/java/GenericsTestClass.java", BUILD_DIR
  javac "tests/java/BaseClass.java", BUILD_DIR
  javac "tests/java/ChildClass.java", BUILD_DIR
  javac "tests/java/ExportTestClass.java", BUILD_DIR

task test, "Run all tests":
  dep int_test_bootstrap
  test "all"

task test_jvm_finder, "Run jvm_finder test":
  dep int_test_bootstrap
  test "jvm_finder"

task test_jni_wrapper, "Run jni_wrapper test":
  dep int_test_bootstrap
  test "jni_wrapper"

task test_jni_api, "Run jni_api test":
  dep int_test_bootstrap
  test "jni_api"

task test_jni_generator, "Run jni_api test":
  dep int_test_bootstrap
  test "jni_generator"

task test_jni_export, "Run jni_export test":
  dep int_test_bootstrap
  test "jni_export"

task test_java_lang, "Run java.lang test":
  dep int_test_bootstrap
  test "java_lang"

task test_java_util, "Run java.util test":
  dep int_test_bootstrap
  test "java_util"

task example, "Run example":
  test "example"
