import jni_wrapper, options, macros, strutils

export jni_wrapper

type
  JNIVersion* {.pure.} = enum
    v1_1 = JNI_VERSION_1_1.int,
    v1_2 = JNI_VERSION_1_2.int,
    v1_4 = JNI_VERSION_1_4.int,
    v1_6 = JNI_VERSION_1_6.int,
    v1_8 = JNI_VERSION_1_8.int

var initArgs: JavaVMInitArgs

# Options for another threads
var theVM: JavaVMPtr
var theEnv* {.threadVar}: JNIEnvPtr
var findClassOverride* {.threadVar.}: proc(env: JNIEnvPtr, name: cstring): JClass

proc initJNIThread* {.gcsafe.}

proc initJNIArgs(version: JNIVersion = JNIVersion.v1_6, options: openarray[string] = []) =
  ## Setup JNI API
  jniAssert(initArgs.version == 0, "JNI API already initialized, you must deinitialize it first")
  initArgs.version = version.jint
  initArgs.nOptions = options.len.jint
  if options.len != 0:
    var opts = cast[ptr UncheckedArray[JavaVMOption]](createShared(JavaVMOption, options.len))
    initArgs.options = addr opts[0]
    for i in 0 ..< options.len:
      opts[i].optionString = cast[cstring](allocShared(options[i].len + 1))
      opts[i].optionString[0] = '\0'
      if options[i].len != 0:
        copyMem(addr opts[i].optionString[0], unsafeAddr options[i][0], options[i].len + 1)

proc initJNI*(version: JNIVersion = JNIVersion.v1_6, options: openarray[string] = []) =
  ## Setup JNI API
  initJNIArgs(version, options)
  initJNIThread()

proc initJNI*(env: JNIEnvPtr) =
  theEnv = env

proc initJNI*(vm: JavaVMPtr) =
  theVM = vm

# This is not supported, as it said here: http://docs.oracle.com/javase/7/docs/technotes/guides/jni/spec/invocation.html#destroy_java_vm:
# "As of JDK/JRE 1.1.2 unloading of the VM is not supported."
# Maybe it can be usefull with alternative implementations of JRE
when false:
  proc deinitJNI* =
    ## Deinitialize JNI API
    if theVM == nil:
      return
    jniCall theVM.DestroyJavaVM(theVM), "Error deinitializing JNI"
    # TODO: dealloc initArgs
    theVM = nil
    theEnv = nil

proc initJNIThread* =
  ## Setup JNI API thread
  if theEnv != nil:
    return
  if initArgs.version == 0:
    raise newJNIException("You must initialize JNI API before using it")

  if theVM == nil:
    # We need to link with JNI and so on
    linkWithJVMLib()
    jniCall JNI_CreateJavaVM(theVM.addr, cast[ptr pointer](theEnv.addr), initArgs.addr), "Error creating VM"
  else:
    # We need to attach current thread to JVM
    jniCall theVM.AttachCurrentThread(theVM, cast[ptr pointer](theEnv.addr), initArgs.addr), "Error attaching thread to VM"

proc deinitJNIThread* =
  ## Deinitialize JNI API thread
  if theEnv == nil:
    return
  discard theVM.DetachCurrentThread(theVM)
  theEnv = nil

proc isJNIThreadInitialized*: bool = theEnv != nil

proc findRunningVM() =
  if theVM.isNil:
    if JNI_GetCreatedJavaVMs.isNil:
        linkWithJVMLib()

    var vmBuf: array[1, JavaVMPtr]
    var bufSize : jsize = 0
    discard JNI_GetCreatedJavaVMs(addr vmBuf[0], jsize(vmBuf.len), addr bufSize)
    if bufSize > 0:
        theVM = vmBuf[0]
    else:
        raise newJNIException("No JVM is running. You must call initJNIThread before using JNI API.")

  let res = theVM.GetEnv(theVM, cast[ptr pointer](theEnv.addr), JNI_VERSION_1_6)
  if res == JNI_EDETACHED:
      initJNIArgs()
      initJNIThread()
  elif res != 0:
      raise newJNIException("GetEnv result: " & $res)
  if theEnv.isNil:
      raise newJNIException("No JVM found")

