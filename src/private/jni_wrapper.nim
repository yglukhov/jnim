import os,
       dynlib,
       strutils

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
    GetObjectClass*: proc(env: JNIEnvPtr, obj: jobject): jclass {.cdecl.}
    FindClass*: proc(env: JNIEnvPtr, name: cstring): jclass {.cdecl.}
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
    GetStaticObjectField*: proc(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jobject {.cdecl.}

    CallVoidMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue) {.cdecl.}

  JNIEnv* = ptr JNINativeInterface
  JNIEnvPtr* = ptr JNIEnv

const JNI_VERSION_1_1* = 0x00010001.jint
const JNI_VERSION_1_2* = 0x00010002.jint
const JNI_VERSION_1_4* = 0x00010004.jint
const JNI_VERSION_1_6* = 0x00010006.jint
const JNI_VERSION_1_8* = 0x00010008.jint

var JNI_CreateJavaVM*: proc (pvm: ptr JavaVMPtr, penv: ptr pointer, args: pointer): jint {.cdecl.}
var JNI_GetDefaultJavaVMInitArgs*: proc(vm_args: ptr JavaVMInitArgs): jint {.cdecl.}
var JNI_GetCreatedJavaVMs*: proc(vmBuf: ptr JavaVMPtr, bufLen: jsize, nVMs: ptr jsize): jint {.cdecl.}

proc isJVMLoaded*: bool =
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

