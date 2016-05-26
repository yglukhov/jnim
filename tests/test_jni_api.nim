import private.jni_api,
       threadpool,
       unittest,
       strutils

suite "jni_api":
  test "API - Initialization":
    proc thrNotInited {.gcsafe.} = 
      test "API - Thread initialization (VM not initialized)":
        check: not isJNIThreadInitialized()
        expect JNIException:
          initJNIThread()
        deinitJNIThread()
    spawn thrNotInited()
    sync()

    initJNI(JNIVersion.v1_6, @[])
    expect JNIException:
      initJNI(JNIVersion.v1_6, @[])
    check: isJNIThreadInitialized()

    proc thrInited {.gcsafe.} = 
      test "API - Thread initialization (VM initialized)":
        check: not isJNIThreadInitialized()
        initJNIThread()
        check: isJNIThreadInitialized()
        deinitJNIThread()
    spawn thrInited()
    sync()

  test "API - JVMClass":
    # Find existing class
    discard JVMClass.getByFqcn(fqcn"java.lang.Object")
    discard JVMClass.getByName("java.lang.Object")
    # Find non existing class
    expect Exception:
      discard JVMClass.getByFqcn(fqcn"java.lang.ObjectThatNotExists")
    expect Exception:
      discard JVMClass.getByName("java.lang.ObjectThatNotExists")

  test "API - call static method":
    let cls = JVMClass.getByName("java.lang.System")
    let outId = cls.getStaticFieldId("out", fqcn"java.io.PrintStream")
    let `out` = cls.getStaticObjectField(outId)
    let outCls = `out`.getClass
    let printlnId = outCls.getMethodId("println", "($#)V" % string.jniSig)
    `out`.callVoidMethod(printlnId, ["Hello, world".newJVMObject.toJValue])