template checkInit* =
  if theEnv.isNil: findRunningVM()

template deleteLocalRef*(env: JNIEnvPtr, r: jobject) =
  env.DeleteLocalRef(env, r)

template deleteGlobalRef*(env: JNIEnvPtr, r: jobject) =
  env.DeleteGlobalRef(env, r)

template newGlobalRef*[T : jobject](env: JNIEnvPtr, r: T): T =
  cast[T](env.NewGlobalRef(env, r))

####################################################################################################
# Types
type
  JVMMethodID* = distinct jmethodID
  JVMFieldID* = distinct jfieldID
  JVMClass* = ref object
    cls: JClass
  JVMObjectObj {.inheritable.} = object
    obj: jobject
  JVMObject* = ref JVMObjectObj
  JnimNonVirtual_JVMObject* {.inheritable.} = object # Not for public use!
    obj*: jobject
    # clazz*: JVMClass


proc freeJVMObjectObj(o: var JVMObjectObj) =
  if o.obj != nil and theEnv != nil:
    theEnv.deleteGlobalRef(o.obj)
    o.obj = nil

when defined(gcDestructors):
  proc `=destroy`*(o: var JVMObjectObj) =
    freeJVMObjectObj(o)

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
proc newJVMObjectConsumingLocalRef*(o: jobject): JVMObject

proc raiseJavaException() =
  let ex = theEnv.ExceptionOccurred(theEnv)
  theEnv.ExceptionClear(theEnv)
  raise newJavaException(newJVMObjectConsumingLocalRef(ex))

proc checkJVMException*(e: JNIEnvPtr) {.inline.} =
  if unlikely(theEnv.ExceptionCheck(theEnv) != JVM_FALSE):
    raiseJavaException()

template checkException() =
  assert(not theEnv.isNil)
  checkJVMException(theEnv)

proc callVM*[T](s: T): T {.inline.} =
  checkException()
  when T isnot void:
    return s

####################################################################################################
# JVMMethodID type
template newJVMMethodID*(id: jmethodID): JVMMethodID = JVMMethodID(id)
template get*(id: JVMMethodID): jmethodID = jmethodID(id)

####################################################################################################
# JVMFieldID type
template newJVMFieldID*(id: jfieldID): JVMFieldID = JVMFieldID(id)
template get*(id: JVMFieldID): jfieldID = jfieldID(id)

####################################################################################################
# JVMClass type
proc freeClass(c: JVMClass) =
  if theEnv != nil:
    theEnv.deleteGlobalRef(c.cls)

proc newJVMClass*(c: JClass): JVMClass =
  assert(cast[pointer](c) != nil)
  result.new(freeClass)
  result.cls = theEnv.newGlobalRef(c)

proc findClass*(env: JNIEnvPtr, name: cstring): JClass =
  if not findClassOverride.isNil:
    result = findClassOverride(env, name)
  else:
    result = env.FindClass(env, name)

proc getByFqcn*(T: typedesc[JVMClass], name: cstring): JVMClass =
  ## Finds class by it's full qualified class name
  checkInit
  let c = callVM findClass(theEnv, name)
  result = c.newJVMClass
  theEnv.deleteLocalRef(c)

proc getByName*(T: typedesc[JVMClass], name: string): JVMClass =
  ## Finds class by it's name (not fqcn)
  T.getByFqcn(name.fqcn)

proc getJVMClass*(o: jobject): JVMClass {.inline.} =
  checkInit
  let c = callVM theEnv.GetObjectClass(theEnv, o)
  result = c.newJVMClass
  theEnv.deleteLocalRef(c)

proc get*(c: JVMClass): JClass =
  c.cls

# Static fields

