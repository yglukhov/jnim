import ../jnim/private / [ jni_api, jni_generator, jni_export ],
       ./common,
       unittest

jclassDef ExportTestClass$OverridableInterface of JVMObject
jclass ExportTestClass of JVMObject:
  proc new
  proc callVoidMethod(r: OverridableInterface)
  proc callIntMethod(r: OverridableInterface): jint
  proc callStringMethod(r: OverridableInterface): string
  proc callStringMethodWithArgs(r: OverridableInterface, s: string, i: jint): string

type MyObj = ref object of JVMObject
  a: int

jexport MyObj implements OverridableInterface:
  proc voidMethod(self: MyObj) # Test fwd declaration

  proc intMethod*(self: MyObj): jint = # Test public
    return 123

  proc stringMethod(self: MyObj): string =
    return "123"

  proc stringMethodWithArgs(self: MyObj, s: string, i: jint): string =
    return "123" & $i & s

proc voidMethod(self: MyObj) =
  inc self.a

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
    check: mr.a == 1
    check: tr.callIntMethod(mr) == 123
    check: tr.callStringMethod(mr) == "123"
    check: tr.callStringMethodWithArgs(mr, "789", 456) == "123456789"

