import macros, tables, sets, jni_wrapper, jni_api

type MethodDescr = object
  name: string
  retType: string
  argTypes: seq[string]

proc initMethodDescr(name, retType: string, argTypes: seq[string]): MethodDescr =
  result.name = name
  result.retType = retType
  result.argTypes = argTypes

proc toWords(a: NimNode, res: var seq[string]) =
  case a.kind
  of nnkArgList:
    var i = 0
    while i < a.len and a[i].kind in {nnkCommand, nnkIdent, nnkInfix}:
      toWords(a[i], res)
      inc i
  of nnkCommand:
    for n in a:
      toWords(n, res)
  of nnkIdent:
    res.add($a)
  of nnkInfix:
    a[0].expectKind(nnkIdent)
    a[1].expectKind(nnkIdent)
    assert($a[0] == "*")
    res.add($a[1] & "*")
    toWords(a[2], res)
  else:
    echo "Enexpected node: ", repr(a)
    doAssert(false)

proc extractArguments(a: NimNode): tuple[className, parentClass: string, interfaces: seq[string], body: NimNode, isPublic: bool] =
  var words: seq[string]
  a.toWords(words)
  var state: range[0 .. 4]
  for w in words:
    case state
    of 0: # Waiting class name
      result.className = w
      if w[^1] == '*':
        result.isPublic = true
        result.className = w[0 .. ^2]
      state = 1
    of 1: # Waiting extends keyword
      if w == "extends":
        state = 2
      elif w == "implements":
        state = 4
      else:
        assert(false)
    of 2: # Waiting superclass
      result.parentClass = w
      state = 3
    of 3: # Waiting implements keyword
      assert(w == "implements")
      state = 4
    of 4: # Waiting interface name
      result.interfaces.add(w)

  if a[^1].kind != nnkIdent:
    result.body = a[^1]

import typetraits

template implementCreateJObject*(T: typedesc) =
  proc stringMethodWithArgs(self, s: jobject): jobject {.cdecl.} =
    echo "stringMethodWithArgs called!"
    return s
  proc stringMethod(self: jobject): jobject {.cdecl.} =
    echo "stringMethod called!"
    return nil
  proc intMethod(self: jobject): jint {.cdecl.} =
    echo "intMethod called!"
    return 5
  proc voidMethod(self: jobject) {.cdecl.} =
    echo "voidMethod called!"

  method createJObject(self: T) =
    const fq = "Jnim$" & T.name
    let clazz = JVMClass.getByFqcn(fq)
    var nativeMethods: array[4, JNINativeMethod]
    nativeMethods[0].name = "stringMethodWithArgs"
    nativeMethods[0].signature = "(Ljava/lang/String;I)Ljava/lang/String;"
    nativeMethods[0].fnPtr = cast[pointer](stringMethodWithArgs)
    nativeMethods[1].name = "stringMethod"
    nativeMethods[1].signature = "()Ljava/lang/String;"
    nativeMethods[1].fnPtr = cast[pointer](stringMethod)
    nativeMethods[2].name = "intMethod"
    nativeMethods[2].signature = "()I"
    nativeMethods[2].fnPtr = cast[pointer](intMethod)
    nativeMethods[3].name = "voidMethod"
    nativeMethods[3].signature = "()V"
    nativeMethods[3].fnPtr = cast[pointer](voidMethod)
    let r = callVM theEnv.RegisterNatives(theEnv, clazz.get(), addr nativeMethods[0], nativeMethods.len.jint)
    assert(r == 0)

    GC_ref(self)
    let inst = clazz.newObjectRaw("(J)V", [toJValue(cast[jlong](self))])
    self.setObj(inst)
    echo "Creating111 " & T.name

const jnimGlue {.strdefine.} = "Jnim.java"

var
  javaGlue {.compileTime.} = newStringOfCap(1000000)
  imports {.compileTime.}: HashSet[string]
  classCursor {.compileTime.} = 0
  importCursor {.compileTime.} = 0