proc getStaticFieldId*(c: JVMClass, name, sig: cstring): JVMFieldID =
  checkInit
  (callVM theEnv.GetStaticFieldID(theEnv, c.get, name, sig)).newJVMFieldID

proc getStaticFieldId*(c: JVMClass, name: cstring, t: typedesc): JVMFieldID {.inline.} =
  getStaticFieldId(c, name, jniSig(t))

proc getFieldId*(c: JVMClass, name, sig: cstring): JVMFieldID =
  checkInit
  (callVM theEnv.GetFieldID(theEnv, c.get, name, sig)).newJVMFieldID

proc getFieldId*(c: JVMClass, name: cstring, t: typedesc): JVMFieldID {.inline.} =
  getFieldId(c, name, jniSig(t))

proc getFieldId*(c: JVMObject, name, sig: cstring): JVMFieldID =
  checkInit
  let clazz = callVM theEnv.GetObjectClass(theEnv, c.obj)
  result = (callVM theEnv.GetFieldID(theEnv, clazz, name, sig)).newJVMFieldID
  theEnv.deleteLocalRef(clazz)

proc getFieldId*(c: JVMObject, name: cstring, t: typedesc): JVMFieldID {.inline.} =
  getFieldId(c, name, jniSig(t))

proc getMethodId*(c: JVMClass, name, sig: cstring): JVMMethodID =
  checkInit
  (callVM theEnv.GetMethodID(theEnv, c.get, name, sig)).newJVMMethodID

proc getMethodId*(c: JVMObject, name, sig: cstring): JVMMethodID =
  checkInit
  let clazz = callVM theEnv.GetObjectClass(theEnv, c.obj)
  result = (callVM theEnv.GetMethodID(theEnv, clazz, name, sig)).newJVMMethodID
  theEnv.deleteLocalRef(clazz)

proc getStaticMethodId*(c: JVMClass, name, sig: cstring): JVMMethodID =
  checkInit
  (callVM theEnv.GetStaticMethodID(theEnv, c.get, name, sig)).newJVMMethodID

proc callVoidMethod*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []) =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  theEnv.CallStaticVoidMethodA(theEnv, c.get, id.get, a)
  checkException

proc callVoidMethod*(c: JVMClass, name, sig: cstring, args: openarray[jvalue] = []) =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  theEnv.CallStaticVoidMethodA(theEnv, c.get, c.getStaticMethodId(name, sig).get, a)
  checkException

proc newObject*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): JVMObject =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  (callVM theEnv.NewobjectA(theEnv, c.get, id.get, a)).newJVMObjectConsumingLocalRef

proc newObject*(c: JVMClass, sig: cstring, args: openarray[jvalue] = []): JVMObject =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  (callVM theEnv.NewobjectA(theEnv, c.get, c.getMethodId("<init>", sig).get, a)).newJVMObjectConsumingLocalRef

proc newObjectRaw*(c: JVMClass, sig: cstring, args: openarray[jvalue] = []): jobject =
  checkInit
  let a = if args.len == 0: nil else: unsafeAddr args[0]
  callVM theEnv.NewobjectA(theEnv, c.get, c.getMethodId("<init>", sig).get, a)

####################################################################################################
# JVMObject type

proc jniSig*(T: typedesc[JVMObject]): string = sigForClass"java.lang.Object"

proc freeJVMObject*(o: JVMObject) =
  freeJVMObjectObj(o[])

proc free*(o: JVMObject) {.deprecated.} =
  o.freeJVMObject()

proc fromJObject*(T: typedesc[JVMObject], o: jobject): T =
  if o != nil:
    when defined(gcDestructors):
      result.new()
    else:
      result.new(cast[proc(r: T) {.nimcall.}](freeJVMObject))
    checkInit
    result.obj = theEnv.newGlobalRef(o)

proc fromJObjectConsumingLocalRef*(T: typedesc[JVMObject], o: jobject): T =
  if not o.isNil:
    result = T.fromJObject(o)
    theEnv.deleteLocalRef(o)

