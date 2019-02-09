import ../jnim/private / [ jni_api, jni_generator, jni_export_old ],
       ./common,
       unittest

suite "jni_export_old":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()

  test "Make proxy":
    jclassDef io.github.yglukhov.jnim.ExportTestClass$OverridableInterface of JVMObject
    jclass io.github.yglukhov.jnim.ExportTestClass of JVMObject:
      proc new
      proc callVoidMethod(r: OverridableInterface)

    type MyObj = ref object of RootObj
      a: int

    var mr = MyObj.new()
    mr.a = 1
    proc handler(env: pointer, o: RootRef, proxiedThis, meth: jobject, args: jobjectArray): jobject {.cdecl.} =
      let mr = cast[MyObj](o)
      inc mr.a

    let runnableClazz = OverridableInterface.getJVMClassForType()
    for i in 0 .. 3:
      let pr = makeProxy(runnableClazz.get, mr, handler)

      let tr = ExportTestClass.new()
      tr.callVoidMethod(OverridableInterface.fromJObject(pr))

    check: mr.a == 5

  test "Implement dispatcher":
    jclassDef io.github.yglukhov.jnim.ExportTestClass$OverridableInterface of JVMObject
    jclass io.github.yglukhov.jnim.ExportTestClass of JVMObject:
        proc new
        proc callVoidMethod(r: OverridableInterface)
        proc callIntMethod(r: OverridableInterface): jint
        proc callStringMethod(r: OverridableInterface): string
        proc callStringMethodWithArgs(r: OverridableInterface, s: string, i: jint): string

    type MyObj = ref object of RootObj
        a: int

    implementDispatcher(MyObj, MyObj_dispatcher):
      proc voidMethod(self: MyObj) =
        inc self.a

      proc intMethod(self: MyObj): jint =
        return 123

      proc stringMethod(self: MyObj): string =
        return "123"

      proc stringMethodWithArgs(self: MyObj, s: string, i: jint): string =
        return "123" & $i & s

    let mr = MyObj.new()
    mr.a = 5
    let pr = makeProxy(OverridableInterface, mr, MyObj_dispatcher)
    let tr = ExportTestClass.new()
    tr.callVoidMethod(pr)
    check: mr.a == 6

    check: tr.callIntMethod(pr) == 123
    check: tr.callStringMethod(pr) == "123"
    check: tr.callStringMethodWithArgs(pr, "789", 456) == "123456789"
