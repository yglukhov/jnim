import private.jni_generator,
       private.jni_api,
       ./common,
       macros,
       unittest

jclass java.lang.String2* of JVMObject:
  proc new
jclass java.lang.String as JVMString2* of JVMObject:
  proc new

# These classes are not used in actual tests -
# but they should compile.

jclass java.util.Map[K,V] of JVMObject:
  proc get(k: K): V

# Class with a method that returns a generic with two arguments
jclass java.lang.ProcessBuilder of JVMObject:
  proc environment: Map[string, string]

# Class that inherits from another with get() method
jclass java.util.Properties of Map[JVMObject, JVMObject]:
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

    parseProcDefTest pd:
      proc `method`*: Map[string,jint]
    check: pd.name == "method"
    check: pd.jName == "method"
    check: pd.retType == "Map[string,jint]"
    check: pd.params == newSeq[ProcParam]()
    check: not pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: pd.isExported

    parseProcDefTest pd:
      proc `method`*(m: Map[string,jint]): jshort
    check: pd.name == "method"
    check: pd.jName == "method"
    check: pd.retType == "jshort"
    check: pd.params == @[("m", "Map[string,jint]")]
    check: not pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: pd.isExported

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

    parseClassDefTest cd:
      java.util.Map$Entry*[K,V] as MapEntry of JVMObject
    check: cd.name == "MapEntry"
    check: cd.jName == "java.util.Map$Entry"
    check: cd.genericTypes == @["K", "V"]
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
    o = ConstructorTestClass.new(1.jint)
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
    let cc = [ConstructorTestClass.new(), ConstructorTestClass.new(1)]
    o = ConstructorTestClass.new(cc)
    check: o.toStringRaw == "Empty constructor called\nInt constructor called, 1\n"

  jclass MethodTestClass of JVMObject:
    proc new
    proc add(x, y: jint): jint {.`static`, importc: "addStatic".}
    proc addToMem(x: jint): jint {.importc: "addToMem".}
    proc factory(i: jint): MethodTestClass {.`static`.}
    proc getStrings: seq[string]

  test "jni_generator - TestClass - methods":
    check: MethodTestClass.add(1, 2) == 3
    let o = MethodTestClass.new
    check: o.addToMem(2) == 2
    check: o.addToMem(3) == 5
    check: MethodTestClass.factory(5).addToMem(1) == 6
    check: o.getStrings == @["Hello", "world!"]

  jclassDef PropsTestClass of JVMObject
  jclassImpl PropsTestClass of JVMObject:
    proc new
    proc staticInt: jint {.prop, `static`.}
    proc instanceInt: jint {.prop.}
    proc inst: PropsTestClass {.prop, `static`, final.}
    proc instanceString: string {.prop.}
    proc staticBool: bool {.prop, `static`.}

  test "jni_generator - TestClass - properties":
    check: PropsTestClass.staticInt == 100
    PropsTestClass.staticInt = 200
    check: PropsTestClass.staticInt == 200
    let o = PropsTestClass.new
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
    proc new
  jclass InnerTestClass$InnerClass of JVMObject:
    proc new(p: InnerTestClass)
    proc intField: jint {.prop.}

  test "jni_generator - TestClass - inner classes":
    let p = InnerTestClass.new
    let o = InnerClass.new(p)
    check: o.intField == 100

  jclass java.util.List[V] of JVMObject:
    proc get[V](i: jint): V

  jclass GenericsTestClass[V] of JVMObject:
    proc new[V](v: V)
    proc genericProp[V]: V {.prop.}
    proc getGenericValue[V]: V
    proc setGenericValue[V](v: V)
    proc getListOfValues[V](count: jint): List[V]

  test "jni_generator - TestClass - generics":
    let o = GenericsTestClass[string].new("hello")
    o.genericProp = "hello, world!"
    check: o.genericProp == "hello, world!"
    o.setGenericValue("hi!")
    check: o.getGenericValue == "hi!"
    let l = o.getListOfValues(3)
    for i in 0..2:
      check: l.get(i.jint) == "hi!"

  jclass BaseClass[V] of JVMObject:
    proc new[V](v: V)
    proc baseMethod[V]: V
    proc overridedMethod[V]: V

  jclass ChildClass[V] of BaseClass[V]:
    proc new[V](base, ch: V)
    proc childMethod[V]: V

  test "jni_generator - TestClass - inheritance":
    let b = BaseClass[string].new("Base")
    let c = ChildClass[string].new("Base", "Child")
    check: b.baseMethod == b.overridedMethod
    check: c.childMethod == c.overridedMethod
    check: b.overridedMethod != c.overridedMethod
