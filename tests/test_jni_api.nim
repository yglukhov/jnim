import ../jnim/private/jni_api,
       ./common,
       unittest,
       strutils,
       typetraits

suite "jni_api":
  test "API - Thread initialization (VM not initialized)":
    check: not isJNIThreadInitialized()
    expect JNIException:
      initJNIThread()
    deinitJNIThread()

  test "API - Thread initialization (VM initialized)":
    initJNIForTests()
    expect JNIException:
      initJNI(JNIVersion.v1_6, @[])
    check: isJNIThreadInitialized()

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
    let outId = cls.getStaticFieldId("out", sigForClass"java.io.PrintStream")
    let `out` = cls.getField(JVMObject, outId)
    let outCls = `out`.getJVMClass
    let printlnId = outCls.getMethodId("println", "($#)V" % string.jniSig)
    `out`.callMethod(void, printlnId, ["Hello, world".newJVMObject.toJValue])

  test "API - TestClass - static fields":
    let cls = JVMClass.getByName("io.github.yglukhov.jnim.TestClass")

    check: cls.getField(JVMObject, "objectSField").toStringRaw == "obj"
    check: cls.getField(jchar, "charSField") == 'A'.jchar
    check: cls.getField(jbyte, "byteSField") == 1
    check: cls.getField(jshort, "shortSField") == 2
    check: cls.getField(jint, "intSField") == 3
    check: cls.getField(jlong, "longSField") == 4
    check: cls.getField(jfloat, "floatSField") == 1.0
    check: cls.getField(jdouble, "doubleSField") == 2.0
    check: cls.getField(jboolean, "booleanSField") == JVM_TRUE

    cls.setField("objectSField", "Nim".newJVMObject)
    cls.setField("charSField", 'B'.jchar)
    cls.setField("byteSField", 100.jbyte)
    cls.setField("shortSField", 200.jshort)
    cls.setField("intSField", 300.jint)
    cls.setField("longSField", 400.jlong)
    cls.setField("floatSField", 500.jfloat)
    cls.setField("doubleSField", 600.jdouble)
    cls.setField("booleanSField", JVM_FALSE)
    
    check: cls.getField(JVMObject, "objectSField").toStringRaw == "Nim"
    check: cls.getField(jchar, "charSField") == 'B'.jchar
    check: cls.getField(jbyte, "byteSField") == 100
    check: cls.getField(jshort, "shortSField") == 200
    check: cls.getField(jint, "intSField") == 300
    check: cls.getField(jlong, "longSField") == 400
    check: cls.getField(jfloat, "floatSField") == 500.0
    check: cls.getField(jdouble, "doubleSField") == 600.0
    check: cls.getField(jboolean, "booleanSField") == JVM_FALSE

  test "API - TestClass - fields":
    let cls = JVMClass.getByName("io.github.yglukhov.jnim.TestClass")
    let obj = cls.newObject("()V")

    check: getPropValue(string, obj, obj.getJVMClass.getFieldId("checkStringProperty", jniSig(string))) == "OK"
    
    check: obj.getField(JVMObject, "objectField").toStringRaw == "obj"
    check: obj.getField(jchar, "charField") == 'A'.jchar
    check: obj.getField(jbyte, "byteField") == 1
    check: obj.getField(jshort, "shortField") == 2
    check: obj.getField(jint, "intField") == 3
    check: obj.getField(jlong, "longField") == 4
    check: obj.getField(jfloat, "floatField") == 1.0
    check: obj.getField(jdouble, "doubleField") == 2.0
    check: obj.getField(jboolean, "booleanField") == JVM_TRUE

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
    let cls = JVMClass.getByName("io.github.yglukhov.jnim.TestClass")

    check: cls.callMethod(JVMObject, "objectSMethod", "($1)$1" % JVMObject.jniSig, ["test".newJVMObject.toJValue]).toStringRaw == "test"
    check: string.callMethod(cls, cls.getStaticMethodId("objectSMethod", "($1)$1" % JVMObject.jniSig), ["test".newJVMObject.toJValue]) == "test"
    check: cls.callMethod(jchar, "charSMethod", "($1)$1" % jchar.jniSig, ['A'.jchar.toJValue]) == 'A'.jchar
    check: cls.callMethod(jbyte, "byteSMethod", "($1)$1" % jbyte.jniSig, [1.jbyte.toJValue]) == 1
    check: cls.callMethod(jshort, "shortSMethod", "($1)$1" % jshort.jniSig, [2.jshort.toJValue]) == 2
    check: cls.callMethod(jint, "intSMethod", "($1)$1" % jint.jniSig, [3.jint.toJValue]) == 3
    check: cls.callMethod(jlong, "longSMethod", "($1)$1" % jlong.jniSig, [4.jlong.toJValue]) == 4
    check: cls.callMethod(jfloat, "floatSMethod", "($1)$1" % jfloat.jniSig, [5.jfloat.toJValue]) == 5.0
    check: cls.callMethod(jdouble, "doubleSMethod", "($1)$1" % jdouble.jniSig, [6.jdouble.toJValue]) == 6.0
    check: cls.callMethod(jboolean, "booleanSMethod", "($1)$1" % jboolean.jniSig, [JVM_TRUE.toJValue]) == JVM_TRUE


  test "JVM - TestClass - methods":
    let cls = JVMClass.getByName("io.github.yglukhov.jnim.TestClass")
    let obj = cls.newObject("()V")

    check: obj.callMethod(JVMObject, "objectMethod", "($1)$1" % JVMObject.jniSig, ["test".newJVMObject.toJValue]).toStringRaw == "test"
    check: string.callMethod(obj, cls.getMethodId("objectMethod", "($1)$1" % JVMObject.jniSig), ["test".newJVMObject.toJValue]) == "test"
    check: obj.callMethod(jchar, "charMethod", "($1)$1" % jchar.jniSig, ['A'.jchar.toJValue]) == 'A'.jchar
    check: obj.callMethod(jbyte, "byteMethod", "($1)$1" % jbyte.jniSig, [1.jbyte.toJValue]) == 1
    check: obj.callMethod(jshort, "shortMethod", "($1)$1" % jshort.jniSig, [2.jshort.toJValue]) == 2
    check: obj.callMethod(jint, "intMethod", "($1)$1" % jint.jniSig, [3.jint.toJValue]) == 3
    check: obj.callMethod(jlong, "longMethod", "($1)$1" % jlong.jniSig, [4.jlong.toJValue]) == 4
    check: obj.callMethod(jfloat, "floatMethod", "($1)$1" % jfloat.jniSig, [5.jfloat.toJValue]) == 5.0
    check: obj.callMethod(jdouble, "doubleMethod", "($1)$1" % jdouble.jniSig, [6.jdouble.toJValue]) == 6.0
    check: obj.callMethod(jboolean, "booleanMethod", "($1)$1" % jboolean.jniSig, [JVM_TRUE.toJValue]) == JVM_TRUE

  test "JVM - arrays":
    discard jchar.newArray(100)
    discard newArray(JVMObject, 100.jsize)
    discard JVMClass.getByName("java.lang.Object").newArray(100)

    discard @[1.jint, 2, 3].toJVMObject()
    discard @["a", "b", "c"].toJVMObject()

  test "JVM - TestClass - arrays":
    let cls = JVMClass.getByName("io.github.yglukhov.jnim.TestClass")
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

    let objArray: JVMObjectArray = newJVMObjectArray(2)
    objArray[0] = "Hello".newJVMObject
    objArray[1] = "world".newJVMObject
    obj.setObjectArray("objectArray", objArray)
    check: obj.callMethod(jboolean, "checkObjectArray", "()" & jboolean.jniSig) == JVM_FALSE
    objArray[1] = "world!".newJVMObject
    check: obj.callMethod(jboolean, "checkObjectArray", "()" & jboolean.jniSig) == JVM_TRUE

    let doubleArray = obj.callDoubleArrayMethod("getDoubleArray", "($#)$#" % [jdouble.jniSig, seq[jdouble].jniSig], [2.0.jdouble.toJValue])
    for idx in 1..doubleArray.len:
      check: doubleArray[idx-1] == (idx * 2).jdouble

    let strArray = cls.callObjectArrayMethod("getStringArrayS", "()" & seq[string].jniSig)
    for idx, val in ["Hello", "from", "java!"]:
      check: newJVMObjectConsumingLocalRef(strArray[idx]).toStringRaw == val

  test "API - jstring $":
    check: $(theEnv.NewStringUTF(theEnv, "test")) == "test"

