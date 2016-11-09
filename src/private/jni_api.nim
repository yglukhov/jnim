import jni_wrapper, fp.option, macros, strutils

export jni_wrapper

type
  JNIVersion* {.pure.} = enum
    v1_1 = JNI_VERSION_1_1.int,
    v1_2 = JNI_VERSION_1_2.int,
    v1_4 = JNI_VERSION_1_4.int,
    v1_6 = JNI_VERSION_1_6.int,
    v1_8 = JNI_VERSION_1_8.int
  JVMOptions = tuple[
    version: JNIVersion,
    options: seq[string]
  ]

var theOptions = JVMOptions.none
# Options for another threads
var theOptionsPtr: pointer
var theVM: JavaVMPtr
var theEnv* {.threadVar}: JNIEnvPtr

proc initJNIThread* {.gcsafe.}
proc initJNI*(version: JNIVersion = JNIVersion.v1_6, options: seq[string] = @[]) =
  ## Setup JNI API
  jniAssert(not theOptions.isDefined, "JNI API already initialized, you must deinitialize it first")
  theOptions = (version: version, options: options).some
  theOptionsPtr = cast[pointer](theOptions)
  initJNIThread()

# This is not supported, as it said here: http://docs.oracle.com/javase/7/docs/technotes/guides/jni/spec/invocation.html#destroy_java_vm:
# "As of JDK/JRE 1.1.2 unloading of the VM is not supported."
# Maybe it can be usefull with alternative implementations of JRE
when false:
  proc deinitJNI* =
    ## Deinitialize JNI API
    if theVM == nil:
      return
    jniCall theVM.DestroyJavaVM(theVM), "Error deinitializing JNI"
    theOptions = JVMOptions.none
    theOptionsPtr = nil
    theVM = nil
    theEnv = nil

proc initJNIThread* =
  ## Setup JNI API thread
  if theEnv != nil:
    return
  if theOptionsPtr == nil:
    raise newJNIException("You must initialize JNI API before using it")

  let o = cast[type(theOptions)](theOptionsPtr).get
  var args: JavaVMInitArgs
  args.version = o.version.jint
  args.nOptions = o.options.len.jint
  if o.options.len > 0:
    var opts = newSeq[JavaVMOption](o.options.len)
    for idx in 0..<o.options.len:
      opts[idx].optionString = o.options[idx].cstring
    args.options = opts[0].addr
  if theVM == nil:
    # We need to link with JNI and so on
    linkWithJVMLib()
    jniCall JNI_CreateJavaVM(theVM.addr, cast[ptr pointer](theEnv.addr), args.addr), "Error creating VM"
  else:
    # We need to attach current thread to JVM
    jniCall theVM.AttachCurrentThread(theVM, cast[ptr pointer](theEnv.addr), args.addr), "Error attaching thread to VM"

proc deinitJNIThread* =
  ## Deinitialize JNI API thread
  if theEnv == nil:
    return
  discard theVM.DetachCurrentThread(theVM)
  theEnv = nil

proc isJNIThreadInitialized*: bool = theEnv != nil

template checkInit* = jniAssert(theEnv != nil, "You must call initJNIThread before using JNI API")

####################################################################################################
# Types
type
  JVMMethodID* = ref object
    id: jmethodID
  JVMFieldID* = ref object
    id: jfieldID
  JVMClass* = ref object
    cls: jclass
  JVMObject* = ref object {.inheritable.}
    obj: jobject

#################################################################################################### 
# Exception handling

type
  JavaException* = object of Exception
    ex: JVMObject

proc toStringRaw*(o: JVMObject): string

proc newJavaException*(ex: JVMObject): ref JavaException =
  result = newException(JavaException, ex.toStringRaw)
  result.ex = ex

proc newJVMObject*(o: jobject): JVMObject

template checkException: stmt =
  if theEnv != nil and theEnv.ExceptionCheck(theEnv) == JVM_TRUE:
    let ex = theEnv.ExceptionOccurred(theEnv).newJVMObject
    theEnv.ExceptionClear(theEnv)
    raise newJavaException(ex)
  
macro callVM*(s: expr): expr =
  result = quote do:
    let res = `s`
    checkException()
    res

####################################################################################################
# JVMMethodID type
proc newJVMMethodID*(id: jmethodID): JVMMethodID =
  JVMMethodID(id: id)

