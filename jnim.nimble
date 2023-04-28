# Package

version       = "0.5.3"
author        = "Anatoly Galiulin, Yuriy Glukhov"
description   = "Java bridge for Nim"
license       = "MIT"

# Dependencies

requires "nim >= 0.19"

from os import `/`

const BIN_DIR = "bin"
const BUILD_DIR = "build"

proc compileJava() =
  BUILD_DIR.mkDir
  var cmd = "javac".toExe & " -d " & BUILD_DIR
  for f in [
      "TestClass",
      "ConstructorTestClass",
      "MethodTestClass",
      "PropsTestClass",
      "InnerTestClass",
      "ExceptionTestClass",
      "GenericsTestClass",
      "BaseClass",
      "ChildClass",
      "ExportTestClass" ]:
    cmd &= " tests/java/" & f & ".java"

  if fileExists("Jnim.java"):
    cmd &= " Jnim.java"
  cmd &= " jnim/support/io/github/vegansk/jnim/NativeInvocationHandler.java"
  exec cmd

proc test(name: string, flags = "") =
  let outFile = BIN_DIR / "test_" & name
  rmFile("Jnim.java")
  exec "nim c " & flags & " --passC:-g --threads:on -d:nimEmulateOverflowChecks -d:jnimGlue=Jnim.java --out:" & outFile & " tests/test_" & name
  compileJava()
  exec outFile

task test, "Run all tests":
  test "all", "--mm:orc"
  test "all", "--mm:refc"

task test_jvm_finder, "Run jvm_finder test":
  test "jvm_finder"

task test_jni_wrapper, "Run jni_wrapper test":
  test "jni_wrapper"

task test_jni_api, "Run jni_api test":
  test "jni_api"

task test_jni_generator, "Run jni_api test":
  test "jni_generator"

task test_jni_export, "Run jni_export test":
  test "jni_export"

task test_jni_export_old, "Run jni_export_old test":
  test "jni_export_old"

task test_java_lang, "Run java.lang test":
  test "java_lang"

task test_java_util, "Run java.util test":
  test "java_util"

task example, "Run example":
  test "example"
