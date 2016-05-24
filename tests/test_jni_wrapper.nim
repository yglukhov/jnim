import private.jni_wrapper,
       unittest

suite "jni_wrapper":

  var vm: JavaVMPtr
  var env: JNIEnvPtr
         
  test "JNI - link with JVM library":
    linkWithJVMLib()
    require isJVMLoaded() == true

  test "JNI - init JVM":
    var args: JavaVMInitArgs
    args.version = JNI_VERSION_1_6
    let res = JNI_CreateJavaVM(addr vm, cast[ptr pointer](addr env), addr args)
    require res == 0.jint

  test "JNI - deinit JVM":
    check vm.DestroyJavaVM(vm) == 0
