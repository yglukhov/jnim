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

    initJNI(JNIVersion.v1_6, @["-Djava.class.path=build"])
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

  test "API - call System.out.println":
    let cls = JVMClass.getByName("java.lang.System")
    let outId = cls.getStaticFieldId("out", fqcn"java.io.PrintStream")
    let `out` = cls.getObject(outId)
    let outCls = `out`.getClass
    let printlnId = outCls.getMethodId("println", "($#)V" % string.jniSig)
    `out`.callVoidMethod(printlnId, ["Hello, world".newJVMObject.toJValue])

  test "API - TestClass - static fields":
    let cls = JVMClass.getByName("TestClass")

    check: cls.getObject("objectSField").toStringRaw == "obj"
    check: cls.getChar("charSField") == 'A'.jchar
    check: cls.getByte("byteSField") == 1
    check: cls.getShort("shortSField") == 2
    check: cls.getInt("intSField") == 3
    check: cls.getLong("longSField") == 4
    check: cls.getFloat("floatSField") == 1.0
    check: cls.getDouble("doubleSField") == 2.0
    check: cls.getBoolean("booleanSField") == JVM_TRUE

    cls.setObject("objectSField", "Nim".newJVMObject)
    cls.setChar("charSField", 'B'.jchar)
    cls.setByte("byteSField", 100)
    cls.setShort("shortSField", 200)
    cls.setInt("intSField", 300)
    cls.setLong("longSField", 400)
    cls.setFloat("floatSField", 500.0)
    cls.setDouble("doubleSField", 600.0)
    cls.setBoolean("booleanSField", JVM_FALSE)
    
    check: cls.getObject("objectSField").toStringRaw == "Nim"
    check: cls.getChar("charSField") == 'B'.jchar
    check: cls.getByte("byteSField") == 100
    check: cls.getShort("shortSField") == 200
    check: cls.getInt("intSField") == 300
    check: cls.getLong("longSField") == 400
    check: cls.getFloat("floatSField") == 500.0
    check: cls.getDouble("doubleSField") == 600.0
    check: cls.getBoolean("booleanSField") == JVM_FALSE

  test "API - TestClass - fields":
    let cls = JVMClass.getByName("TestClass")
    let cons = cls.getMethodId("<init>", "()V")
    let obj = cls.newObject(cons, [])
    
    check: obj.getObject("objectField").toStringRaw == "obj"
    check: obj.getChar("charField") == 'A'.jchar
    check: obj.getByte("byteField") == 1
    check: obj.getShort("shortField") == 2
    check: obj.getInt("intField") == 3
    check: obj.getLong("longField") == 4
    check: obj.getFloat("floatField") == 1.0
    check: obj.getDouble("doubleField") == 2.0
    check: obj.getBoolean("booleanField") == JVM_TRUE

    obj.setObject("objectField", "Nim".newJVMObject)
    obj.setChar("charField", 'B'.jchar)
    obj.setByte("byteField", 100)
    obj.setShort("shortField", 200)
    obj.setInt("intField", 300)
    obj.setLong("longField", 400)
    obj.setFloat("floatField", 500.0)
    obj.setDouble("doubleField", 600.0)
    obj.setBoolean("booleanField", JVM_FALSE)
    
    check: obj.getObject("objectField").toStringRaw == "Nim"
    check: obj.getChar("charField") == 'B'.jchar
    check: obj.getByte("byteField") == 100
    check: obj.getShort("shortField") == 200
    check: obj.getInt("intField") == 300
    check: obj.getLong("longField") == 400
    check: obj.getFloat("floatField") == 500.0
    check: obj.getDouble("doubleField") == 600.0
    check: obj.getBoolean("booleanField") == JVM_FALSE
