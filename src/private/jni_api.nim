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
var theVM: JavaVMPtr
var theEnv {.threadVar}: JNIEnvPtr

proc initJNIThread*
proc initJNI*(version: JNIVersion, options: seq[string]) =
  ## Setup JNI API
  jniAssert(not theOptions.isDefined, "JNI API already initialized, you must deinitialize it first")
  theOptions = (version, options).some
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
    theVM = nil
    theEnv = nil

proc initJNIThread* =
  ## Setup JNI API thread
  if theEnv != nil:
    return
  if not theOptions.isDefined:
    raise newJNIException("You must initialize JNI API before using it")

  let o = theOptions.get
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

template checkInit = jniAssert(theEnv != nil, "You must call initJNIThread before using JNI API")

type
  JVMObject* = ref object
    o: jobject

proc freeJVMObject(o: JVMObject) =
  if o.o != nil and theEnv != nil:
    theEnv.DeleteLocalRef(theEnv, o.o)

proc newJVMObject*(o: jobject): JVMObject =
  new(result, freeJVMObject)
  result.o = o

proc get*(o: JVMObject): jobject =
  o.o