proc newJVMObject*(o: jobject): JVMObject =
  JVMObject.fromJObject(o)

proc newJVMObjectConsumingLocalRef*(o: jobject): JVMObject =
  if not o.isNil:
    result = newJVMObject(o)
    theEnv.deleteLocalRef(o)

proc create*(t: typedesc[JVMObject], o: jobject): JVMObject = newJVMObject(o)

proc newJVMObject*(s: string): JVMObject =
  result = (callVM theEnv.NewStringUTF(theEnv, s)).newJVMObjectConsumingLocalRef

proc get*(o: JVMObject): jobject =
  assert(not o.obj.isNil)
  o.obj

proc getNoCreate*(o: JVMObject): jobject {.inline.} = o.obj

proc setObj*(o: JVMObject, obj: jobject) =
  assert(obj == nil or theEnv.GetObjectRefType(theEnv, obj) in {JNILocalRefType, JNIWeakGlobalRefType})
  o.obj = obj

proc toJValue*(o: JVMObject): jvalue =
  if not o.isNil:
    result = o.get.toJValue

proc getJVMClass*(o: JVMObject): JVMClass =
  assert(o.get != nil)
  getJVMClass(o.get)

proc equalsRaw*(v1, v2: JVMObject): jboolean =
  # This is low level ``equals`` version
  assert v1.obj != nil
  let cls = theEnv.GetObjectClass(theEnv, v1.obj)
  jniAssertEx(cls.pointer != nil, "Can't find object's class")
  const sig = "($#)$#" % [jobject.jniSig, jboolean.jniSig]
  let mthId = theEnv.GetMethodID(theEnv, cls, "equals", sig)
  theEnv.deleteLocalRef(cls)
  jniAssertEx(mthId != nil, "Can't find ``equals`` method")
  var v2w = v2.obj.toJValue
  result = theEnv.CallBooleanMethodA(theEnv, v1.obj, mthId, addr v2w)

proc jstringToStringAux(s: jstring): string =
  assert(not s.isNil)
  let numBytes = theEnv.GetStringUTFLength(theEnv, s)
  result = newString(numBytes)
  if numBytes != 0:
    let numChars = theEnv.GetStringLength(theEnv, s)
    theEnv.GetStringUTFRegion(theEnv, s, 0, numChars, addr result[0])

proc toStringRaw(o: jobject): string =
  # This is low level ``toString`` version.
  assert(not o.isNil)
  let cls = theEnv.GetObjectClass(theEnv, o)
  jniAssertEx(cls.pointer != nil, "Can't find object's class")
  const sig = "()" & string.jniSig
  let mthId = theEnv.GetMethodID(theEnv, cls, "toString", sig)
  theEnv.deleteLocalRef(cls)
  jniAssertEx(mthId != nil, "Can't find ``toString`` method")
  let s = theEnv.CallObjectMethodA(theEnv, o, mthId, nil).jstring
  if s == nil:
    return ""
  result = jstringToStringAux(s)
  theEnv.deleteLocalRef(s)

proc toStringRawConsumingLocalRef(o: jobject): string =
  # This is low level ``toString`` version
  if not o.isNil:
    result = toStringRaw(o)
    theEnv.deleteLocalRef(o)

proc toStringRaw(o: JVMObject): string =
  # This is low level ``toString`` version
  if o.isNil:
    return ""
  toStringRaw(o.obj)

####################################################################################################
# Arrays support

type JVMArray[T] = ref object
  arr: jtypedArray[T]

proc get*[T](arr: JVMArray[T]): jtypedArray[T] = arr.arr
proc jniSig*[T](t: typedesc[JVMArray[T]]): string = "[" & jniSig(T)
proc freeJVMArray[T](a: JVMArray[T]) =
  if a.arr != nil and theEnv != nil:
    theEnv.deleteGlobalRef(a.arr)