proc get*(id: JVMMethodID): jmethodID =
  id.id

####################################################################################################
# JVMFieldID type
proc newJVMFieldID*(id: jfieldID): JVMFieldID =
  JVMFieldID(id: id)

proc get*(id: JVMFieldID): jfieldID =
  id.id

####################################################################################################
# JVMClass type
proc newJVMClass*(c: jclass): JVMClass =
  JVMClass(cls: c)

proc getByFqcn*(T: typedesc[JVMClass], name: string): JVMClass =
  ## Finds class by it's full qualified class name
  checkInit
  let c = callVM theEnv.FindClass(theEnv, name)
  c.newJVMClass

proc getByName*(T: typedesc[JVMClass], name: string): JVMClass =
  ## Finds class by it's name (not fqcn)
  T.getByFqcn(name.fqcn)

proc get*(c: JVMClass): jclass =
  c.cls

# Static fields

proc getStaticFieldId*(c: JVMClass, name: string, sig: string): JVMFieldID =
  checkInit
  (callVM theEnv.GetStaticFieldID(theEnv, c.get, name, sig)).newJVMFieldID

proc getStaticFieldId*(c: JVMClass, name: string, t: typedesc): JVMFieldID =
  checkInit
  (callVM theEnv.GetStaticFieldID(theEnv, c.get, name, jniSig(t))).newJVMFieldID

proc getFieldId*(c: JVMClass, name: string, sig: string): JVMFieldID =
  checkInit
  (callVM theEnv.GetFieldID(theEnv, c.get, name, sig)).newJVMFieldID

proc getFieldId*(c: JVMClass, name: string, t: typedesc): JVMFieldID =
  checkInit
  (callVM theEnv.GetFieldID(theEnv, c.get, name, jniSig(t))).newJVMFieldID

proc getMethodId*(c: JVMClass, name, sig: string): JVMMethodID =
  checkInit
  (callVM theEnv.GetMethodID(theEnv, c.get, name, sig)).newJVMMethodID

proc getStaticMethodId*(c: JVMClass, name: string, sig: string): JVMMethodID =
  checkInit
  (callVM theEnv.GetStaticMethodID(theEnv, c.get, name, sig)).newJVMMethodID

proc callVoidMethod*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []) =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  theEnv.CallStaticVoidMethodA(theEnv, c.get, id.get, a)
  checkException

proc callVoidMethod*(c: JVMClass, name, sig: string, args: openarray[jvalue] = []) =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  theEnv.CallStaticVoidMethodA(theEnv, c.get, c.getStaticMethodId(name, sig).get, a)
  checkException

proc newObject*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): JVMObject =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  (callVM theEnv.NewobjectA(theEnv, c.get, id.get, a)).newJVMObject

proc newObject*(c: JVMClass, sig: string, args: openarray[jvalue] = []): JVMObject =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  (callVM theEnv.NewobjectA(theEnv, c.get, c.getMethodId("<init>", sig).get, a)).newJVMObject

proc newObjectRaw*(c: JVMClass, sig: string, args: openarray[jvalue] = []): jobject =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  callVM theEnv.NewobjectA(theEnv, c.get, c.getMethodId("<init>", sig).get, a)

####################################################################################################
# JVMObject type

proc jniSig*(T: typedesc[JVMObject]): string = fqcn"java.lang.Object"

proc free*(o: JVMObject) =
  if o.obj != nil and theEnv != nil:
    theEnv.DeleteLocalRef(theEnv, o.obj)
    o.obj = nil

proc freeJVMObject*(o: JVMObject) =
  o.free

proc newJVMObject*(o: jobject): JVMObject =
  new(result, freeJVMObject)
  result.obj = o

proc create*(t: typedesc[JVMObject], o: jobject): JVMObject = newJVMObject(o)

proc newJVMObject*(s: string): JVMObject =
  (callVM theEnv.NewStringUTF(theEnv, s)).newJVMObject

proc get*(o: JVMObject): jobject =
  o.obj

proc setObj*(o: var JVMObject, obj: jobject) =
  o.obj = obj

proc toJValue*(o: JVMObject): jvalue =
  o.get.toJValue

proc getJVMClass*(o: JVMObject): JVMClass =
  checkInit
  (callVM theEnv.GetObjectClass(theEnv, o.get)).newJVMClass
  
