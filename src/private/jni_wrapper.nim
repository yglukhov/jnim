import os,
       dynlib,
       strutils,
       macros

from jvm_finder import CT_JVM

const JNI_INC_DIR = CT_JVM.root / "include"
const JNI_HDR = "<jni.h>"

when defined macosx:
  {.passC: "-I" & JNI_INC_DIR.}
  {.emit: """
  #include <CoreFoundation/CoreFoundation.h>
  """.}
  {.passC: "-I" & JNI_INC_DIR / "darwin".}
  {.passL: "-framework CoreFoundation".}
elif defined windows:
  {.passC: "-I\"" & JNI_INC_DIR & "\"".}
  {.passC: "-I\"" & JNI_INC_DIR / "win32\"".}
elif defined linux:
  {.passC: "-I" & JNI_INC_DIR.}
  {.passC: "-I" & JNI_INC_DIR / "linux".}

{.warning[SmallLshouldNotBeUsed]: off.}

type
  JNIException* = object of Exception

proc newJNIException*(msg: string): ref JNIException =
  newException(JNIException, msg)

template jniAssert*(call: expr): stmt =
  if not `call`:
    raise newJNIException(call.astToStr & " is false")
    
template jniAssert*(call: expr, msg: string): stmt =
  if not `call`:
    raise newJNIException(msg)
    
template jniAssertEx*(call: expr, msg: string): stmt =
  if not `call`:
    raise newJNIException(msg & " (" & call.astToStr & " is false)")
    
template jniCall*(call: expr): stmt =
  let res = `call`
  if res != 0.jint:
    raise newJNIException(call.astToStr & " returned " & $res)

template jniCall*(call: expr, msg: string): stmt =
  let res = `call`
  if res != 0.jint:
    raise newJNIException(msg & " (result = " & $res & ")")

template jniCallEx*(call: expr, msg: string): stmt =
  let res = `call`
  if res != 0.jint:
    raise newJNIException(msg & " (" & call.astToStr & " returned " & $res & ")")

type
  jint* {.header: JNI_HDR.} = cint
  jsize* {.header: JNI_HDR.} = jint
  jchar* {.header: JNI_HDR.} = uint16
  jlong* {.header: JNI_HDR.} = int64
  jshort* {.header: JNI_HDR.} = int16
  jbyte* {.header: JNI_HDR.} = int8
  jfloat* {.header: JNI_HDR.} = cfloat
  jdouble* {.header: JNI_HDR.} = cdouble
  jboolean* {.header: JNI_HDR.} = uint8
  jclass* {.header: JNI_HDR.} = distinct pointer
  jmethodID* {.header: JNI_HDR.} = pointer
  jobject* {.header: JNI_HDR.} = pointer
  jfieldID* {.header: JNI_HDR.} = pointer
  jstring* {.header: JNI_HDR.} = jobject
  jthrowable* {.header: JNI_HDR.} = jobject
  jarray* {.header: JNI_HDR.} = jobject
  jobjectArray* {.header: JNI_HDR.} = jarray
  jbooleanArray* {.header: JNI_HDR.} = jarray
  jbyteArray* {.header: JNI_HDR.} = jarray
  jcharArray* {.header: JNI_HDR.} = jarray
  jshortArray* {.header: JNI_HDR.} = jarray
  jintArray* {.header: JNI_HDR.} = jarray
  jlongArray* {.header: JNI_HDR.} = jarray
  jfloatArray* {.header: JNI_HDR.} = jarray
  jdoubleArray* {.header: JNI_HDR.} = jarray

  jvalue* {.header: JNI_HDR, union.} = object
    z*: jboolean
    b*: jbyte
    c*: jchar
    s*: jshort
    i*: jint
    j*: jlong
    f*: jfloat
    d*: jdouble
    l*: jobject

const JVM_TRUE* = 1.jboolean
const JVM_FALSE* = 0.jboolean

const JNINativeInterfaceImportName = when defined(android):
                                       "struct JNINativeInterface"
                                     else:
                                       "struct JNINativeInterface_"