proc newArray*(T: typedesc, len: int): JVMArray[T] =
  checkInit
  new(result, freeJVMArray[T])
  let j = callVM theEnv.newArray(T, len.jsize)
  result.arr = theEnv.newGlobalRef(j)
  theEnv.deleteLocalRef(j)

proc len*(arr: JVMArray): jsize =
  callVM theEnv.GetArrayLength(theEnv, arr.get)

template genArrayType(typ, arrTyp: typedesc, typName: untyped): untyped =

  # Creation

  type `JVM typName Array`* {.inject.} = JVMArray[typ]

  when `typ` isnot jobject:
    proc `newJVM typName Array`*(len: jsize): JVMArray[typ] {.inline, deprecated.} =
      newArray(`typ`, len.int)

  else:

    proc `newJVM typName Array`*(len: jsize, cls = JVMClass.getByName("java.lang.Object")): JVMArray[typ] =
      checkInit
      new(result, freeJVMArray[jobject])
      let j = callVM theEnv.NewObjectArray(theEnv, len, cls.get, nil)
      result.arr = theEnv.newGlobalRef(j)
      theEnv.deleteLocalRef(j)

    proc newArray*(c: JVMClass, len: int): JVMArray[typ] =
      `newJVM typName Array`(len.jsize, c)

    proc newArray*(t: typedesc[JVMObject], len: int): JVMArray[typ] =
      `newJVM typName Array`(len.jsize, JVMClass.getByName("java.lang.Object"))

  proc `newJVM typName Array`*(arr: jobject): JVMArray[typ] =
    checkInit
    new(result, freeJVMArray[typ])
    result.arr = theEnv.newGlobalRef(arr).`arrTyp`

  proc `newJVM typName Array`*(arr: JVMObject): JVMArray[typ] =
    `newJVM typName Array`(arr.get)

  proc newArray*(t: typedesc[typ], arr: jobject): JVMArray[typ] = `newJVM typName Array`(arr)

  proc newArray*(t: typedesc[typ], arr: JVMObject): JVMArray[typ] =
    `newJVM typName Array`(arr.get)

  proc toJVMObject*(a: JVMArray[typ]): JVMObject =
    checkInit
    newJVMObject(a.arr.jobject)

  # getters/setters

  proc `get typName Array`*(c: JVMClass, name: cstring): JVMArray[typ] =
    checkInit
    let j = callVM theEnv.GetStaticObjectField(theEnv, c.get, c.getStaticFieldId(name, seq[`typ`].jniSig).get)
    result = `typ`.newArray(j)
    theEnv.deleteLocalRef(j)

  proc `get typName Array`*(o: JVMObject, name: cstring): JVMArray[typ] =
    checkInit
    let j = callVM theEnv.GetObjectField(theEnv, o.get, o.getFieldId(name, seq[`typ`].jniSig).get)
    result = `typ`.newArray(j)
    theEnv.deleteLocalRef(j)

  proc `set typName Array`*(c: JVMClass, name: cstring, arr: JVMArray[typ]) =
    checkInit
    theEnv.SetStaticObjectField(theEnv, c.get, c.getStaticFieldId(name, seq[`typ`].jniSig).get, arr.arr)
    checkException

  proc `set typName Array`*(o: JVMObject, name: cstring, arr: JVMArray[typ]) =
    checkInit
    theEnv.SetObjectField(theEnv, o.get, o.getFieldId(name, seq[`typ`].jniSig).get, arr.arr)
    checkException


  # Array methods
  proc `call typName ArrayMethod`*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): JVMArray[typ] =
    checkInit
    let a = if args.len == 0: nil else: unsafeAddr args[0]
    let j = callVM theEnv.CallStaticObjectMethodA(theEnv, c.get, id.get, a)
    result = `typ`.newArray(j)
    theEnv.deleteLocalRef(j)

  proc `call typName ArrayMethod`*(c: JVMClass, name, sig: cstring, args: openarray[jvalue] = []): JVMArray[typ] =
    `call typName ArrayMethod`(c, c.getStaticMethodId(name, sig), args)

  proc `call typName ArrayMethod`*(o: JVMObject, id: JVMMethodID, args: openarray[jvalue] = []): JVMArray[typ] =
    checkInit
    let a = if args.len == 0: nil else: unsafeAddr args[0]
    let j = callVM theEnv.CallObjectMethodA(theEnv, o.get, id.get, a)
    result = `typ`.newArray(j)
    theEnv.deleteLocalRef(j)

  proc `call typName ArrayMethod`*(o: JVMObject, name, sig: cstring, args: openarray[jvalue] = []): JVMArray[typ] {.inline.} =
    `call typName ArrayMethod`(o, o.getMethodId(name, sig), args)