proc equalsRaw*(v1, v2: JVMObject): jboolean =
  # This is low level ``equals`` version
  assert v1.obj != nil
  let cls = theEnv.GetObjectClass(theEnv, v1.obj)
  jniAssertEx(cls.pointer != nil, "Can't find object's class")
  let mthId = theEnv.GetMethodID(theEnv, cls, "equals", "($#)$#" % [jobject.jniSig, jboolean.jniSig])
  jniAssertEx(mthId != nil, "Can't find ``equals`` method")
  var v2w = v2.obj.toJValue
  result = theEnv.CallBooleanMethodA(theEnv, v1.obj, mthId, addr v2w)

proc toStringRaw(o: JVMObject): string =
  # This is low level ``toString`` version
  if o.obj.isNil:
    return nil
  let cls = theEnv.GetObjectClass(theEnv, o.obj)
  jniAssertEx(cls.pointer != nil, "Can't find object's class")
  let mthId = theEnv.GetMethodID(theEnv, cls, "toString", "()" & string.jniSig)
  jniAssertEx(mthId != nil, "Can't find ``toString`` method")
  let s = theEnv.CallObjectMethodA(theEnv, o.obj, mthId, nil).jstring
  defer:
    if s != nil:
      theEnv.DeleteLocalRef(theEnv, s)
  if s == nil:
    return nil
  let cs = theEnv.GetStringUTFChars(theEnv, s, nil)
  defer:
    if cs != nil:
      theEnv.ReleaseStringUTFChars(theEnv, s, cs)
  $cs

proc callVoidMethod*(o: JVMObject, id: JVMMethodID, args: openarray[jvalue] = []) =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  theEnv.CallVoidMethodA(theEnv, o.get, id.get, a)
  checkException

proc callVoidMethod*(o: JVMObject, name, sig: string, args: openarray[jvalue] = []) =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  theEnv.CallVoidMethodA(theEnv, o.get, o.getJVMClass.getMethodId(name, sig).get, a)
  checkException

####################################################################################################
# Reference handling
proc newRef*(o: JVMObject): jobject =
  checkInit
  callVM theEnv.NewLocalRef(theEnv, o.get)
  
####################################################################################################
# Arrays support

