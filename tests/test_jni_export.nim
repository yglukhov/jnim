import ../jnim/private / [ jni_api, jni_generator, jni_export ],
       ./common,
       unittest

jclassDef io.github.yglukhov.jnim.ExportTestClass$OverridableInterface of JVMObject
jclass io.github.yglukhov.jnim.ExportTestClass of JVMObject:
  proc new
  proc callVoidMethod(r: OverridableInterface)
  proc callIntMethod(r: OverridableInterface): jint
  proc callStringMethod(r: OverridableInterface): string
  proc callStringMethodWithArgs(r: OverridableInterface, s: string, i: jint): string

type
  MyObj = ref object of JVMObject
    a: int
  MyObjSub = ref object of MyObj

jexport MyObj implements OverridableInterface:
  proc voidMethod() # Test fwd declaration

  proc intMethod*(): jint = # Test public
    return 123

  proc stringMethod(): string =
    return "123"

  proc stringMethodWithArgs(s: string, i: jint): string =
    return "123" & $i & s

jexport MyObjSub extends MyObj:
  proc stringMethod(): string = "456"

proc voidMethod(this: MyObj) =
  inc this.a

debugPrintJavaGlue()

suite "jni_export":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()

  test "Make proxy":
    let mr = MyObj()

    let tr = ExportTestClass.new()
    check: mr.a == 0
    tr.callVoidMethod(mr)
    check:
      mr.a == 1
      tr.callIntMethod(mr) == 123
      tr.callStringMethod(mr) == "123"
      tr.callStringMethodWithArgs(mr, "789", 456) == "123456789"
      tr.callStringMethod(MyObjSub()) == "456"