genArrayType(jchar, jcharArray, Char)
genArrayType(jbyte, jbyteArray, Byte)
genArrayType(jshort, jshortArray, Short)
genArrayType(jint, jintArray, Int)
genArrayType(jlong, jlongArray, Long)
genArrayType(jfloat, jfloatArray, Float)
genArrayType(jdouble, jdoubleArray, Double)
genArrayType(jboolean, jbooleanArray, Boolean)
genArrayType(jobject, jobjectArray, Object)

proc `[]`*[T](arr: JVMArray[T], idx: Natural): T =
  checkInit
  when T is jobject:
    callVM theEnv.GetObjectArrayElement(theEnv, arr.get, idx.jsize)
  elif T is JVMObject:
    (callVM theEnv.GetObjectArrayElement(theEnv, arr.get, idx.jsize)).newJVMObjectConsumingLocalRef
  else:
    theEnv.getArrayRegion(arr.get, idx.jsize, 1, addr result)
    checkException

proc `[]=`*[T, V](arr: JVMArray[T], idx: Natural, v: V) =
  checkInit
  theEnv.setArrayRegion(arr.get, idx.jsize, 1, unsafeAddr v)
  checkException

proc `[]=`*(arr: JVMArray[jobject], idx: Natural, v: JVMObject|jobject) =
  checkInit
  let vv = when v is jobject: v
            else: v.get
  theEnv.SetObjectArrayElement(theEnv, arr.get, idx.jsize, vv)
  checkException

####################################################################################################
# Fields accessors generation
proc getField*(c: JVMClass, T: typedesc, id: JVMFieldID): T =
  checkInit
  when T is JVMObject:
    (callVM theEnv.getStaticField(jobject, c.get, id.get)).newJVMObjectConsumingLocalRef
  else:
    (callVM theEnv.getStaticField(T, c.get, id.get))

proc getField*(c: JVMClass, T: typedesc, name: cstring): T {.inline.} =
  getField(c, T, c.getStaticFieldId(name, T))

proc setField*[T](c: JVMClass, id: JVMFieldID, v: T) =
  checkInit
  when T is JVMObject:
    theEnv.setStaticField(c.get, id.get, v.get)
  else:
    theEnv.setStaticField(c.get, id.get, v)
  checkException

proc setField*[T](c: JVMClass, name: cstring, v: T) =
  setField(c, c.getStaticFieldId(name, T), v)

proc getField*(o: JVMObject, T: typedesc, id: JVMFieldID): T =
  checkInit
  when T is JVMObject:
    (callVM theEnv.getField(jobject, o.get, id.get)).newJVMObjectConsumingLocalRef
  else:
    (callVM theEnv.getField(T, o.get, id.get))

proc getField*(o: JVMObject, T: typedesc, name: cstring): T =
  getField(o, T, o.getFieldId(name, T))

proc setField*[T](o: JVMObject, id: JVMFieldID, v: T) =
  checkInit
  when T is JVMObject:
    theEnv.setField(o.get, id.get, v.get)
  else:
    theEnv.setField(o.get, id.get, v)
  checkException

proc setField*[T](o: JVMObject, name: cstring, v: T) =
  setField(o, o.getFieldId(name, T), v)

