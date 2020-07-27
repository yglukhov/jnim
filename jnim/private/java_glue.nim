import sets

const jnimPackageName* {.strdefine.} = "io.github.yglukhov.jnim"

const
  jnimGlue {.strdefine.} = "Jnim.java"
  FinalizerName* = "_0" # Private, don't use

var
  javaGlue {.compileTime.} = newStringOfCap(1000000)
  existingImports {.compileTime.} = initSet[string]()
  classCursor {.compileTime.} = 0
  importCursor {.compileTime.} = 0

proc initGlueIfNeeded() =
  if classCursor == 0:
    javaGlue = "package " & jnimPackageName & ";\n"
    importCursor = javaGlue.len
    javaGlue &= """
public class Jnim {
public interface __NimObject {}
public static native void """ & FinalizerName & """(long p);
"""
    classCursor = javaGlue.len
    javaGlue &= "}\n"

proc emitGlueImportsP*(imports: openarray[string]) {.compileTime.} =
  var newImports = newStringOfCap(10000)
  for s in imports:
    if s.len != 0 and s notin existingImports:
      existingImports.incl(s)
      newImports &= "import "
      newImports &= s
      newImports &= ";\n"

  if newImports.len != 0:
    initGlueIfNeeded()
    javaGlue.insert(newImports, importCursor)
    importCursor += newImports.len
    classCursor += newImports.len

proc emitGlueClassP*(classDef: string) {.compileTime.} =
  initGlueIfNeeded()
  javaGlue.insert(classDef, classCursor)
  classCursor += classDef.len

proc flushGlueP*() {.compileTime.} = writeFile(jnimGlue, javaGlue)
macro emitGlueImports*(imports: static varargs[string]): untyped = emitGlueImportsP(imports)
macro emitGlueClass*(classCode: static[string]): untyped = emitGlueClassP(classCode)
macro flushGlue*(): untyped = flushGlueP()
macro debugPrintJavaGlue*(): untyped {.deprecated.} = echo javaGlue