const JNIInvokeInterfaceImportName = when defined(android):
                                       "struct JNIInvokeInterface"
                                     else:
                                       "struct JNIInvokeInterface_"

type
  JNIInvokeInterface* {.importc: JNIInvokeInterfaceImportName, nodecl, header: JNI_HDR, incompleteStruct.} = object
    DestroyJavaVM*: proc(vm: JavaVMPtr): jint {.cdecl.}
    AttachCurrentThread*: proc(vm: JavaVMPtr, penv: ptr pointer, args: pointer): jint {.cdecl.}
    DetachCurrentThread*: proc(vm: JavaVMPtr): jint {.cdecl.}
    GetEnv*: proc(vm: JavaVMPtr, penv: ptr pointer, version: jint): jint {.cdecl.}
    AttachCurrentThreadAsDaemon*: proc(vm: JavaVMPtr, penv: ptr pointer, args: pointer): jint {.cdecl.}
  JavaVM* = ptr JNIInvokeInterface
  JavaVMPtr* = ptr JavaVM
  JavaVMOption* {.header: JNI_HDR.} = object
    optionString*: cstring
    extraInfo*: pointer
  JavaVMInitArgs* {.header: JNI_HDR.} = object
    version*: jint
    nOptions*: jint
    options*: ptr JavaVMOption
    ignoreUnrecognized*: jboolean

  JNINativeInterface* {.importc: JNINativeInterfaceImportName, nodecl, header: JNI_HDR, incompleteStruct.} = object
    GetVersion*: proc(env: JNIEnvPtr): jint {.cdecl.}
    ExceptionCheck*: proc(env: JNIEnvPtr): jboolean {.cdecl.}
    ExceptionOccurred*: proc(env: JNIEnvPtr): jthrowable {.cdecl.}
    ExceptionClear*: proc(env: JNIEnvPtr) {.cdecl.}
    GetObjectClass*: proc(env: JNIEnvPtr, obj: jobject): jclass {.cdecl.}
    FindClass*: proc(env: JNIEnvPtr, name: cstring): jclass {.cdecl.}
    GetStringUTFChars*: proc(env: JNIEnvPtr, s: jstring, isCopy: ptr jboolean): cstring {.cdecl.}
    ReleaseStringUTFChars*: proc(env: JNIEnvPtr, s: jstring, cstr: cstring) {.cdecl.}
    NewStringUTF*: proc(env: JNIEnvPtr, s: cstring): jstring {.cdecl.}
    NewGlobalRef*: proc(env: JNIEnvPtr, obj: jobject): jobject {.cdecl.}
    NewLocalRef*: proc(env: JNIEnvPtr, obj: jobject): jobject {.cdecl.}
    DeleteGlobalRef*: proc(env: JNIEnvPtr, obj: jobject) {.cdecl.}
    DeleteLocalRef*: proc(env: JNIEnvPtr, obj: jobject) {.cdecl.}

    GetStaticFieldID*: proc(env: JNIEnvPtr, cls: jclass, name, sig: cstring): jfieldID {.cdecl.}
    GetStaticMethodID*: proc(env: JNIEnvPtr, cls: jclass, name, sig: cstring): jmethodID {.cdecl.}
    GetFieldID*: proc(env: JNIEnvPtr, cls: jclass, name, sig: cstring): jfieldID {.cdecl.}
    GetMethodID*: proc(env: JNIEnvPtr, cls: jclass, name, sig: cstring): jmethodID {.cdecl.}

    GetObjectField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jobject {.cdecl.}
    GetBooleanField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jboolean {.cdecl.}
    GetByteField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jbyte {.cdecl.}
    GetCharField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jchar {.cdecl.}
    GetShortField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jshort {.cdecl.}
    GetIntField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jint {.cdecl.}
    GetLongField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jlong {.cdecl.}
    GetFloatField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jfloat {.cdecl.}
    GetDoubleField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jdouble {.cdecl.}
    SetObjectField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jobject) {.cdecl.}
    SetBooleanField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jboolean) {.cdecl.}
    SetByteField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jbyte) {.cdecl.}
    SetCharField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jchar) {.cdecl.}
    SetShortField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jshort) {.cdecl.}
    SetIntField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jint) {.cdecl.}
    SetLongField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jlong) {.cdecl.}
    SetFloatField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jfloat) {.cdecl.}
    SetDoubleField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jdouble) {.cdecl.}

    GetStaticObjectField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jobject {.cdecl.}
    GetStaticBooleanField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jboolean {.cdecl.}
    GetStaticByteField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jbyte {.cdecl.}
    GetStaticCharField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jchar {.cdecl.}
    GetStaticShortField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jshort {.cdecl.}
    GetStaticIntField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jint {.cdecl.}
    GetStaticLongField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jlong {.cdecl.}
    GetStaticFloatField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jfloat {.cdecl.}
    GetStaticDoubleField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jdouble {.cdecl.}
    
    SetStaticObjectField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jobject) {.cdecl.}
    SetStaticBooleanField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jboolean) {.cdecl.}
    SetStaticByteField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jbyte) {.cdecl.}
    SetStaticCharField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jchar) {.cdecl.}
    SetStaticShortField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jshort) {.cdecl.}
    SetStaticIntField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jint) {.cdecl.}
    SetStaticLongField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jlong) {.cdecl.}
    SetStaticFloatField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jfloat) {.cdecl.}
    SetStaticDoubleField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jdouble) {.cdecl.}
    
    NewObjectA*: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jobject {.cdecl.}

    CallStaticVoidMethodA*: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue) {.cdecl.}
    CallVoidMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue) {.cdecl.}

    CallStaticObjectMethodA*: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jobject {.cdecl.}
    CallStaticBooleanMethodA*: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jboolean {.cdecl.}
    CallStaticByteMethodA*: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jbyte {.cdecl.}
    CallStaticCharMethodA*: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jchar {.cdecl.}
    CallStaticShortMethodA*: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jshort {.cdecl.}
    CallStaticIntMethodA*: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jint {.cdecl.}
    CallStaticLongMethodA*: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jlong {.cdecl.}
    CallStaticFloatMethodA*: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jfloat {.cdecl.}
    CallStaticDoubleMethodA*: proc(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: ptr jvalue): jdouble {.cdecl.}
    CallObjectMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue): jobject {.cdecl.}
    CallBooleanMethodA*: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jboolean {.cdecl.}
    CallByteMethodA*: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jbyte {.cdecl.}
    CallCharMethodA*: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jchar {.cdecl.}
    CallShortMethodA*: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jshort {.cdecl.}
    CallIntMethodA*: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jint {.cdecl.}
    CallLongMethodA*: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jlong {.cdecl.}
    CallFloatMethodA*: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jfloat {.cdecl.}
    CallDoubleMethodA*: proc(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: ptr jvalue): jdouble {.cdecl.}
    
    GetArrayLength*: proc(env: JNIEnvPtr, arr: jarray): jsize {.cdecl.}
    
    NewObjectArray*: proc(env: JNIEnvPtr, size: jsize, clazz: jclass, init: jobject): jobjectArray {.cdecl.}

    NewBooleanArray*: proc(env: JNIEnvPtr, len: jsize): jbooleanArray {.cdecl.}
    NewByteArray*: proc(env: JNIEnvPtr, len: jsize): jbyteArray {.cdecl.}
    NewCharArray*: proc(env: JNIEnvPtr, len: jsize): jcharArray {.cdecl.}
    NewShortArray*: proc(env: JNIEnvPtr, len: jsize): jshortArray {.cdecl.}
    NewIntArray*: proc(env: JNIEnvPtr, len: jsize): jintArray {.cdecl.}
    NewLongArray*: proc(env: JNIEnvPtr, len: jsize): jlongArray {.cdecl.}
    NewFloatArray*: proc(env: JNIEnvPtr, len: jsize): jfloatArray {.cdecl.}
    NewDoubleArray*: proc(env: JNIEnvPtr, len: jsize): jdoubleArray {.cdecl.}

    GetBooleanArrayElements*: proc(env: JNIEnvPtr, arr: jbooleanArray, isCopy: ptr jboolean): ptr jboolean {.cdecl.}
    GetByteArrayElements*: proc(env: JNIEnvPtr, arr: jbyteArray, isCopy: ptr jboolean): ptr jbyte {.cdecl.}
    GetCharArrayElements*: proc(env: JNIEnvPtr, arr: jcharArray, isCopy: ptr jboolean): ptr jchar {.cdecl.}
    GetShortArrayElements*: proc(env: JNIEnvPtr, arr: jshortArray, isCopy: ptr jboolean): ptr jshort {.cdecl.}
    GetIntArrayElements*: proc(env: JNIEnvPtr, arr: jintArray, isCopy: ptr jboolean): ptr jint {.cdecl.}
    GetLongArrayElements*: proc(env: JNIEnvPtr, arr: jlongArray, isCopy: ptr jboolean): ptr jlong {.cdecl.}
    GetFloatArrayElements*: proc(env: JNIEnvPtr, arr: jfloatArray, isCopy: ptr jboolean): ptr jfloat {.cdecl.}
    GetDoubleArrayElements*: proc(env: JNIEnvPtr, arr: jdoubleArray, isCopy: ptr jboolean): ptr jdouble {.cdecl.}

    ReleaseBooleanArrayElements*: proc(env: JNIEnvPtr, arr: jbooleanArray, elems: ptr jboolean, mode: jint) {.cdecl.}
    ReleaseByteArrayElements*: proc(env: JNIEnvPtr, arr: jbyteArray, elems: ptr jbyte, mode: jint) {.cdecl.}
    ReleaseCharArrayElements*: proc(env: JNIEnvPtr, arr: jcharArray, elems: ptr jchar, mode: jint) {.cdecl.}
    ReleaseShortArrayElements*: proc(env: JNIEnvPtr, arr: jshortArray, elems: ptr jshort, mode: jint) {.cdecl.}
    ReleaseIntArrayElements*: proc(env: JNIEnvPtr, arr: jintArray, elems: ptr jint, mode: jint) {.cdecl.}
    ReleaseLongArrayElements*: proc(env: JNIEnvPtr, arr: jlongArray, elems: ptr jlong, mode: jint) {.cdecl.}
    ReleaseFloatArrayElements*: proc(env: JNIEnvPtr, arr: jfloatArray, elems: ptr jfloat, mode: jint) {.cdecl.}
    ReleaseDoubleArrayElements*: proc(env: JNIEnvPtr, arr: jdoubleArray, elems: ptr jdouble, mode: jint) {.cdecl.}

    GetBooleanArrayRegion*: proc(env: JNIEnvPtr, arr: jbooleanArray, start, len: jsize, buf: ptr jboolean) {.cdecl.}
    GetByteArrayRegion*: proc(env: JNIEnvPtr, arr: jbyteArray, start, len: jsize, buf: ptr jbyte) {.cdecl.}
    GetCharArrayRegion*: proc(env: JNIEnvPtr, arr: jcharArray, start, len: jsize, buf: ptr jchar) {.cdecl.}
    GetShortArrayRegion*: proc(env: JNIEnvPtr, arr: jshortArray, start, len: jsize, buf: ptr jshort) {.cdecl.}
    GetIntArrayRegion*: proc(env: JNIEnvPtr, arr: jintArray, start, len: jsize, buf: ptr jint) {.cdecl.}
    GetLongArrayRegion*: proc(env: JNIEnvPtr, arr: jlongArray, start, len: jsize, buf: ptr jlong) {.cdecl.}
    GetFloatArrayRegion*: proc(env: JNIEnvPtr, arr: jfloatArray, start, len: jsize, buf: ptr jfloat) {.cdecl.}
    GetDoubleArrayRegion*: proc(env: JNIEnvPtr, arr: jdoubleArray, start, len: jsize, buf: ptr jdouble) {.cdecl.}

    SetBooleanArrayRegion*: proc(env: JNIEnvPtr, arr: jbooleanArray, start, len: jsize, buf: ptr jboolean) {.cdecl.}
    SetByteArrayRegion*: proc(env: JNIEnvPtr, arr: jbyteArray, start, len: jsize, buf: ptr jbyte) {.cdecl.}
    SetCharArrayRegion*: proc(env: JNIEnvPtr, arr: jcharArray, start, len: jsize, buf: ptr jchar) {.cdecl.}
    SetShortArrayRegion*: proc(env: JNIEnvPtr, arr: jshortArray, start, len: jsize, buf: ptr jshort) {.cdecl.}
    SetIntArrayRegion*: proc(env: JNIEnvPtr, arr: jintArray, start, len: jsize, buf: ptr jint) {.cdecl.}
    SetLongArrayRegion*: proc(env: JNIEnvPtr, arr: jlongArray, start, len: jsize, buf: ptr jlong) {.cdecl.}
    SetFloatArrayRegion*: proc(env: JNIEnvPtr, arr: jfloatArray, start, len: jsize, buf: ptr jfloat) {.cdecl.}
    SetDoubleArrayRegion*: proc(env: JNIEnvPtr, arr: jdoubleArray, start, len: jsize, buf: ptr jdouble) {.cdecl.}

  JNIEnv* = ptr JNINativeInterface
  JNIEnvPtr* = ptr JNIEnv