template genArrayType(typ, arrTyp: typedesc, typName: untyped): stmt {.immediate.} =

  # Creation

  type `JVM typName Array`* {.inject.} = ref object
    arr: `arrTyp`

  proc get*(arr: `JVM typName Array`): `arrTyp` = arr.arr

  proc jniSig*(T: typedesc[`JVM typName Array`]): string = "[" & jniSig(typ)

  proc `freeJVM typName Array`(a: `JVM typName Array`) =
    if a.arr != nil and theEnv != nil:
      theEnv.DeleteLocalRef(theEnv, a.arr)

  when not (`typ` is JVMObject):
    proc `newJVM typName Array`*(len: jsize): `JVM typName Array` =
      checkInit
      new(result, `freeJVM typName Array`)
      result.arr = callVM theEnv.`New typName Array`(theEnv, len)

    proc newArray*(t: typedesc[typ], len: int): `JVM typName Array` = `newJVM typName Array`(len.jsize)

  else:

    proc `newJVM typName Array`*(len: jsize, cls = JVMClass.getByName("java.lang.Object")): `JVM typName Array` =
      checkInit
      new(result, freeJVMObjectArray)
      result.arr = callVM theEnv.NewObjectArray(theEnv, len, cls.get, nil)

    proc newArray*(c: JVMClass, len: int): `JVM typName Array` =
      `newJVM typName Array`(len.jsize, c)

    proc newArray*(t: typedesc[JVMObject], len: int): `JVM typName Array` =
      `newJVM typName Array`(len.jsize, JVMClass.getByName("java.lang.Object"))

  proc `newJVM typName Array`*(arr: jobject): `JVM typName Array` =
    checkInit
    new(result, `freeJVM typName Array`)
    result.arr = arr.`arrTyp`

  proc `newJVM typName Array`*(arr: JVMObject): `JVM typName Array` =
    `newJVM typName Array`(arr.newRef)

  proc newArray*(t: typedesc[typ], arr: jobject): `JVM typName Array` = `newJVM typName Array`(arr)

  proc newArray*(t: typedesc[typ], arr: JVMObject): `JVM typName Array` =
    `newJVM typName Array`(arr.newRef)

  proc toJVMObject*(a: `JVM typName Array`): JVMObject =
    checkInit
    newJVMObject(callVM theEnv.NewLocalRef(theEnv, a.arr.jobject))

  # getters/setters
  
  proc `get typName Array`*(c: JVMClass, name: string): `JVM typName Array` =
    checkInit
    `typ`.newArray(callVM theEnv.GetStaticObjectField(theEnv, c.get, c.getStaticFieldId(`name`, seq[`typ`].jniSig).get))

  proc `get typName Array`*(o: JVMObject, name: string): `JVM typName Array` =
    checkInit
    `typ`.newArray(callVM theEnv.GetObjectField(theEnv, o.get, o.getJVMClass.getFieldId(`name`, seq[`typ`].jniSig).get))

  proc `set typName Array`*(c: JVMClass, name: string, arr: `JVM typName Array`) =
    checkInit
    theEnv.SetStaticObjectField(theEnv, c.get, c.getStaticFieldId(`name`, seq[`typ`].jniSig).get, arr.arr)
    checkException

  proc `set typName Array`*(o: JVMObject, name: string, arr: `JVM typName Array`) =
    checkInit
    theEnv.SetObjectField(theEnv, o.get, o.getJVMClass.getFieldId(`name`, seq[`typ`].jniSig).get, arr.arr)
    checkException

  # Array methods

  proc len*(arr: `JVM typName Array`): jsize =
    checkInit
    callVM theEnv.GetArrayLength(theEnv, arr.get)

  when `typ` is JVMObject:
    proc `[]`*(arr: `JVM typName Array`, idx: Natural): JVMObject =
      checkInit
      (callVM theEnv.GetObjectArrayElement(theEnv, arr.get, idx.jsize)).newJVMObject
    proc `[]=`*(arr: `JVM typName Array`, idx: Natural, obj: JVMObject) =
      checkInit
      theEnv.SetObjectArrayElement(theEnv, arr.get, idx.jsize, obj.get)
      checkException
  else:
    proc getArrayRegion*(a: arrTyp, start, length: jint, address: ptr typ) =
      checkInit
      theEnv.`Get typName ArrayRegion`(theEnv, a, start, length, address)

    proc `[]`*(arr: `JVM typName Array`, idx: Natural): `typ` =
      checkInit
      theEnv.`Get typName ArrayRegion`(theEnv, arr.get, idx.jsize, 1.jsize, addr result)
      checkException
    proc `[]=`*(arr: `JVM typName Array`, idx: Natural, v: `typ`) =
      checkInit
      theEnv.`Set typName ArrayRegion`(theEnv, arr.get, idx.jsize, 1.jsize, unsafeAddr v)
      checkException

  # Array methods
  proc `call typName ArrayMethod`*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): `JVM typName Array` =
    checkInit
    let a = if args.len == 0: nil else: unsafeAddr args[0]
    `typ`.newArray((callVM theEnv.CallStaticObjectMethodA(theEnv, c.get, id.get, a)).newJVMObject)

  proc `call typName ArrayMethod`*(c: JVMClass, name, sig: string, args: openarray[jvalue] = []): `JVM typName Array` =
    checkInit
    let a = if args.len == 0: nil else: unsafeAddr args[0]
    `typ`.newArray((callVM theEnv.CallStaticObjectMethodA(theEnv, c.get, c.getStaticMethodId(name, sig).get, a)).newJVMObject)

  proc `call typName ArrayMethod`*(o: JVMObject, id: JVMMethodID, args: openarray[jvalue] = []): `JVM typName Array` =
    checkInit
    let a = if args.len == 0: nil else: unsafeAddr args[0]
    `typ`.newArray((callVM theEnv.CallObjectMethodA(theEnv, o.get, id.get, a)).newJVMObject)

  proc `call typName ArrayMethod`*(o: JVMObject, name, sig: string, args: openarray[jvalue] = []): `JVM typName Array` =
    checkInit
    let a = if args.len == 0: nil else: unsafeAddr args[0]
    `typ`.newArray((callVM theEnv.CallObjectMethodA(theEnv, o.get, o.getJVMClass.getMethodId(name, sig).get, a)).newJVMObject)

