import jni_wrapper, fp.option, macros

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
var theEnv {.threadVar}: JNIEnvPtr

proc initJNIThread* {.gcsafe.}
proc initJNI*(version: JNIVersion, options: seq[string]) =
  ## Setup JNI API
  jniAssert(not theOptions.isDefined, "JNI API already initialized, you must deinitialize it first")
  theOptions = (version, options).some
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

template checkInit = jniAssert(theEnv != nil, "You must call initJNIThread before using JNI API")

####################################################################################################
# Types
type
  JVMMethodID* = ref object
    id: jmethodID
  JVMFieldID* = ref object
    id: jfieldID
  JVMClass* = ref object
    cls: jclass
  JVMObject* = ref object
    obj: jobject

proc jniSig*(T: typedesc[JVMObject]): string = fqcn"java.lang.Object"
  
#################################################################################################### 
# Exception handling

type
  JavaException* = object of Exception

proc newJavaException*(msg: string): ref JavaException =
  newException(JavaException, msg)

proc newJVMObject*(o: jobject): JVMObject
proc toStringRaw*(o: JVMObject): string
template checkException: stmt =
  #TODO: Add stack trace support
  if theEnv != nil and theEnv.ExceptionCheck(theEnv) == JVM_TRUE:
    let ex = theEnv.ExceptionOccurred(theEnv).newJVMObject
    theEnv.ExceptionClear(theEnv)
    raise newJavaException(ex.toStringRaw)
  
macro callVM(s: expr): expr =
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

####################################################################################################
# JVMObject type

proc freeJVMObject(o: JVMObject) =
  if o.obj != nil and theEnv != nil:
    theEnv.DeleteLocalRef(theEnv, o.obj)

proc newJVMObject*(o: jobject): JVMObject =
  new(result, freeJVMObject)
  result.obj = o

proc newJVMObject*(s: string): JVMObject =
  (callVM theEnv.NewStringUTF(theEnv, s)).newJVMObject

proc get*(o: JVMObject): jobject =
  o.obj

proc toJValue*(o: JVMObject): jvalue =
  o.get.toJValue

proc getClass*(o: JVMObject): JVMClass =
  checkInit
  (callVM theEnv.GetObjectClass(theEnv, o.get)).newJVMClass
  
proc toStringRaw(o: JVMObject): string =
  # This is low level ``toString`` version
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
  theEnv.CallVoidMethodA(theEnv, o.get, o.getClass.getMethodId(name, sig).get, a)
  checkException

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
      (callVM theEnv.`Get typName Field`(theEnv, o.get, o.getClass.getFieldId(`name`, `typ`).get)).newJVMObject
    else:
      (callVM theEnv.`Get typName Field`(theEnv, o.get, o.getClass.getFieldId(`name`, `typ`).get))

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
      theEnv.`Set typName Field`(theEnv, o.get, o.getClass.getFieldId(`name`, `typ`).get, v.get)
    else:
      theEnv.`Set typName Field`(theEnv, o.get, o.getClass.getFieldId(`name`, `typ`).get, v)
    checkException

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

genMethod(JVMObject, Object)
genMethod(jchar, Char)
genMethod(jbyte, Byte)
genMethod(jshort, Short)
genMethod(jint, Int)
genMethod(jlong, Long)
genMethod(jfloat, Float)
genMethod(jdouble, Double)
genMethod(jboolean, Boolean)
