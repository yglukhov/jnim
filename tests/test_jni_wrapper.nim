import ../jnim/private/jni_wrapper,
       unittest,
       strutils

suite "jni_wrapper":

  var vm: JavaVMPtr
  var env: JNIEnvPtr

  const version = JNI_VERSION_1_6

  test "JNI - link with JVM library":
    linkWithJVMLib()
    require isJVMLoaded() == true

  test "JNI - init JVM":
    var args: JavaVMInitArgs
    args.version = version
    let res = JNI_CreateJavaVM(addr vm, cast[ptr pointer](addr env), addr args)
    require res == 0.jint

  test "JNI - test version":
    check env.GetVersion(env) >= version

  template chkEx: untyped =
    if env.ExceptionCheck(env) != JVM_FALSE:
      env.ExceptionDescribe(env)
      require false

  test "JNI - call System.out.println":
    let cls = env.FindClass(env, fqcn"java.lang.System")
    chkEx
    let outId = env.GetStaticFieldID(env, cls, "out", sigForClass"java.io.PrintStream")
    chkEx
    let `out` = env.GetStaticObjectField(env, cls, outId)
    chkEx
    defer: env.DeleteLocalRef(env, `out`)
    let outCls = env.GetObjectClass(env, `out`)
    chkEx
    let printlnId = env.GetMethodID(env, outCls, "println", "($#)V" % sigForClass"java.lang.String")
    chkEx
    var str = env.NewStringUTF(env, "Hello, world!")
    chkEx
    defer: env.DeleteLocalRef(env, `str`)
    var val = str.jobject.toJValue
    env.CallVoidMethodA(env, `out`, printlnId, addr val)
    chkEx

  test "JNI - deinit JVM":
    check vm.DestroyJavaVM(vm) == 0