genArrayType(jchar, jcharArray, Char)
genArrayType(jbyte, jbyteArray, Byte)
genArrayType(jshort, jshortArray, Short)
genArrayType(jint, jintArray, Int)
genArrayType(jlong, jlongArray, Long)
genArrayType(jfloat, jfloatArray, Float)
genArrayType(jdouble, jdoubleArray, Double)
genArrayType(jboolean, jbooleanArray, Boolean)
genArrayType(JVMObject, jobjectArray, Object)

####################################################################################################
# Fields accessors generation

template genField(typ: typedesc, typName: untyped): stmt =
  proc `get typName`*(c: JVMClass, id: JVMFieldID): `typ` =
    checkInit
    when `typ` is JVMObject:
      (callVM theEnv.`GetStatic typName Field`(theEnv, c.get, id.get)).newJVMObject
    else:
      (callVM theEnv.`GetStatic typName Field`(theEnv, c.get, id.get))

  proc `get typName`*(c: JVMClass, name: string): `typ` =
    checkInit
    when `typ` is JVMObject:
      (callVM theEnv.`GetStatic typName Field`(theEnv, c.get, c.getStaticFieldId(`name`, `typ`).get)).newJVMObject
    else:
      (callVM theEnv.`GetStatic typName Field`(theEnv, c.get, c.getStaticFieldId(`name`, `typ`).get))

  proc `set typName`*(c: JVMClass, id: JVMFieldID, v: `typ`) =
    checkInit
    when `typ` is JVMObject:
      theEnv.`SetStatic typName Field`(theEnv, c.get, id.get, v.get)
    else:
      theEnv.`SetStatic typName Field`(theEnv, c.get, id.get, v)
    checkException
    
  proc `set typName`*(c: JVMClass, name: string, v: `typ`) =
    checkInit
    when `typ` is JVMObject:
      theEnv.`SetStatic typName Field`(theEnv, c.get, c.getStaticFieldId(`name`, `typ`).get, v.get)
    else:
      theEnv.`SetStatic typName Field`(theEnv, c.get, c.getStaticFieldId(`name`, `typ`).get, v)
    checkException

  proc `get typName`*(o: JVMObject, id: JVMFieldID): `typ` =
    checkInit
    when `typ` is JVMObject:
      (callVM theEnv.`Get typName Field`(theEnv, o.get, id.get)).newJVMObject
    else:
      (callVM theEnv.`Get typName Field`(theEnv, o.get, id.get))

  proc `get typName`*(o: JVMObject, name: string): `typ` =
    checkInit
    when `typ` is JVMObject:
      (callVM theEnv.`Get typName Field`(theEnv, o.get, o.getJVMClass.getFieldId(`name`, `typ`).get)).newJVMObject
    else:
      (callVM theEnv.`Get typName Field`(theEnv, o.get, o.getJVMClass.getFieldId(`name`, `typ`).get))

  proc `set typName`*(o: JVMObject, id: JVMFieldID, v: `typ`) =
    checkInit
    when `typ` is JVMObject:
      theEnv.`Set typName Field`(theEnv, o.get, id.get, v.get)
    else:
      theEnv.`Set typName Field`(theEnv, o.get, id.get, v)
    checkException
    
  proc `set typName`*(o: JVMObject, name: string, v: `typ`) =
    checkInit
    when `typ` is JVMObject:
      theEnv.`Set typName Field`(theEnv, o.get, o.getJVMClass.getFieldId(`name`, `typ`).get, v.get)
    else:
      theEnv.`Set typName Field`(theEnv, o.get, o.getJVMClass.getFieldId(`name`, `typ`).get, v)
    checkException

  when `typ` is JVMObject:
    proc getPropRaw*(T: typedesc[`typ`], c: JVMClass, id: JVMFieldID): jobject =
      checkInit
      (callVM theEnv.`GetStatic typName Field`(theEnv, c.get, id.get))

    proc getPropRaw*(T: typedesc[`typ`], o: JVMObject, id: JVMFieldID): jobject =
      checkInit
      (callVM theEnv.`Get typName Field`(theEnv, o.get, id.get))

    proc setPropRaw*(T: typedesc[`typ`], c: JVMClass, id: JVMFieldID, v: jobject) =
      checkInit
      theEnv.`SetStatic typName Field`(theEnv, c.get, id.get, v)
      checkException
      
    proc setPropRaw*(T: typedesc[`typ`], o: JVMObject, id: JVMFieldID, v: jobject) =
      checkInit
      theEnv.`Set typName Field`(theEnv, o.get, id.get, v)
      checkException
  else:
    # Need to find out, why I can't just call `get typName`. Guess it's Nim's bug
    proc getProp*(T: typedesc[`typ`], c: JVMClass, id: JVMFieldID): `typ` =
      checkInit
      (callVM theEnv.`GetStatic typName Field`(theEnv, c.get, id.get))

    proc getProp*(T: typedesc[`typ`], o: JVMObject, id: JVMFieldID): `typ` =
      checkInit
      (callVM theEnv.`Get typName Field`(theEnv, o.get, id.get))

    proc setProp*(T: typedesc[`typ`], o: JVMClass|JVMObject, id: JVMFieldID, v: `typ`) =
      `set typName`(o, id, v)


