import os, osproc, strutils, options

type
  JVMPath* = tuple[
    root: string,
    lib: string
  ]
  JVMSearchOpts* {.pure.} = enum
    ## JVM search options.
    JavaHome,
    CurrentEnv

proc findJvmInPath(p: string): string =
  const libs = [
      # Windows
      "bin\\server\\jvm.dll",
      "bin\\client\\jvm.dll",
      "jre\\bin\\server\\jvm.dll",
      "jre\\bin\\client\\jvm.dll",
      # *nix
      "jre/lib/libjvm.so",
      "jre/lib/libjvm.dylib",
      "jre/lib/amd64/jamvm/libjvm.so",
      "jre/lib/amd64/server/libjvm.so",
      "lib/server/libjvm.so"
    ]
  for lib in libs:
    let lp = p / lib
    if fileExists(lp):
      return lp

proc searchInPaths(paths: openarray[string]): Option[JVMPath] =
  for p in paths:
    let lp = findJvmInPath(p)
    if lp.len != 0:
      return (root: p, lib: lp).some

proc searchInJavaHome: Option[JVMPath] =
  when defined(android):
    ## Hack for Kindle fire.
    return (root:"", lib: "/system/lib/libdvm.so").some
  else:
    var p = getEnv("JAVA_HOME")
    var lib: string
    if p.len != 0:
      lib = findJvmInPath(p)

    if lib.len == 0:
      p = "/usr/lib/jvm/default/"
      lib = findJvmInPath(p)

    if lib.len != 0:
      return (root: p, lib: lib).some

proc runJavaProcess: string =
  when nimvm:
    result = staticExec("java -verbose:class -version")
  else:
    result = execProcess("java -verbose:class -version")

proc searchInJavaProcessOutput(data: string): Option[JVMPath] =
  proc getRtJar(s: string): string =
    if s.startsWith("[Opened ") and s.contains("]"):
      let path = s[s.find(" ") + 1 .. s.rfind("]") - 1]
      if fileExists(path): return path
    else:
      const prefix = "[info][class,load] opened: "
      let i = s.find(prefix)
      if i != -1:
        let path = s[i + prefix.len .. ^1]
        if fileExists(path): return path

  proc findUsingRtJar(jar: string): Option[JVMPath] =
    let p1 = jar.splitPath[0].splitPath[0]
    when defined(macosx):
      if p1.endsWith("/Contents/Home/jre"):
        # Assume MacOS. MacOS may not have libjvm, and jvm is loaded in a
        # different way, so just return java home here.
        return (root: p1.parentDir, lib: "").some
      elif p1.endsWith("/Contents/Home"):
        # ditto
        return (root: p1, lib: "").some

    searchInPaths([p1, p1.splitPath[0]])

  for s in data.splitLines:
    let jar = getRtJar(s)
    if jar.len != 0:
      result = findUsingRtJar(jar)
      if result.isSome: return

proc searchInCurrentEnv: Option[JVMPath] =
  searchInJavaProcessOutput(runJavaProcess())

proc findJVM*(opts: set[JVMSearchOpts] = {JVMSearchOpts.JavaHome, JVMSearchOpts.CurrentEnv},
              additionalPaths: openarray[string] = []): Option[JVMPath] =
  ## Find the path to JVM. First it tries to find it in ``additionalPaths``,
  ## then it tries the ``JAVA_HOME`` environment variable if ``JVMSearchOpts.JavaHome`` is set in ``opts``,
  ## and at least, it tries to get it calling java executable in the
  ## current environment if ``JVMSearchOpts.CurrentEnv`` is set in ``opts``.
  result = searchInPaths(additionalPaths)
  if not result.isSome:
    if JVMSearchOpts.JavaHome in opts:
      result = searchInJavaHome()
    if not result.isSome and JVMSearchOpts.CurrentEnv in opts:
      result = searchInCurrentEnv()
