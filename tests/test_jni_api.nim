import private.jni_api,
       ./common,
       threadpool,
       unittest,
       strutils,
       typetraits

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

    initJNIForTests()
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
    let obj = cls.newObject("()V")
    
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

  test "JVM - TestClass - static methods":
    let cls = JVMClass.getByName("TestClass")

    check: cls.callObjectMethod("objectSMethod", "($1)$1" % JVMObject.jniSig, ["test".newJVMObject.toJValue]).toStringRaw == "test"
    check: cls.callCharMethod("charSMethod", "($1)$1" % jchar.jniSig, ['A'.jchar.toJValue]) == 'A'.jchar
    check: cls.callByteMethod("byteSMethod", "($1)$1" % jbyte.jniSig, [1.jbyte.toJValue]) == 1
    check: cls.callShortMethod("shortSMethod", "($1)$1" % jshort.jniSig, [2.jshort.toJValue]) == 2
    check: cls.callIntMethod("intSMethod", "($1)$1" % jint.jniSig, [3.jint.toJValue]) == 3
    check: cls.callLongMethod("longSMethod", "($1)$1" % jlong.jniSig, [4.jlong.toJValue]) == 4
    check: cls.callFloatMethod("floatSMethod", "($1)$1" % jfloat.jniSig, [5.jfloat.toJValue]) == 5.0
    check: cls.callDoubleMethod("doubleSMethod", "($1)$1" % jdouble.jniSig, [6.jdouble.toJValue]) == 6.0
    check: cls.callBooleanMethod("booleanSMethod", "($1)$1" % jboolean.jniSig, [JVM_TRUE.toJValue]) == JVM_TRUE

  test "JVM - TestClass - methods":
    let cls = JVMClass.getByName("TestClass")
    let obj = cls.newObject("()V")

    check: obj.callObjectMethod("objectMethod", "($1)$1" % JVMObject.jniSig, ["test".newJVMObject.toJValue]).toStringRaw == "test"
    check: obj.callCharMethod("charMethod", "($1)$1" % jchar.jniSig, ['A'.jchar.toJValue]) == 'A'.jchar
    check: obj.callByteMethod("byteMethod", "($1)$1" % jbyte.jniSig, [1.jbyte.toJValue]) == 1
    check: obj.callShortMethod("shortMethod", "($1)$1" % jshort.jniSig, [2.jshort.toJValue]) == 2
    check: obj.callIntMethod("intMethod", "($1)$1" % jint.jniSig, [3.jint.toJValue]) == 3
    check: obj.callLongMethod("longMethod", "($1)$1" % jlong.jniSig, [4.jlong.toJValue]) == 4
    check: obj.callFloatMethod("floatMethod", "($1)$1" % jfloat.jniSig, [5.jfloat.toJValue]) == 5.0
    check: obj.callDoubleMethod("doubleMethod", "($1)$1" % jdouble.jniSig, [6.jdouble.toJValue]) == 6.0
    check: obj.callBooleanMethod("booleanMethod", "($1)$1" % jboolean.jniSig, [JVM_TRUE.toJValue]) == JVM_TRUE

  test "JVM - arrays":
    discard newJVMCharArray(100.jsize)
    discard jchar.newArray(100)
    discard newJVMObjectArray(100.jsize)
    discard JVMClass.getByName("java.lang.Object").newArray(100)

  test "JVM - TestClass - arrays":
    let cls = JVMClass.getByName("TestClass")
    let sArr = cls.getCharArray("staticCharArray")

    check: sArr.len == 5
    for idx, ch in "Hello":
      check: sArr[idx] == ch.jchar

    let obj = cls.newObject("()V")
    let arr = obj.getIntArray("intArray")

    check: arr.len == 5
    for idx, i in [1,2,3,4,5]:
      check: arr[idx] == i
      arr[idx] = (i * 2).jint
      check: arr[idx] == i * 2

    let objArray = newJVMObjectArray(2)
    objArray[0] = "Hello".newJVMObject
    objArray[1] = "world".newJVMObject
    obj.setObjectArray("objectArray", objArray)
    check: obj.callBooleanMethod("checkObjectArray", "()" & jboolean.jniSig) == JVM_FALSE
    objArray[1] = "world!".newJVMObject
    check: obj.callBooleanMethod("checkObjectArray", "()" & jboolean.jniSig) == JVM_TRUE

    let doubleArray = obj.callDoubleArrayMethod("getDoubleArray", "($#)$#" % [jdouble.jniSig, seq[jdouble].jniSig], [2.0.jdouble.toJValue])
    for idx in 1..doubleArray.len:
      check: doubleArray[idx-1] == (idx * 2).jdouble

    let strArray = cls.callObjectArrayMethod("getStringArrayS", "()" & seq[string].jniSig)
    for idx, val in ["Hello", "from", "java!"]:
      check: strArray[idx].toStringRaw == val