genField(JVMObject, Object)
genField(jchar, Char)
genField(jbyte, Byte)
genField(jshort, Short)
genField(jint, Int)
genField(jlong, Long)
genField(jfloat, Float)
genField(jdouble, Double)
genField(jboolean, Boolean)

####################################################################################################
# Methods generation

template genMethod(typ: typedesc, typName: untyped): stmt =
  proc `call typName Method`*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): `typ` =
    checkInit
    let a = if args.len == 0: nil else: unsafeAddr args[0]
    when `typ` is JVMObject:
      (callVM theEnv.`CallStatic typName MethodA`(theEnv, c.get, id.get, a)).newJVMObject
    else:
      callVM theEnv.`CallStatic typName MethodA`(theEnv, c.get, id.get, a)

  proc `call typName Method`*(c: JVMClass, name, sig: string, args: openarray[jvalue] = []): `typ` =
    checkInit
    let a = if args.len == 0: nil else: unsafeAddr args[0]
    when `typ` is JVMObject:
      (callVM theEnv.`CallStatic typName MethodA`(theEnv, c.get, c.getStaticMethodId(name, sig).get, a)).newJVMObject
    else:
      callVM theEnv.`CallStatic typName MethodA`(theEnv, c.get, c.getStaticMethodId(name, sig).get, a)

  proc `call typName Method`*(o: JVMObject, id: JVMMethodID, args: openarray[jvalue] = []): `typ` =
    checkInit
    let a = if args.len == 0: nil else: unsafeAddr args[0]
    when `typ` is JVMObject:
      (callVM theEnv.`Call typName MethodA`(theEnv, o.get, id.get, a)).newJVMObject
    else:
      callVM theEnv.`Call typName MethodA`(theEnv, o.get, id.get, a)

  proc `call typName Method`*(o: JVMObject, name, sig: string, args: openarray[jvalue] = []): `typ` =
    checkInit
    let a = if args.len == 0: nil else: unsafeAddr args[0]
    when `typ` is JVMObject:
      (callVM theEnv.`Call typName MethodA`(theEnv, o.get, o.getJVMClass.getMethodId(name, sig).get, a)).newJVMObject
    else:
      callVM theEnv.`Call typName MethodA`(theEnv, o.get, o.getJVMClass.getMethodId(name, sig).get, a)

  when `typ` is JVMObject:
    proc `call typName MethodRaw`*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): jobject =
      let a = if args.len == 0: nil else: unsafeAddr args[0]
      callVM theEnv.`CallStatic typName MethodA`(theEnv, c.get, id.get, a)

    proc `call typName MethodRaw`*(o: JVMObject, id: JVMMethodID, args: openarray[jvalue] = []): jobject =
      let a = if args.len == 0: nil else: unsafeAddr args[0]
      callVM theEnv.`Call typName MethodA`(theEnv, o.get, id.get, a)

genMethod(JVMObject, Object)
genMethod(jchar, Char)
genMethod(jbyte, Byte)
genMethod(jshort, Short)
genMethod(jint, Int)
genMethod(jlong, Long)
genMethod(jfloat, Float)
genMethod(jdouble, Double)
genMethod(jboolean, Boolean)

####################################################################################################
# Helpers

proc getJVMException*(ex: JavaException): JVMObject =
  ex.ex

proc toJVMObject*(s: string): JVMObject =
  newJVMObject(s)