template genField(typ: typedesc, typName: untyped): untyped =
  proc `get typName`*(c: JVMClass, id: JVMFieldID): typ {.inline.} =
    getField(c, typ, id)

  proc `get typName`*(c: JVMClass, name: string): typ {.inline.} =
    getField(c, typ, name)

  proc `set typName`*(c: JVMClass, id: JVMFieldID, v: typ) {.inline.} =
    setField(c, id, v)

  proc `set typName`*(c: JVMClass, name: string, v: typ) {.inline.} =
    setField(c, name, v)

  proc `get typName`*(o: JVMObject, id: JVMFieldID): typ {.inline.} =
    getField(o, typ, id)

  proc `get typName`*(o: JVMObject, name: string): typ {.inline.} =
    getField(o, typ, name)

  proc `set typName`*(o: JVMObject, id: JVMFieldID, v: typ) {.inline.} =
    setField(o, id, v)

  proc `set typName`*(o: JVMObject, name: string, v: typ) {.inline.} =
    setField(o, name, v)


genField(JVMObject, Object)
genField(jchar, Char)
genField(jbyte, Byte)
genField(jshort, Short)
genField(jint, Int)
genField(jlong, Long)
genField(jfloat, Float)
genField(jdouble, Double)
genField(jboolean, Boolean)

proc callMethod*(c: JVMClass, retType: typedesc, id: JVMMethodId, args: openarray[jvalue] = []): retType =
  checkInit
  when retType is JVMObject:
    (callVM theEnv.callStaticMethod(jobject, c.get, id.get, args)).newJVMObjectConsumingLocalRef
  else:
    callVM theEnv.callStaticMethod(retType, c.get, id.get, args)

proc callMethod*(c: JVMClass, retType: typedesc, name, sig: cstring, args: openarray[jvalue] = []): retType {.inline.} =
  callMethod(c, retType, c.getStaticMethodId(name, sig), args)

proc callMethod*(o: JVMObject, retType: typedesc, id: JVMMethodID, args: openarray[jvalue] = []): retType =
  checkInit
  when retType is JVMObject:
    (callVM theEnv.callMethod(jobject, o.get, id.get, args)).newJVMObjectConsumingLocalRef
  else:
    callVM theEnv.callMethod(retType, o.get, id.get, args)

proc callMethod*(o: JVMObject, retType: typedesc, name, sig: cstring, args: openarray[jvalue] = []): retType {.inline.} =
  callMethod(o, retType, o.getMethodId(name, sig), args)

proc callMethod*(o: JnimNonVirtual_JVMObject, retType: typedesc, c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): retType =
  when retType is JVMObject:
    (callVM theEnv.callNonVirtualMethod(jobject, o.obj, c.get, id.get, args)).newJVMObjectConsumingLocalRef
  else:
    callVM theEnv.callNonVirtualMethod(retType, o.obj, c.get, id.get, args)

####################################################################################################
# Methods generation

template genMethod(typ: typedesc, typName: untyped): untyped =
  proc `call typName Method`*(c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): `typ` {.inline, deprecated.} =
    callMethod(c, typ, id, args)

  proc `call typName Method`*(c: JVMClass, name, sig: string, args: openarray[jvalue] = []): `typ` {.inline, deprecated.} =
    callMethod(c, typ, name, sig, args)

  proc `call typName Method`*(o: JVMObject, id: JVMMethodID, args: openarray[jvalue] = []): `typ` {.inline, deprecated.} =
    callMethod(o, typ, id, args)

  proc `call typName Method`*(o: JVMObject, name, sig: cstring, args: openarray[jvalue] = []): `typ` {.inline, deprecated.} =
    callMethod(o, typ, name, sig, args)

  proc `call typName Method`*(o: JnimNonVirtual_JVMObject, c: JVMClass, id: JVMMethodID, args: openarray[jvalue] = []): `typ` {.inline, deprecated.} =
    callMethod(o, typ, c, id, args)

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