const JNI_VERSION_1_1* = 0x00010001.jint
const JNI_VERSION_1_2* = 0x00010002.jint
const JNI_VERSION_1_4* = 0x00010004.jint
const JNI_VERSION_1_6* = 0x00010006.jint
const JNI_VERSION_1_8* = 0x00010008.jint

var JNI_CreateJavaVM*: proc (pvm: ptr JavaVMPtr, penv: ptr pointer, args: pointer): jint {.cdecl, gcsafe.}
var JNI_GetDefaultJavaVMInitArgs*: proc(vm_args: ptr JavaVMInitArgs): jint {.cdecl, gcsafe.}
var JNI_GetCreatedJavaVMs*: proc(vmBuf: ptr JavaVMPtr, bufLen: jsize, nVMs: ptr jsize): jint {.cdecl, gcsafe.}

proc isJVMLoaded*: bool {.gcsafe.} =
  not JNI_CreateJavaVM.isNil and not JNI_GetDefaultJavaVMInitArgs.isNil and not JNI_GetCreatedJavaVMs.isNil

proc linkWithJVMLib* =
  when defined(macosx):
    let libPath {.hint[XDeclaredButNotUsed]: off.} = CT_JVM.root.parentDir.parentDir.cstring
    {.emit: """
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (const UInt8 *)`libPath`, strlen(`libPath`), true);
    if (url)
    {
      CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, url);
      CFRelease(url);

      if (bundle)
      {
        `JNI_CreateJavaVM` = CFBundleGetFunctionPointerForName(bundle, CFSTR("JNI_CreateJavaVM"));
        `JNI_GetDefaultJavaVMInitArgs` = CFBundleGetFunctionPointerForName(bundle, CFSTR("JNI_GetDefaultJavaVMInitArgs"));
        `JNI_GetCreatedJavaVMs` = CFBundleGetFunctionPointerForName(bundle, CFSTR("JNI_GetCreatedJavaVMs"));
      }
    }
    """.}
  else:
    proc linkWithJVMModule(handle: LibHandle) =
      JNI_CreateJavaVM = cast[type(JNI_CreateJavaVM)](symAddr(handle, "JNI_CreateJavaVM"))
      JNI_GetDefaultJavaVMInitArgs = cast[type(JNI_GetDefaultJavaVMInitArgs)](symAddr(handle, "JNI_GetDefaultJavaVMInitArgs"))
      JNI_GetCreatedJavaVMs = cast[type(JNI_GetCreatedJavaVMs)](symAddr(handle, "JNI_GetCreatedJavaVMs"))

    # First we try to find the JNI functions in the current process. We may already be linked with those.
    var handle = loadLib()
    if not handle.isNil:
      linkWithJVMModule(handle)

    if not isJVMLoaded():
      if not handle.isNil:
        unloadLib(handle)
        handle = loadLib(CT_JVM.lib)
        linkWithJVMModule(handle)

  if not isJVMLoaded():
    raise newException(Exception, "JVM could not be loaded")

