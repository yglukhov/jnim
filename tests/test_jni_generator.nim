import private.jni_generator,
       private.jni_api,
       ./common,
       macros,
       unittest

jclass java.lang.String2* of JVMObject:
  proc new
jclass java.lang.String as JVMString2* of JVMObject:
  proc new

suite "jni_generator":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()
  
  test "jni_generator - proc def - constructors":
    var pd: ProcDef

    parseProcDefTest pd:
      proc new
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: pd.retType == "void"
    check: pd.params.len == 0
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: not pd.isExported

    parseProcDefTest pd:
      proc new*
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: pd.retType == "void"
    check: pd.params.len == 0
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: pd.isExported
      
    parseProcDefTest pd:
      proc new(o: JVMObject)
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: pd.retType == "void"
    check: pd.params == @[("o", "JVMObject")]
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: not pd.isExported
      
    parseProcDefTest pd:
      proc new*(i: jint, s: string)
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: pd.retType == "void"
    check: pd.params == @[("i", "jint"), ("s", "string")]
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: pd.isExported

  test "jni_generator - proc def - methods":
    var pd: ProcDef

    parseProcDefTest pd:
      proc `method`*(i: jint): jshort {.importc: "jmethod".}
    check: pd.name == "method"
    check: pd.jName == "jmethod"
    check: pd.retType == "jshort"
    check: pd.params == @[("i", "jint")]
    check: not pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: pd.isExported

    parseProcDefTest pd:
      proc staticMethod(i: jint): jshort {.`static`.}
    check: pd.name == "staticMethod"
    check: pd.jName == "staticMethod"
    check: pd.retType == "jshort"
    check: pd.params == @[("i", "jint")]
    check: not pd.isConstructor
    check: pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: not pd.isExported

  test "jni_generator - proc def - properties":
    var pd: ProcDef

    parseProcDefTest pd:
      proc `out`*(): JVMObject {.prop, final, `static`.}
    check: pd.name == "out"
    check: pd.jName == "out"
    check: pd.retType == "JVMObject"
    check: pd.params.len == 0
    check: not pd.isConstructor
    check: pd.isStatic
    check: pd.isProp
    check: pd.isFinal
    check: pd.isExported

  test "jni_generator - class def - header":
    var cd: ClassDef
    
    parseClassDefTest cd:
      java.lang.String of JVMObject

    check: cd.name == "String"
    check: cd.jName == "java.lang.String"
    check: cd.parent == "JVMObject"
    check: not cd.isExported

    parseClassDefTest cd:
      java.lang.String as JVMString of JVMObject

    check: cd.name == "JVMString"
    check: cd.jName == "java.lang.String"
    check: cd.parent == "JVMObject"
    check: not cd.isExported

    parseClassDefTest cd:
      java.lang.String* of JVMObject

    check: cd.name == "String"
    check: cd.jName == "java.lang.String"
    check: cd.parent == "JVMObject"
    check: cd.isExported

    parseClassDefTest cd:
      java.lang.String as JVMString* of JVMObject

    check: cd.name == "JVMString"
    check: cd.jName == "java.lang.String"
    check: cd.parent == "JVMObject"
    check: cd.isExported

  test "jni_generator - import class":
    jclass java.lang.String1 of JVMObject:
      proc new
    check: declared(String1)
    check: String1.jniSig == fqcn"java.lang.String1"
    jclass java.lang.String as JVMString1 of JVMObject:
      proc new
    check: declared(JVMString1)
    check: JVMString1.jniSig == fqcn"java.lang.String"
    check: declared(String2)
    check: String2.jniSig == fqcn"java.lang.String2"
    check: declared(JVMString2)
    check: JVMString2.jniSig == fqcn"java.lang.String"

  jclass ConstructorTestClass of JVMObject:
    proc new
    proc new(i: jint)
    proc new(s: string)
    proc new(i: jint, d: jdouble, s: string)
    proc new(ints: openarray[jint])
    proc new(strings: openarray[string])
    proc new(c: ConstructorTestClass)
    proc new(c: openarray[ConstructorTestClass])

  test "jni_generator - TestClass - constructors":
    var o = ConstructorTestClass.new
    check: o.toStringRaw == "Empty constructor called"
    o = ConstructorTestClass.new(1)
    check: o.toStringRaw == "Int constructor called, 1"
    o = ConstructorTestClass.new("hi!")
    check: o.toStringRaw == "String constructor called, hi!"
    o = ConstructorTestClass.new(1, 2.0, "str")
    check: o.toStringRaw == "Multiparameter constructor called, 1, 2.0, str"
    o = ConstructorTestClass.new(@[1.jint,2,3])
    check: o.toStringRaw == "Int array constructor called, 1, 2, 3"
    o = ConstructorTestClass.new(@["a", "b", "c"])
    check: o.toStringRaw == "String array constructor called, a, b, c"
    o = ConstructorTestClass.new(o)
    check: o.toStringRaw == "String array constructor called, a, b, c"
    let cc = @[ConstructorTestClass.new(), ConstructorTestClass.new(1)]
    o = ConstructorTestClass.new(cc)
    check: o.toStringRaw == "Empty constructor called\nInt constructor called, 1\n"
