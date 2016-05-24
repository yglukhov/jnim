import os,
       dynlib

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
    z: jboolean
    b: jbyte
    c: jchar
    s: jshort
    i: jint
    j: jlong
    f: jfloat
    d: jdouble
    l: jobject

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
  JNIInvokeInterface* {.importc: JNIInvokeInterfaceImportName, nodecl, header: JNI_HDR.} = object
    reserved0, reserved1, reserved2: pointer
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

#TODO: Do we really need incompleteStruct pragma? For what?
  JNINativeInterface* {.importc: JNINativeInterfaceImportName, nodecl, header: JNI_HDR, incompleteStruct.} = object
    reserved0: pointer
    reserved1: pointer
    reserved2: pointer
    reserved3: pointer
    GetVersion*: proc(env: JNIEnvPtr): jint {.cdecl.}
  JNIEnv* = ptr JNINativeInterface
  JNIEnvPtr* = ptr JNIEnv

var JNI_VERSION_1_1* {.header: JNI_HDR.} : jint
var JNI_VERSION_1_2* {.header: JNI_HDR.} : jint
var JNI_VERSION_1_4* {.header: JNI_HDR.} : jint
var JNI_VERSION_1_6* {.header: JNI_HDR.} : jint
var JNI_VERSION_1_8* {.header: JNI_HDR.} : jint

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