proc fqcn*(cls: string): string =
  ## Create fullqualified class name
  result = "L" & cls.replace(".", "/") & ";"

proc toJValue*(v: cfloat): jvalue = result.f = v
proc toJValue*(v: jdouble): jvalue = result.d = v
proc toJValue*(v: jint): jvalue = result.i = v
proc toJValue*(v: jlong): jvalue = result.j = v
proc toJValue*(v: jboolean): jvalue = result.z = v
proc toJValue*(v: jbyte): jvalue = result.b = v
proc toJValue*(v: jchar): jvalue = result.c = v
proc toJValue*(v: jshort): jvalue = result.s = v
proc toJValue*(v: jobject): jvalue = result.l = v

template fromJValue*(T: typedesc, v: jvalue): auto =
  when T is jboolean: v.z
  elif T is jbyte: v.b
  elif T is jchar: v.c
  elif T is jshort: v.s
  elif T is jint: v.i
  elif T is jlong: v.j
  elif T is jfloat: v.f
  elif T is jdouble: v.d
  elif T is jobject: v.l
  else:
    {.error: "wrong type".}

template jniSig*(t: typedesc[jlong]): string = "J"
template jniSig*(t: typedesc[jint]): string = "I"
template jniSig*(t: typedesc[jboolean]): string = "Z"
template jniSig*(t: typedesc[bool]): string = "Z"
template jniSig*(t: typedesc[jbyte]): string = "B"
template jniSig*(t: typedesc[jchar]): string = "C"
template jniSig*(t: typedesc[jshort]): string = "S"
template jniSig*(t: typedesc[jfloat]): string = "F"
template jniSig*(t: typedesc[jdouble]): string = "D"
template jniSig*(t: typedesc[string]): string = fqcn"java.lang.String"
template jniSig*(t: typedesc[void]): string = "V"
proc elementTypeOfOpenArrayType[OpenArrayType](dummy: OpenArrayType = @[]): auto = dummy[0]
template jniSig*(t: typedesc[openarray]): string = "[" & jniSig(type(elementTypeOfOpenArrayType[t]()))