type JPrimitiveType = jint | jfloat | jboolean | jdouble | jshort | jlong | jchar | jbyte

proc toJVMObject*[T](a: openarray[T]): JVMObject =
  when T is JVMObject:
    var arr = JVMObject.newArray(a.len)
    for i, v in a:
      arr[i] = v
    result = arr.toJVMObject
  elif compiles(toJVMObject(a[0])):
    var arr = JVMObject.newArray(a.len)
    for i, v in a:
      arr[i] = v.toJVMObject
    result = arr.toJVMObject
  elif T is JPrimitiveType:
    var arr = T.newArray(a.len)
    for i, v in a:
      arr[i] = v
    result = arr.toJVMObject
  else:
    {.error: "define toJVMObject method for the openarray element type".}

template jarrayToSeqImpl[T](arr: jarray, res: var seq[T]) =
  checkInit
  res = nil
  if arr == nil:
    return
  let length = theEnv.GetArrayLength(theEnv, arr)
  res = newSeq[T](length.int)
  when T is JPrimitiveType:
    getArrayRegion(arr, 0, length, addr(res[0]))
  elif compiles(T.fromJObject(nil.jobject)):
    for i in 0..<res.len:
      res[i] = T.fromJObject(theEnv.GetObjectArrayElement(theEnv, arr.jobjectArray, i.jsize))
  elif T is string:
    for i in 0..<res.len:
      res[i] = theEnv.GetObjectArrayElement(theEnv, arr.jobjectArray, i.jsize).newJVMObject.toStringRaw
  else:
    {.fatal: "Sequences is not supported for the supplied type".}

proc jarrayToSeq[T](arr: jarray, t: typedesc[seq[T]]): seq[T] {.inline.} =
  jarrayToSeqImpl(arr, result)

template getPropValue*(T: typedesc, o: expr, id: JVMFieldID): expr {.immediate.} =
  when T is bool:
    (jboolean.getProp(o, id) == JVM_TRUE)
  elif T is JPrimitiveType:
    T.getProp(o, id)
  elif T is string:
    JVMObject.getPropRaw(o, id).newJVMObject.toStringRaw
  elif compiles(T.fromJObject(nil.jobject)):
    T.fromJObject(JVMObject.getPropRaw(o, id))
  elif T is seq:
    T(jarrayToSeq(JVMObject.getPropRaw(o, id).jarray, T))
  else:
    {.error: "Unknown property type".}

template setPropValue*(T: typedesc, o: expr, id: JVMFieldID, v: T): expr {.immediate.} =
  when T is bool:
    jboolean.setProp(o, id, if v: JVM_TRUE else: JVM_FALSE)
  elif T is JPrimitiveType:
    T.setProp(o, id, v)
  elif compiles(toJVMObject(v)):
    JVMObject.setPropRaw(o, id, toJVMObject(v).get)
  else:
    {.error: "Unknown property type".}

template callMethod*(T: typedesc, o: expr, methodId: JVMMethodID, args: openarray[jvalue]): expr {.immediate.} =
  when T is void:
    o.callVoidMethod(methodId, args)
  elif T is jchar:
    o.callCharMethod(methodId, args)
  elif T is jbyte:
    o.callByteMethod(methodId, args)
  elif T is jshort:
    o.callShortMethod(methodId, args)
  elif T is jint:
    o.callIntMethod(methodId, args)
  elif T is jlong:
    o.callLongMethod(methodId, args)
  elif T is jfloat:
    o.callFloatMethod(methodId, args)
  elif T is jdouble:
    o.callDoubleMethod(methodId, args)
  elif T is jboolean:
    o.callBooleanMethod(methodId, args)
  elif T is bool:
    (o.callBooleanMethod(methodId, args) == JVM_TRUE)
  elif T is seq:
    T(jarrayToSeq(o.callObjectMethodRaw(methodId, args).jarray, T))
  elif T is string:
    o.callObjectMethod(methodId, args).toStringRaw
  elif compiles(T.fromJObject(nil.jobject)):
    T.fromJObject(o.callObjectMethodRaw(methodId, args))
  else:
    {.error: "Unknown return type".}

proc instanceOfRaw*(obj: JVMObject, cls: JVMClass): bool =
  checkInit
  callVM theEnv.IsInstanceOf(theEnv, obj.obj, cls.cls) == JVM_TRUE