macro jexportAux(className, parentClass: static[string], interfaces: static[seq[string]], isPublic: static[bool], methodDefs: static[seq[MethodDescr]]): untyped =
  # echo treeRepr(a)
  if classCursor == 0:

    javaGlue = """
public class Jnim {
public interface __NimObject {}
"""
    classCursor = javaGlue.len
    javaGlue &= "}"
    imports = initSet[string]()

  echo "className: ", className, " public: ", isPublic
  echo "super: ", parentClass
  echo "interfaces: ", interfaces
  echo "body: ", repr(body)
  # echo "cur javaglue.len: ", javaGlue.len

  var newImports = newStringOfCap(10000)

  proc addImport(s: string) =
    if s notin imports:
      imports.incl(s)
      newImports &= "import "
      newImports &= s
      newImports &= ";\n"

  # addImport("ExportTestClass")
  # addImport(className)

  var classDef = newStringOfCap(100000)
  classDef &= "public static class "
  classDef &= className
  if parentClass.len != 0:
    classDef &= " extends "
    classDef &= parentClass

  classDef &= " implements __NimObject"
  for f in interfaces:
    classDef &= ", "
    classDef &= f
  classDef &= """ {
protected """ & className & """(long p) { this.p = p; }
protected void finalize() throws Throwable { super.finalize(); _0(p); }
private long p;
private native void _0(long p);
"""

  for m in methodDefs:
    classDef &= "public native "
    classDef &= m.retType
    classDef &= " "
    classDef &= m.name
    classDef &= "("
    for i, a in m.argTypes:
      if i != 0: classDef &= ", "
      classDef &= a
      classDef &= " _" & $i
    classDef &= ");\n"


  classDef &= "}\n\n"

  if newImports.len != 0:
    javaGlue.insert(newImports, importCursor)
    importCursor += newImports.len
    classCursor += newImports.len

  javaGlue.insert(classDef, classCursor)
  classCursor += classDef.len
  # echo javaGlue
  # echo "new javaglue.len: ", javaGlue.len

  # echo classDef

  # var s {.global.}: string
  # s.insert($a & "\n")
  writeFile(jnimGlue, javaGlue)

proc varargsToSeqStr(args: varargs[string]): seq[string] {.compileTime.} = @args
proc varargsToSeqMethodDef(args: varargs[MethodDescr]): seq[MethodDescr] {.compileTime.} = @args

proc jniFqcn*(T: type[void]): string = "void"
proc jniFqcn*(T: type[jint]): string = "int"
proc jniFqcn*(T: type[string]): string = "String"

macro jexport*(a: varargs[untyped]): untyped =
  var (className, parentClass, interfaces, body, isPublic) = extractArguments(a)

  var parentFq: NimNode
  if parentClass.len != 0:
    parentFq = newCall("getFqcn", newIdentNode(parentClass))
  else:
    parentFq = newLit("")

  var inter = newCall(bindSym"varargsToSeqStr")
  for i in interfaces:
    inter.add(newCall("jniFqcn", newIdentNode(i)))

  var methodDefs = newCall(bindSym"varargsToSeqMethodDef")
  for m in body:
    expectKind(m, nnkProcDef)
    let params = m.params

    var retType: NimNode
    if params[0].kind == nnkEmpty:
      retType = newLit("void")
    else:
      retType = newCall("jniFqcn", params[0])
    let argTypes = newCall(bindSym"varargsToSeqStr")
    for i in 2 ..< params.len:
      for j in 0 .. params[i].len - 3:
        argTypes.add(newCall("jniFqcn", params[i][^2]))
    let md = newCall(bindSym"initMethodDescr", newLit($m.name), retType, argTypes)
    methodDefs.add(md)

  result = newCall(bindSym"jexportAux", newLit(className), parentFq, inter, newLit(isPublic), methodDefs)

  echo repr result

macro debugPrintJavaGlue*(): untyped =
  echo javaGlue

# foo asdf1* extends super implements super1, super2:
#   proc hello()
# foo(asdf2 extends asdf implements qwert)
# foo(asdf3 extends asdf)
# foo(asdf4 implements qwert)
# foo(zxcv5)
#
# printJavaGlue()
#