proc toJVMObject*(s: string): JVMObject {.inline.} =
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
  if arr == nil:
    return
  let length = theEnv.GetArrayLength(theEnv, arr)
  res = newSeq[T](length.int)
  when T is JPrimitiveType:
    type TT = T
    if length != 0:
      theEnv.getArrayRegion(jtypedArray[TT](arr), 0, length, addr(res[0]))
  elif T is JVMObject:
    type TT = T
    for i in 0..<res.len:
      res[i] = fromJObjectConsumingLocalRef(TT, theEnv.GetObjectArrayElement(theEnv, arr.jobjectArray, i.jsize))
  elif T is string:
    for i in 0..<res.len:
      res[i] = toStringRawConsumingLocalRef(theEnv.GetObjectArrayElement(theEnv, arr.jobjectArray, i.jsize))
  else:
    {.fatal: "Sequences is not supported for the supplied type".}

proc jarrayToSeqConsumingLocalRef[T](arr: jarray, t: typedesc[seq[T]]): seq[T] {.inline.} =
  jarrayToSeqImpl(arr, result)
  theEnv.deleteLocalRef(arr)

template getPropValue*(T: typedesc, o: untyped, id: JVMFieldID): untyped =
  when T is bool:
    (getField(o, jboolean, id) != JVM_FALSE)
  elif T is JPrimitiveType:
    getField(o, T, id)
  elif T is string:
    toStringRawConsumingLocalRef(getField(o, jobject, id))
  elif T is JVMObject:
    fromJObjectConsumingLocalRef(T, getField(o, jobject, id))
  elif T is seq:
    T(jarrayToSeqConsumingLocalRef(getField(o, jobject, id).jarray, T))
  else:
    {.error: "Unknown property type".}

template setPropValue*(T: typedesc, o: untyped, id: JVMFieldID, v: T) =
  when T is bool:
    setField(o, id, if v: JVM_TRUE else: JVM_FALSE)
  elif T is JPrimitiveType:
    setField(o, id, v)
  elif compiles(toJVMObject(v)):
    setField(o, id, toJVMObject(v).get)
  else:
    {.error: "Unknown property type".}

template callMethod*(T: typedesc, o: untyped, methodId: JVMMethodID, args: openarray[jvalue]): untyped =
  when T is JVMValueType|void:
    o.callMethod(T, methodId, args)
  elif T is bool:
    (o.callMethod(jboolean, methodId, args) != JVM_FALSE)
  elif T is seq:
    T(jarrayToSeqConsumingLocalRef(o.callMethod(jobject, methodId, args).jarray, T))
  elif T is string:
    toStringRawConsumingLocalRef(o.callMethod(jobject, methodId, args))
  elif T is JVMObject:
    fromJObjectConsumingLocalRef(T, o.callMethod(jobject, methodId, args))
  else:
    {.error: "Unknown return type" & $T.}

template callNonVirtualMethod*(T: typedesc, o: JnimNonVirtual_JVMObject, c: JVMClass, methodId: JVMMethodID, args: openarray[jvalue]): untyped =
  when T is JVMValueType|void:
    o.callMethod(T, c, methodId, args)
  elif T is bool:
    (o.callMethod(jboolean, c, methodId, args) != JVM_FALSE)
  elif T is seq:
    T(jarrayToSeqConsumingLocalRef(o.callMethod(jobject, c, methodId, args).jarray, T))
  elif T is string:
    toStringRawConsumingLocalRef(o.callMethod(jobject, c, methodId, args))
  elif T is JVMObject:
    fromJObjectConsumingLocalRef(T, o.callMethod(jobject, c, methodId, args))
  else:
    {.error: "Unknown return type " & $T.}

proc instanceOfRaw*(obj: JVMObject, cls: JVMClass): bool =
  checkInit
  callVM theEnv.IsInstanceOf(theEnv, obj.obj, cls.cls) != JVM_FALSE

proc `$`*(s: jstring): string =
  checkInit
  if s != nil:
    result = jstringToStringAux(s)
