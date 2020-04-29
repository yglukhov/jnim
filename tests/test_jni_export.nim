import ../jnim/private / [ jni_api, jni_generator, jni_export ],
       ./common,
       unittest

jclass io.github.yglukhov.jnim.ExportTestClass$Interface of JVMObject:
  proc voidMethod()
  proc intMethod*(): jint # Test public
  proc stringMethod(): string
  proc stringMethodWithArgs(s: string, i: jint): string

jclass io.github.yglukhov.jnim.ExportTestClass$Tester of JVMObject:
  proc new
  proc callVoidMethod(r: Interface)
  proc callIntMethod(r: Interface): jint
  proc callStringMethod(r: Interface): string
  proc callStringMethodWithArgs(r: Interface, s: string, i: jint): string

jclass io.github.yglukhov.jnim.ExportTestClass$Implementation of Interface:
  proc new

type
  MyObjData = ref object
    a: int

  MyObj = ref object of JVMObject
    data: MyObjData

  MyObjSub = ref object of MyObj
  ImplementationSub = ref object of Implementation

jexport MyObj implements Interface:
  proc new() = super()

  proc voidMethod() # Test fwd declaration

  proc intMethod*(): jint = # Test public
    return 123

  proc stringMethod(): string =
    return "Hello world"

  proc stringMethodWithArgs(s: string, i: jint): string =
    return "123" & $i & s

jexport MyObjSub extends MyObj:
  proc new = super()

  proc stringMethod(): string =
    "Nim"

jexport ImplementationSub extends Implementation:
  proc new() = super()

  proc stringMethod(): string =
    this.super.stringMethod() & " is awesome"

proc voidMethod(this: MyObj) =
  inc this.data.a

debugPrintJavaGlue()

suite "jni_export":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()

    registerNativeMethods()

  test "Smoke test":
    let mr = MyObj.new()
    let tr = Tester.new()
    check:
      not mr.data.isNil
      mr.data.a == 0
    tr.callVoidMethod(mr)
    check:
      mr.data.a == 1
      tr.callIntMethod(mr) == 123
      tr.callStringMethod(mr) == "Hello world"
      tr.callStringMethodWithArgs(mr, "789", 456) == "123456789"
      tr.callStringMethod(MyObjSub.new()) == "Nim"

      tr.callStringMethod(Implementation.new()) == "Jnim"
      tr.callStringMethod(ImplementationSub.new()) == "Jnim is awesome"