type
  JVMArrayType* = jobjectArray |
    jcharArray |
    jbyteArray |
    jshortArray |
    jintArray |
    jlongArray |
    jfloatArray |
    jdoubleArray |
    jbooleanArray
  JVMValueType* = jobject |
    jchar |
    jbyte |
    jshort |
    jint |
    jlong |
    jfloat |
    jdouble |
    jboolean

template valueType*(T: typedesc): typedesc =
  when T is jobjectArray:
    jobject
  elif T is jcharArray:
    jchar
  elif T is jbyteArray:
    jbyte
  elif T is jshortArray:
    jshort
  elif T is jintArray:
    jint
  elif T is jlongArray:
    jlong
  elif T is jfloatArray:
    jfloat
  elif T is jdoubleArray:
    jdouble
  elif T is jbooleanArray:
    jboolean
  else:
    {.error: "Can't use type " & astToStr(T) & " with java's arrays".}
    discard

template arrayType*(T: typedesc): typedesc =
  when T is jobject:
    jobjectArray
  elif T is jchar:
    jcharArray
  elif T is jbyte:
    jbyteArray
  elif T is jshort:
    jshortArray
  elif T is jint:
    jintArray
  elif T is jlong:
    jlongArray
  elif T is jfloat:
    jfloatArray
  elif T is jdouble:
    jdoubleArray
  elif T is jboolean:
    jbooleanArray
  else:
    {.error: "Can't use type " & astToStr(T) & " with java's arrays".}
    discard
