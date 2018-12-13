import ../jnim/private / [ jni_api, jni_generator, jni_export ],
       ./common,
       unittest

jclassDef ExportTestClass$OverridableInterface of JVMObject
jclass ExportTestClass of JVMObject:
  proc new
  proc callVoidMethod(r: OverridableInterface)

type MyObj = ref object of JVMObject
  a: int

implementCreateJObject(MyObj)

jexport MyObj implements OverridableInterface:
  proc voidMethod(self: MyObj) =
    inc self.a

  proc intMethod(self: MyObj): jint =
    return 123

  proc stringMethod(self: MyObj): string =
    return "123"

  proc stringMethodWithArgs(self: MyObj, s: string, i: jint): string =
    return "123" & $i & s


debugPrintJavaGlue()

suite "jni_export":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()

  test "Make proxy":

    let mr = MyObj()

    let tr = ExportTestClass.new()
    check: mr.a == 0
    tr.callVoidMethod(cast[OverridableInterface](mr))
    check: mr.a == 1

  # test "Implement dispatcher":
  #   jclassDef ExportTestClass$OverridableInterface of JVMObject
  #   jclass ExportTestClass of JVMObject:
  #       proc new
  #       proc callVoidMethod(r: OverridableInterface)
  #       proc callIntMethod(r: OverridableInterface): jint
  #       proc callStringMethod(r: OverridableInterface): string
  #       proc callStringMethodWithArgs(r: OverridableInterface, s: string, i: jint): string
  #
  #   type MyObj = ref object of RootObj
  #       a: int
  #
  #   implementDispatcher(MyObj, MyObj_dispatcher):
  #     proc voidMethod(self: MyObj) =
  #       inc self.a
  #
  #     proc intMethod(self: MyObj): jint =
  #       return 123
  #
  #     proc stringMethod(self: MyObj): string =
  #       return "123"
  #
  #     proc stringMethodWithArgs(self: MyObj, s: string, i: jint): string =
  #       return "123" & $i & s
  #
  #   let mr = MyObj.new()
  #   mr.a = 5
  #   let pr = makeProxy(OverridableInterface, mr, MyObj_dispatcher)
  #   let tr = ExportTestClass.new()
  #   tr.callVoidMethod(pr)
  #   check: mr.a == 6
  #
  #   check: tr.callIntMethod(pr) == 123
  #   check: tr.callStringMethod(pr) == "123"
  #   check: tr.callStringMethodWithArgs(pr, "789", 456) == "123456789"
