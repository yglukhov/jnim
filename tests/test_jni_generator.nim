import private.jni_generator,
       private.jni_api,
       ./common,
       macros,
       unittest

jclass java.lang.String2* of JVMObject:
  proc jnew
jclass java.lang.String as JVMString2* of JVMObject:
  proc jnew

suite "jni_generator":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()
  
  test "jni_generator - proc def - constructors":
    var pd: ProcDef

    parseProcDefTest pd:
      proc jnew
    check: pd.name == "jnew"
    check: pd.jName == "<init>"
    check: pd.retType == "void"
    check: pd.params.len == 0
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: not pd.isExported

    parseProcDefTest pd:
      proc jnew*
    check: pd.name == "jnew"
    check: pd.jName == "<init>"
    check: pd.retType == "void"
    check: pd.params.len == 0
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: pd.isExported
      
    parseProcDefTest pd:
      proc jnew(o: JVMObject)
    check: pd.name == "jnew"
    check: pd.jName == "<init>"
    check: pd.retType == "void"
    check: pd.params == @[("o", "JVMObject")]
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: not pd.isExported
      
    parseProcDefTest pd:
      proc jnew*(i: jint, s: string)
    check: pd.name == "jnew"
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
      proc getStrings: seq[string]
    check: pd.name == "getStrings"
    check: pd.jName == "getStrings"
    check: pd.retType == "seq[string]"
    check: pd.params.len == 0
    check: not pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: not pd.isExported

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
      proc `method`*(i, j: jint): jshort {.importc: "jmethod".}
    check: pd.name == "method"
    check: pd.jName == "jmethod"
    check: pd.retType == "jshort"
    check: pd.params == @[("i", "jint"), ("j", "jint")]
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

  test "jni_generator - proc def - generics":
    var pd: ProcDef

    parseProcDefTest pd:
      proc setAt[K,V](k: K, v: V)
    check: pd.name == "setAt"
    check: pd.genericTypes == @["K", "V"]

    parseProcDefTest pd:
      proc genericProp[V]: V {.prop.}
    check: pd.name == "genericProp"
    check: pd.genericTypes == @["V"]
    check: pd.isProp
    check: not pd.isStatic

    parseProcDefTest pd:
      proc genericProp*[V]: V {.prop.}
    check: pd.name == "genericProp"
    check: pd.genericTypes == @["V"]
    check: pd.isProp
    check: pd.isExported
    check: not pd.isStatic

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

    parseClassDefTest cd:
      InnerTestClass$InnerClass of JVMObject
    check: cd.name == "InnerClass"
    check: cd.jName == "InnerTestClass$InnerClass"
    check: cd.parent == "JVMObject"
    check: not cd.isExported

  test "jni_generator - class def - generic header":
    var cd: ClassDef

    parseClassDefTest cd:
      java.util.List[T] of JVMObject
    check: cd.name == "List"
    check: cd.jName == "java.util.List"
    check: cd.genericTypes == @["T"]

    parseClassDefTest cd:
      java.util.Map[K,V] of JVMObject
    check: cd.name == "Map"
    check: cd.jName == "java.util.Map"
    check: cd.genericTypes == @["K", "V"]

    parseClassDefTest cd:
      java.util.HashMap[K,V] of Map[K,V]
    check: cd.name == "HashMap"
    check: cd.jName == "java.util.HashMap"
    check: cd.genericTypes == @["K", "V"]
    check: cd.parentGenericTypes == @["K", "V"]
    check: cd.parent == "Map"

    parseClassDefTest cd:
      java.util.Map2*[K,V] of JVMObject
    check: cd.name == "Map2"
    check: cd.jName == "java.util.Map2"
    check: cd.genericTypes == @["K", "V"]
    check: cd.isExported

    parseClassDefTest cd:
      java.util.HashMap2*[K,V] of Map2[K,V]
    check: cd.name == "HashMap2"
    check: cd.jName == "java.util.HashMap2"
    check: cd.genericTypes == @["K", "V"]
    check: cd.parentGenericTypes == @["K", "V"]
    check: cd.parent == "Map2"
    check: cd.isExported
    
  test "jni_generator - import class":
    jclass java.lang.String1 of JVMObject:
      proc jnew
    check: declared(String1)
    check: String1.jniSig == fqcn"java.lang.String1"
    jclass java.lang.String as JVMString1 of JVMObject:
      proc jnew
    check: declared(JVMString1)
    check: JVMString1.jniSig == fqcn"java.lang.String"
    check: declared(String2)
    check: String2.jniSig == fqcn"java.lang.String2"
    check: declared(JVMString2)
    check: JVMString2.jniSig == fqcn"java.lang.String"

  jclass ConstructorTestClass of JVMObject:
    proc jnew
    proc jnew(i: jint)
    proc jnew(s: string)
    proc jnew(i: jint, d: jdouble, s: string)
    proc jnew(ints: openarray[jint])
    proc jnew(strings: openarray[string])
    proc jnew(c: ConstructorTestClass)
    proc jnew(c: openarray[ConstructorTestClass])

  test "jni_generator - TestClass - constructors":
    var o = ConstructorTestClass.jnew
    check: o.toStringRaw == "Empty constructor called"
    o = ConstructorTestClass.jnew(1.jint)
    check: o.toStringRaw == "Int constructor called, 1"
    o = ConstructorTestClass.jnew("hi!")
    check: o.toStringRaw == "String constructor called, hi!"
    o = ConstructorTestClass.jnew(1, 2.0, "str")
    check: o.toStringRaw == "Multiparameter constructor called, 1, 2.0, str"
    o = ConstructorTestClass.jnew(@[1.jint,2,3])
    check: o.toStringRaw == "Int array constructor called, 1, 2, 3"
    o = ConstructorTestClass.jnew(@["a", "b", "c"])
    check: o.toStringRaw == "String array constructor called, a, b, c"
    o = ConstructorTestClass.jnew(o)
    check: o.toStringRaw == "String array constructor called, a, b, c"
    let cc = [ConstructorTestClass.jnew(), ConstructorTestClass.jnew(1)]
    o = ConstructorTestClass.jnew(cc)
    check: o.toStringRaw == "Empty constructor called\nInt constructor called, 1\n"

  jclass MethodTestClass of JVMObject:
    proc jnew
    proc add(x, y: jint): jint {.`static`, importc: "addStatic".}
    proc addToMem(x: jint): jint {.importc: "addToMem".}
    proc factory(i: jint): MethodTestClass {.`static`.}
    proc getStrings: seq[string]

  test "jni_generator - TestClass - methods":
    check: MethodTestClass.add(1, 2) == 3
    let o = MethodTestClass.jnew
    check: o.addToMem(2) == 2
    check: o.addToMem(3) == 5
    check: MethodTestClass.factory(5).addToMem(1) == 6
    check: o.getStrings == @["Hello", "world!"]

  jclassDef PropsTestClass of JVMObject
  jclassImpl PropsTestClass of JVMObject:
    proc jnew
    proc staticInt: jint {.prop, `static`.}
    proc instanceInt: jint {.prop.}
    proc inst: PropsTestClass {.prop, `static`, final.}
    proc instanceString: string {.prop.}
    proc staticBool: bool {.prop, `static`.}

  test "jni_generator - TestClass - properties":
    check: PropsTestClass.staticInt == 100
    PropsTestClass.staticInt = 200
    check: PropsTestClass.staticInt == 200
    let o = PropsTestClass.jnew
    check: o.instanceInt == 100
    o.instanceInt = 300
    check: o.instanceInt == 300
    check PropsTestClass.inst.instanceInt == 100
    PropsTestClass.inst.instanceString = "Hello, world!"
    check: PropsTestClass.inst.instanceString == "Hello, world!"
    check: not PropsTestClass.staticBool
    PropsTestClass.staticBool = true
    check: PropsTestClass.staticBool

  jclass InnerTestClass of JVMObject:
    proc jnew
  jclass InnerTestClass$InnerClass of JVMObject:
    proc jnew(p: InnerTestClass)
    proc intField: jint {.prop.}

  test "jni_generator - TestClass - inner classes":
    let p = InnerTestClass.jnew
    let o = InnerClass.jnew(p)
    check: o.intField == 100

  jclass java.util.List[V] of JVMObject:
    proc get[V](i: jint): V

  jclass GenericsTestClass[V] of JVMObject:
    proc jnew[V](v: V)
    proc genericProp[V]: V {.prop.}
    proc getGenericValue[V]: V
    proc setGenericValue[V](v: V)
    proc getListOfValues[V](count: jint): List[V]

  test "jni_generator - TestClass - generics":
    let o = GenericsTestClass[string].jnew("hello")
    o.genericProp = "hello, world!"
    check: o.genericProp == "hello, world!"
    o.setGenericValue("hi!")
    check: o.getGenericValue == "hi!"
    let l = o.getListOfValues(3)
    for i in 0..2:
      check: l.get(i.jint) == "hi!"

  jclass BaseClass[V] of JVMObject:
    proc jnew[V](v: V)
    proc baseMethod[V]: V
    proc overridedMethod[V]: V

  jclass ChildClass[V] of BaseClass[V]:
    proc jnew[V](base, ch: V)
    proc childMethod[V]: V

  test "jni_generator - TestClass - inheritance":
    let b = BaseClass[string].jnew("Base")
    let c = ChildClass[string].jnew("Base", "Child")
    check: b.baseMethod == b.overridedMethod
    check: c.childMethod == c.overridedMethod
    check: b.overridedMethod != c.overridedMethod
