import future, os, osproc, strutils, fp.option, fp.list

type
  JVMPath* = tuple[
    root: string,
    lib: string
  ]
  JVMSearchOpts* {.pure.} = enum
    ## JVM search options.
    JavaHome,
    CurrentEnv

proc findJvmInPath(p: string): Option[string] =
  const libs =
    when defined(windows): [
      "bin\\server\\jvm.dll",
      "bin\\client\\jvm.dll",
      "jre\\bin\\server\\jvm.dll",
      "jre\\bin\\client\\jvm.dll"
    ]
    else: [
      "jre/lib/libjvm.so",
      "jre/lib/libjvm.dylib",
      "jre/lib/amd64/jamvm/libjvm.so",
      "jre/lib/amd64/server/libjvm.so"
    ]
  for lib in libs:
    if fileExists(p / lib):
      return (p / lib).some
  return string.none

proc searchInPaths(paths = Nil[string]()): Option[JVMPath] =
  paths.foldLeft(JVMPath.none, (res, p) => (if res.isDefined: res else: p.findJvmInPath.map(lib => (p, lib))))

proc searchInJavaHome: Option[JVMPath] =
  "JAVA_HOME".getEnv.some.notEmpty.flatMap((p: string) => p.findJvmInPath.map(lib => (p, lib)))

proc runJavaProcess: string =
  when nimvm:
    result = staticExec("java -verbose:class -version")
  else:
    result = execProcess("java -verbose:class -version")

proc searchInJavaProcessOutput(data: string): Option[JVMPath] =
  proc getRtJar(s: string): Option[string] =
    if not s.contains("[") or not s.contains("]"):
      string.none
    else:
      let path = s[s.find(" ") + 1 .. s.rfind("]") - 1]
      path.some.notEmpty.filter(p => p.fileExists)

  proc findUsingRtJar(jar: string): Option[JVMPath] =
    let p1 = jar.splitPath[0].splitPath[0]
    searchInPaths([p1, p1.splitPath[0]].asList)

  data.splitLines[0].some.notEmpty
  .flatMap(getRtJar)
  .flatMap(findUsingRtJar)

proc searchInCurrentEnv: Option[JVMPath] =
  searchInJavaProcessOutput(runJavaProcess())

proc findJVM*(opts: set[JVMSearchOpts] = {JVMSearchOpts.JavaHome, JVMSearchOpts.CurrentEnv},
              additionalPaths = Nil[string]()): Option[JVMPath] =
  ## Find the path to JVM. First it tries to find it in ``additionalPaths``,
  ## then it tries the ``JAVA_HOME`` environment variable if ``JVMSearchOpts.JavaHome`` is set in ``opts``,
  ## and at least, it tries to get it calling java executable in the
  ## current environment if ``JVMSearchOpts.CurrentEnv`` is set in ``opts``.
  searchInPaths(additionalPaths)
  .orElse(() => (if JVMSearchOpts.JavaHome in opts: searchInJavaHome() else: JVMPath.none))
  .orElse(() => (if JVMSearchOpts.CurrentEnv in opts: searchInCurrentEnv() else: JVMPath.none))

proc findCtJVM: JVMPath {.compileTime.} =
  let jvmO = findJVM()
  assert jvmO.isDefined, "JVM not found. Please set JAVA_HOME environment variable"
  jvmO.get

const CT_JVM* = findCtJVM() ## Compile time JVM
