import os, dynlib, strutils, macros, options

from jvm_finder import findJVM

when defined macosx:
  {.emit: """
  #include <CoreFoundation/CoreFoundation.h>
  """.}
  {.passL: "-framework CoreFoundation".}

type
  JNIException* = object of CatchableError

proc newJNIException*(msg: string): ref JNIException =
  newException(JNIException, msg)

template jniAssert*(call: untyped): untyped =
  if not `call`:
    raise newJNIException(call.astToStr & " is false")

template jniAssert*(call: untyped, msg: string): untyped =
  if not `call`:
    raise newJNIException(msg)

template jniAssertEx*(call: untyped, msg: string): untyped =
  if not `call`:
    raise newJNIException(msg & " (" & call.astToStr & " is false)")

template jniCall*(call: untyped): untyped =
  let res = `call`
  if res != 0.jint:
    raise newJNIException(call.astToStr & " returned " & $res)

template jniCall*(call: untyped, msg: string): untyped =
  let res = `call`
  if res != 0.jint:
    raise newJNIException(msg & " (result = " & $res & ")")

template jniCallEx*(call: untyped, msg: string): untyped =
  let res = `call`
  if res != 0.jint:
    raise newJNIException(msg & " (" & call.astToStr & " returned " & $res & ")")

type
  jint* = int32
  jsize* = jint
  jchar* = uint16
  jlong* = int64
  jshort* = int16
  jbyte* = int8
  jfloat* = cfloat
  jdouble* = cdouble
  jboolean* = uint8

  jobject_base {.inheritable, pure.} = object
  jobject* = ptr jobject_base
  JClass* = ptr object of jobject
  jmethodID* = pointer
  jfieldID* = pointer
  jstring* = ptr object of jobject
  jthrowable* = ptr object of jobject

  jarray* = ptr object of jobject
  jtypedArray*[T] = ptr object of jarray

  jobjectArray* = jtypedArray[jobject]
  jbooleanArray* = jtypedArray[jboolean]
  jbyteArray* = jtypedArray[jbyte]
  jcharArray* = jtypedArray[jchar]
  jshortArray* = jtypedArray[jshort]
  jintArray* = jtypedArray[jint]
  jlongArray* = jtypedArray[jlong]
  jfloatArray* = jtypedArray[jfloat]
  jdoubleArray* = jtypedArray[jdouble]
  jweak* = jobject

  jvalue* {.union.} = object
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

{.pragma: jni, cdecl, gcsafe.}

type
  JNIInvokeInterface* = object
    # WARNING: The fields should be defined in exact same order as they are
    # defined in jni.h to preserve ABI compatibility.
    reserved0: pointer
    reserved1: pointer
    reserved2: pointer
    when defined(not_TARGET_RT_MAC_CFM_and_ppc): # No idea what this means.
      cfm_vectors: array[4, pointer]

    DestroyJavaVM*: proc(vm: JavaVMPtr): jint {.jni.}
    AttachCurrentThread*: proc(vm: JavaVMPtr, penv: ptr pointer, args: pointer): jint {.jni.}
    DetachCurrentThread*: proc(vm: JavaVMPtr): jint {.jni.}
    GetEnv*: proc(vm: JavaVMPtr, penv: ptr pointer, version: jint): jint {.jni.}
    AttachCurrentThreadAsDaemon*: proc(vm: JavaVMPtr, penv: ptr pointer, args: pointer): jint {.jni.}

  JavaVM* = ptr JNIInvokeInterface
  JavaVMPtr* = ptr JavaVM
  JavaVMOption* = object
    # WARNING: The fields should be defined in exact same order as they are
    # defined in jni.h to preserve ABI compatibility.
    optionString*: cstring
    extraInfo*: pointer

  JavaVMInitArgs* = object
    # WARNING: The fields should be defined in exact same order as they are
    # defined in jni.h to preserve ABI compatibility.
    version*: jint
    nOptions*: jint
    options*: ptr JavaVMOption
    ignoreUnrecognized*: jboolean

  JNINativeInterface* = object
    # WARNING: The fields should be defined in exact same order as they are
    # defined in jni.h to preserve ABI compatibility.

    reserved0: pointer
    reserved1: pointer
    reserved2: pointer
    reserved3: pointer

    when defined(not_TARGET_RT_MAC_CFM_and_ppc): # No idea what this means.
      cfm_vectors: array[225, pointer]

    GetVersion*: proc(env: JNIEnvPtr): jint {.jni.}

    DefineClass*: proc(env: JNIEnvPtr, name: cstring, loader: jobject, buf: ptr jbyte, len: jsize): JClass {.jni.}
    FindClass*: proc(env: JNIEnvPtr, name: cstring): JClass {.jni.}

    FromReflectedMethod*: proc(env: JNIEnvPtr, meth: jobject): jmethodID {.jni.}
    FromReflectedField*: proc(env: JNIEnvPtr, field: jobject): jfieldID {.jni.}

    ToReflectedMethod*: proc(env: JNIEnvPtr, cls: JClass, methodID: jmethodID, isStatic: jboolean): jobject {.jni.}

    GetSuperclass*: proc(env: JNIEnvPtr, sub: JClass): JClass {.jni.}
    IsAssignableFrom*: proc(env: JNIEnvPtr, sub, sup: JClass): jboolean {.jni.}

    ToReflectedField*: proc(env: JNIEnvPtr, cls: JClass, fieldID: jfieldID, isStatic: jboolean): jobject {.jni.}

    Throw*: proc(env: JNIEnvPtr, obj: jthrowable): jint {.jni.}
    ThrowNew*: proc(env: JNIEnvPtr, clazz: JClass, msg: cstring): jint {.jni.}
    ExceptionOccurred*: proc(env: JNIEnvPtr): jthrowable {.jni.}
    ExceptionDescribe*: proc(env: JNIEnvPtr) {.jni.}
    ExceptionClear*: proc(env: JNIEnvPtr) {.jni.}
    FatalError*: proc(env: JNIEnvPtr, msg: cstring) {.jni.}

    PushLocalFrame*: proc(env: JNIEnvPtr, capacity: jint): jint {.jni.}
    PopLocalFrame*: proc(env: JNIEnvPtr, res: jobject): jobject {.jni.}

    NewGlobalRef*: proc(env: JNIEnvPtr, obj: jobject): jobject {.jni.}
    DeleteGlobalRef*: proc(env: JNIEnvPtr, obj: jobject) {.jni.}
    DeleteLocalRef*: proc(env: JNIEnvPtr, obj: jobject) {.jni.}
    IsSameObject*: proc(env: JNIEnvPtr, obj1, obj2: jobject): jboolean {.jni.}
    NewLocalRef*: proc(env: JNIEnvPtr, obj: jobject): jobject {.jni.}
    EnsureLocalCapacity*: proc(env: JNIEnvPtr, capacity: jint): jint {.jni.}

    AllocObject*: proc(env: JNIEnvPtr, clazz: JClass): jobject {.jni.}
    NewObject*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID): jobject {.jni, varargs.}
    NewObjectV: pointer # This function utilizes va_list which is not needed in Nim
    NewObjectA*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jobject {.jni.}

    GetObjectClass*: proc(env: JNIEnvPtr, obj: jobject): JClass {.jni.}
    IsInstanceOf*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass): jboolean {.jni.}

    GetMethodID*: proc(env: JNIEnvPtr, clazz: JClass, name, sig: cstring): jmethodID {.jni.}

    CallObjectMethod*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID): jobject {.jni, varargs.}
    CallObjectMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallObjectMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue): jobject {.jni.}

    CallBooleanMethod*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID): jboolean {.jni, varargs.}
    CallBooleanMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallBooleanMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue): jboolean {.jni.}

    CallByteMethod*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID): jbyte {.jni, varargs.}
    CallByteMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallByteMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue): jbyte {.jni.}

    CallCharMethod*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID): jchar {.jni, varargs.}
    CallCharMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallCharMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue): jchar {.jni.}

    CallShortMethod*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID): jshort {.jni, varargs.}
    CallShortMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallShortMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue): jshort {.jni.}

    CallIntMethod*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID): jint {.jni, varargs.}
    CallIntMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallIntMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue): jint {.jni.}

    CallLongMethod*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID): jlong {.jni, varargs.}
    CallLongMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallLongMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue): jlong {.jni.}

    CallFloatMethod*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID): jfloat {.jni, varargs.}
    CallFloatMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallFloatMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue): jfloat {.jni.}

    CallDoubleMethod*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID): jdouble {.jni, varargs.}
    CallDoubleMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallDoubleMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue): jdouble {.jni.}

    CallVoidMethod*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID) {.jni, varargs.}
    CallVoidMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallVoidMethodA*: proc(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: ptr jvalue) {.jni.}

    CallNonvirtualObjectMethod*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID): jobject {.jni, varargs.}
    CallNonvirtualObjectMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallNonvirtualObjectMethodA*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jobject {.jni.}

    CallNonvirtualBooleanMethod*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID): jboolean {.jni, varargs.}
    CallNonvirtualBooleanMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallNonvirtualBooleanMethodA*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jboolean {.jni.}

    CallNonvirtualByteMethod*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID): jbyte {.jni, varargs.}
    CallNonvirtualByteMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallNonvirtualByteMethodA*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jbyte {.jni.}

    CallNonvirtualCharMethod*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID): jchar {.jni, varargs.}
    CallNonvirtualCharMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallNonvirtualCharMethodA*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jchar {.jni.}

    CallNonvirtualShortMethod*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID): jshort {.jni, varargs.}
    CallNonvirtualShortMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallNonvirtualShortMethodA*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jshort {.jni.}

    CallNonvirtualIntMethod*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID): jint {.jni, varargs.}
    CallNonvirtualIntMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallNonvirtualIntMethodA*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jint {.jni.}

    CallNonvirtualLongMethod*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID): jlong {.jni, varargs.}
    CallNonvirtualLongMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallNonvirtualLongMethodA*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jlong {.jni.}

    CallNonvirtualFloatMethod*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID): jfloat {.jni, varargs.}
    CallNonvirtualFloatMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallNonvirtualFloatMethodA*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jfloat {.jni.}

    CallNonvirtualDoubleMethod*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID): jdouble {.jni, varargs.}
    CallNonvirtualDoubleMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallNonvirtualDoubleMethodA*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jdouble {.jni.}

    CallNonvirtualVoidMethod*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID) {.jni, varargs.}
    CallNonvirtualVoidMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallNonvirtualVoidMethodA*: proc(env: JNIEnvPtr, obj: jobject, clazz: JClass, methodID: jmethodID, args: ptr jvalue) {.jni.}

    GetFieldID*: proc(env: JNIEnvPtr, cls: JClass, name, sig: cstring): jfieldID {.jni.}

    GetObjectField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jobject {.jni.}
    GetBooleanField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jboolean {.jni.}
    GetByteField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jbyte {.jni.}
    GetCharField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jchar {.jni.}
    GetShortField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jshort {.jni.}
    GetIntField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jint {.jni.}
    GetLongField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jlong {.jni.}
    GetFloatField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jfloat {.jni.}
    GetDoubleField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jdouble {.jni.}

    SetObjectField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jobject) {.jni.}
    SetBooleanField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jboolean) {.jni.}
    SetByteField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jbyte) {.jni.}
    SetCharField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jchar) {.jni.}
    SetShortField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jshort) {.jni.}
    SetIntField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jint) {.jni.}
    SetLongField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jlong) {.jni.}
    SetFloatField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jfloat) {.jni.}
    SetDoubleField*: proc(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jdouble) {.jni.}

    GetStaticMethodID*: proc(env: JNIEnvPtr, cls: JClass, name, sig: cstring): jmethodID {.jni.}

    CallStaticObjectMethod*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID): jobject {.jni, varargs.}
    CallStaticObjectMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallStaticObjectMethodA*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jobject {.jni.}

    CallStaticBooleanMethod*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID): jboolean {.jni, varargs.}
    CallStaticBooleanMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallStaticBooleanMethodA*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jboolean {.jni.}

    CallStaticByteMethod*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID): jbyte {.jni, varargs.}
    CallStaticByteMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallStaticByteMethodA*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jbyte {.jni.}

    CallStaticCharMethod*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID): jchar {.jni, varargs.}
    CallStaticCharMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallStaticCharMethodA*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jchar {.jni.}

    CallStaticShortMethod*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID): jshort {.jni, varargs.}
    CallStaticShortMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallStaticShortMethodA*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jshort {.jni.}

    CallStaticIntMethod*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID): jint {.jni, varargs.}
    CallStaticIntMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallStaticIntMethodA*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jint {.jni.}

    CallStaticLongMethod*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID): jlong {.jni, varargs.}
    CallStaticLongMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallStaticLongMethodA*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jlong {.jni.}

    CallStaticFloatMethod*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID): jfloat {.jni, varargs.}
    CallStaticFloatMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallStaticFloatMethodA*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jfloat {.jni.}

    CallStaticDoubleMethod*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID): jdouble {.jni, varargs.}
    CallStaticDoubleMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallStaticDoubleMethodA*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID, args: ptr jvalue): jdouble {.jni.}

    CallStaticVoidMethod*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID) {.jni, varargs.}
    CallStaticVoidMethodV: pointer # This function utilizes va_list which is not needed in Nim
    CallStaticVoidMethodA*: proc(env: JNIEnvPtr, clazz: JClass, methodID: jmethodID, args: ptr jvalue) {.jni.}

    GetStaticFieldID*: proc(env: JNIEnvPtr, cls: JClass, name, sig: cstring): jfieldID {.jni.}

    GetStaticObjectField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID): jobject {.jni.}
    GetStaticBooleanField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID): jboolean {.jni.}
    GetStaticByteField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID): jbyte {.jni.}
    GetStaticCharField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID): jchar {.jni.}
    GetStaticShortField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID): jshort {.jni.}
    GetStaticIntField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID): jint {.jni.}
    GetStaticLongField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID): jlong {.jni.}
    GetStaticFloatField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID): jfloat {.jni.}
    GetStaticDoubleField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID): jdouble {.jni.}

    SetStaticObjectField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID, val: jobject) {.jni.}
    SetStaticBooleanField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID, val: jboolean) {.jni.}
    SetStaticByteField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID, val: jbyte) {.jni.}
    SetStaticCharField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID, val: jchar) {.jni.}
    SetStaticShortField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID, val: jshort) {.jni.}
    SetStaticIntField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID, val: jint) {.jni.}
    SetStaticLongField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID, val: jlong) {.jni.}
    SetStaticFloatField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID, val: jfloat) {.jni.}
    SetStaticDoubleField*: proc(env: JNIEnvPtr, obj: JClass, fieldId: jfieldID, val: jdouble) {.jni.}

    NewString*: proc(env: JNIEnvPtr, unicode: ptr jchar, len: jsize): jstring {.jni.}
    GetStringLength*: proc(env: JNIEnvPtr, str: jstring): jsize {.jni.}
    GetStringChars*: proc(env: JNIEnvPtr, str: jstring, isCopy: ptr jboolean): ptr jchar {.jni.}
    ReleaseStringChars*: proc(env: JNIEnvPtr, str: jstring, chars: ptr jchar) {.jni.}

    NewStringUTF*: proc(env: JNIEnvPtr, s: cstring): jstring {.jni.}
    GetStringUTFLength*: proc(env: JNIEnvPtr, str: jstring): jsize {.jni.}
    GetStringUTFChars*: proc(env: JNIEnvPtr, s: jstring, isCopy: ptr jboolean): cstring {.jni.}
    ReleaseStringUTFChars*: proc(env: JNIEnvPtr, s: jstring, cstr: cstring) {.jni.}

    GetArrayLength*: proc(env: JNIEnvPtr, arr: jarray): jsize {.jni.}

    NewObjectArray*: proc(env: JNIEnvPtr, size: jsize, clazz: JClass, init: jobject): jobjectArray {.jni.}
    GetObjectArrayElement*: proc(env: JNIEnvPtr, arr: jobjectArray, index: jsize): jobject {.jni.}
    SetObjectArrayElement*: proc(env: JNIEnvPtr, arr: jobjectArray, index: jsize, val: jobject) {.jni.}

    NewBooleanArray*: proc(env: JNIEnvPtr, len: jsize): jbooleanArray {.jni.}
    NewByteArray*: proc(env: JNIEnvPtr, len: jsize): jbyteArray {.jni.}
    NewCharArray*: proc(env: JNIEnvPtr, len: jsize): jcharArray {.jni.}
    NewShortArray*: proc(env: JNIEnvPtr, len: jsize): jshortArray {.jni.}
    NewIntArray*: proc(env: JNIEnvPtr, len: jsize): jintArray {.jni.}
    NewLongArray*: proc(env: JNIEnvPtr, len: jsize): jlongArray {.jni.}
    NewFloatArray*: proc(env: JNIEnvPtr, len: jsize): jfloatArray {.jni.}
    NewDoubleArray*: proc(env: JNIEnvPtr, len: jsize): jdoubleArray {.jni.}

    GetBooleanArrayElements*: proc(env: JNIEnvPtr, arr: jbooleanArray, isCopy: ptr jboolean): ptr jboolean {.jni.}
    GetByteArrayElements*: proc(env: JNIEnvPtr, arr: jbyteArray, isCopy: ptr jboolean): ptr jbyte {.jni.}
    GetCharArrayElements*: proc(env: JNIEnvPtr, arr: jcharArray, isCopy: ptr jboolean): ptr jchar {.jni.}
    GetShortArrayElements*: proc(env: JNIEnvPtr, arr: jshortArray, isCopy: ptr jboolean): ptr jshort {.jni.}
    GetIntArrayElements*: proc(env: JNIEnvPtr, arr: jintArray, isCopy: ptr jboolean): ptr jint {.jni.}
    GetLongArrayElements*: proc(env: JNIEnvPtr, arr: jlongArray, isCopy: ptr jboolean): ptr jlong {.jni.}
    GetFloatArrayElements*: proc(env: JNIEnvPtr, arr: jfloatArray, isCopy: ptr jboolean): ptr jfloat {.jni.}
    GetDoubleArrayElements*: proc(env: JNIEnvPtr, arr: jdoubleArray, isCopy: ptr jboolean): ptr jdouble {.jni.}

    ReleaseBooleanArrayElements*: proc(env: JNIEnvPtr, arr: jbooleanArray, elems: ptr jboolean, mode: jint) {.jni.}
    ReleaseByteArrayElements*: proc(env: JNIEnvPtr, arr: jbyteArray, elems: ptr jbyte, mode: jint) {.jni.}
    ReleaseCharArrayElements*: proc(env: JNIEnvPtr, arr: jcharArray, elems: ptr jchar, mode: jint) {.jni.}
    ReleaseShortArrayElements*: proc(env: JNIEnvPtr, arr: jshortArray, elems: ptr jshort, mode: jint) {.jni.}
    ReleaseIntArrayElements*: proc(env: JNIEnvPtr, arr: jintArray, elems: ptr jint, mode: jint) {.jni.}
    ReleaseLongArrayElements*: proc(env: JNIEnvPtr, arr: jlongArray, elems: ptr jlong, mode: jint) {.jni.}
    ReleaseFloatArrayElements*: proc(env: JNIEnvPtr, arr: jfloatArray, elems: ptr jfloat, mode: jint) {.jni.}
    ReleaseDoubleArrayElements*: proc(env: JNIEnvPtr, arr: jdoubleArray, elems: ptr jdouble, mode: jint) {.jni.}

    GetBooleanArrayRegion*: proc(env: JNIEnvPtr, arr: jbooleanArray, start, len: jsize, buf: ptr jboolean) {.jni.}
    GetByteArrayRegion*: proc(env: JNIEnvPtr, arr: jbyteArray, start, len: jsize, buf: ptr jbyte) {.jni.}
    GetCharArrayRegion*: proc(env: JNIEnvPtr, arr: jcharArray, start, len: jsize, buf: ptr jchar) {.jni.}
    GetShortArrayRegion*: proc(env: JNIEnvPtr, arr: jshortArray, start, len: jsize, buf: ptr jshort) {.jni.}
    GetIntArrayRegion*: proc(env: JNIEnvPtr, arr: jintArray, start, len: jsize, buf: ptr jint) {.jni.}
    GetLongArrayRegion*: proc(env: JNIEnvPtr, arr: jlongArray, start, len: jsize, buf: ptr jlong) {.jni.}
    GetFloatArrayRegion*: proc(env: JNIEnvPtr, arr: jfloatArray, start, len: jsize, buf: ptr jfloat) {.jni.}
    GetDoubleArrayRegion*: proc(env: JNIEnvPtr, arr: jdoubleArray, start, len: jsize, buf: ptr jdouble) {.jni.}

    SetBooleanArrayRegion*: proc(env: JNIEnvPtr, arr: jbooleanArray, start, len: jsize, buf: ptr jboolean) {.jni.}
    SetByteArrayRegion*: proc(env: JNIEnvPtr, arr: jbyteArray, start, len: jsize, buf: ptr jbyte) {.jni.}
    SetCharArrayRegion*: proc(env: JNIEnvPtr, arr: jcharArray, start, len: jsize, buf: ptr jchar) {.jni.}
    SetShortArrayRegion*: proc(env: JNIEnvPtr, arr: jshortArray, start, len: jsize, buf: ptr jshort) {.jni.}
    SetIntArrayRegion*: proc(env: JNIEnvPtr, arr: jintArray, start, len: jsize, buf: ptr jint) {.jni.}
    SetLongArrayRegion*: proc(env: JNIEnvPtr, arr: jlongArray, start, len: jsize, buf: ptr jlong) {.jni.}
    SetFloatArrayRegion*: proc(env: JNIEnvPtr, arr: jfloatArray, start, len: jsize, buf: ptr jfloat) {.jni.}
    SetDoubleArrayRegion*: proc(env: JNIEnvPtr, arr: jdoubleArray, start, len: jsize, buf: ptr jdouble) {.jni.}

    RegisterNatives*: proc(env: JNIEnvPtr, clazz: JClass, methods: ptr JNINativeMethod, nMethods: jint): jint {.jni.}
    UnregisterNatives*: proc(env: JNIEnvPtr, clazz: JClass): jint {.jni.}

    MonitorEnter*: proc(env: JNIEnvPtr, obj: jobject): jint {.jni.}
    MonitorExit*: proc(env: JNIEnvPtr, obj: jobject): jint {.jni.}

    GetJavaVM*: proc(env: JNIEnvPtr, vm: ptr JavaVMPtr): jint {.jni.}

    GetStringRegion*: proc(env: JNIEnvPtr, str: jstring, start, len: jsize, buf: ptr jchar) {.jni.}
    GetStringUTFRegion*: proc(env: JNIEnvPtr, str: jstring, start, len: jsize, buf: ptr char) {.jni.}

    GetPrimitiveArrayCritical*: proc(env: JNIEnvPtr, arr: jarray, isCopy: ptr jboolean): pointer {.jni.}
    ReleasePrimitiveArrayCritical*: proc(env: JNIEnvPtr, arr: jarray, carray: jarray, mode: jint) {.jni.}

    GetStringCritical*: proc(env: JNIEnvPtr, str: jstring, isCopy: ptr jboolean): ptr jchar {.jni.}
    ReleaseStringCritical*: proc(env: JNIEnvPtr, str: jstring, cstr: ptr jchar) {.jni.}

    NewWeakGlobalRef*: proc(env: JNIEnvPtr, obj: jobject): jweak {.jni.}
    DeleteWeakGlobalRef*: proc(env: JNIEnvPtr, r: jweak) {.jni.}

    ExceptionCheck*: proc(env: JNIEnvPtr): jboolean {.jni.}

    NewDirectByteBuffer*: proc(env: JNIEnvPtr, address: pointer, capacity: jlong): jobject {.jni.}
    GetDirectBufferAddress*: proc(env: JNIEnvPtr, buf: jobject): pointer {.jni.}
    GetDirectBufferCapacity*: proc(env: JNIEnvPtr, buf: jobject): jlong {.jni.}

    # New JNI 1.6 Features

    GetObjectRefType*: proc(env: JNIEnvPtr, obj: jobject): jobjectRefType {.jni.}

  JNIEnv* = ptr JNINativeInterface
  JNIEnvPtr* = ptr JNIEnv

  JNINativeMethod* = object
    name*: cstring
    signature*: cstring
    fnPtr*: pointer

  jobjectRefType* {.size: sizeof(cint).} = enum
    JNIInvalidRefType
    JNILocalRefType
    JNIGlobalRefType
    JNIWeakGlobalRefType

const
  JNI_VERSION_1_1* = 0x00010001.jint
  JNI_VERSION_1_2* = 0x00010002.jint
  JNI_VERSION_1_4* = 0x00010004.jint
  JNI_VERSION_1_6* = 0x00010006.jint
  JNI_VERSION_1_8* = 0x00010008.jint

const
  JNI_OK* = 0.jint
  JNI_ERR* = jint(-1)
  JNI_EDETACHED* = jint(-2)
  JNI_EVERSION* = jint(-3)
  JNI_ENOMEM* = jint(-4)
  JNI_EEXIST* = jint(-5)
  JNI_EINVAL* = jint(-6)

var JNI_CreateJavaVM*: proc (pvm: ptr JavaVMPtr, penv: ptr pointer, args: pointer): jint {.jni.}
var JNI_GetDefaultJavaVMInitArgs*: proc(vm_args: ptr JavaVMInitArgs): jint {.jni.}
var JNI_GetCreatedJavaVMs*: proc(vmBuf: ptr JavaVMPtr, bufLen: jsize, nVMs: ptr jsize): jint {.jni.}

proc isJVMLoaded*: bool {.gcsafe.} =
  not JNI_CreateJavaVM.isNil and not JNI_GetDefaultJavaVMInitArgs.isNil and not JNI_GetCreatedJavaVMs.isNil

proc linkWithJVMLib* =
  when defined(macosx):
    let jvm = findJVM()
    if not jvm.isSome:
      raise newException(Exception, "Could not find JVM")
    let libPath = jvm.get.root.parentDir.parentDir.cstring
    {.emit: """
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (const UInt8 *)`libPath`, strlen(`libPath`), true);
    if (url) {
      CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, url);
      CFRelease(url);

      if (bundle) {
        *(void**)&`JNI_CreateJavaVM` = CFBundleGetFunctionPointerForName(bundle, CFSTR("JNI_CreateJavaVM"));
        *(void**)&`JNI_GetDefaultJavaVMInitArgs` = CFBundleGetFunctionPointerForName(bundle, CFSTR("JNI_GetDefaultJavaVMInitArgs"));
        *(void**)&`JNI_GetCreatedJavaVMs` = CFBundleGetFunctionPointerForName(bundle, CFSTR("JNI_GetCreatedJavaVMs"));
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

    # Then try locating JVM dynamically
    if not isJVMLoaded():
      if not handle.isNil:
        unloadLib(handle)
      let foundJVM = findJVM()
      if foundJVM.isSome:
        handle = loadLib(foundJVM.get.lib)
        linkWithJVMModule(handle)

    if not isJVMLoaded():
      if not handle.isNil:
        unloadLib(handle)

  if not isJVMLoaded():
    raise newException(Exception, "JVM could not be loaded")

proc fqcn*(cls: string): string =
  ## Create fullqualified class name
  cls.replace(".", "/")

proc sigForClass*(cls: string): string =
  ## Create method/field signature part for class name
  "L" & fqcn(cls) & ";"

proc toJValue*(v: cfloat): jvalue = result.f = v
proc toJValue*(v: jdouble): jvalue = result.d = v
proc toJValue*(v: jint): jvalue = result.i = v
proc toJValue*(v: jlong): jvalue = result.j = v
proc toJValue*(v: jboolean): jvalue = result.z = v
proc toJValue*(v: bool): jvalue = result.z = if v: JVM_TRUE else: JVM_FALSE
proc toJValue*(v: jbyte): jvalue = result.b = v
proc toJValue*(v: jchar): jvalue = result.c = v
proc toJValue*(v: jshort): jvalue = result.s = v
proc toJValue*(v: jobject): jvalue = result.l = v

template fromJValue*(T: typedesc, v: jvalue): auto =
  when T is jboolean: v.z
  elif T is bool: v.z != JVM_FALSE
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
template jniSig*(t: typedesc[string]): string = sigForClass"java.lang.String"
template jniSig*(t: typedesc[jobject]): string = sigForClass"java.lang.Object"
template jniSig*(t: typedesc[void]): string = "V"
proc elementTypeOfOpenArrayType[OpenArrayType](dummy: OpenArrayType = @[]): auto = dummy[0]
template jniSig*(t: typedesc[openarray]): string = "[" & jniSig(type(elementTypeOfOpenArrayType[t]()))
template jniSig*(t: typedesc[seq]): string = "[" & jniSig(type(elementTypeOfOpenArrayType[t]()))

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

proc unexpectedType() = discard # Used only for compilation errors

proc callMethod*(e: JNIEnvPtr, T: typedesc, o: jobject, m: jmethodID, a: ptr jvalue): T {.inline.} =
  when T is jobject: e.CallObjectMethodA(e, o, m, a)
  elif T is jchar: e.CallCharMethodA(e, o, m, a)
  elif T is jbyte: e.CallByteMethodA(e, o, m, a)
  elif T is jshort: e.CallShortMethodA(e, o, m, a)
  elif T is jint: e.CallIntMethodA(e, o, m, a)
  elif T is jlong: e.CallLongMethodA(e, o, m, a)
  elif T is jfloat: e.CallFloatMethodA(e, o, m, a)
  elif T is jdouble: e.CallDoubleMethodA(e, o, m, a)
  elif T is jboolean: e.CallBooleanMethodA(e, o, m, a)
  elif T is void: e.CallVoidMethodA(e, o, m, a)
  else: unexpectedType(result)

proc callMethod*(e: JNIEnvPtr, T: typedesc, o: jobject, m: jmethodID, a: openarray[jvalue]): T {.inline.} =
  e.callMethod(T, o, m, cast[ptr jvalue](a))

proc callNonvirtualMethod*(e: JNIEnvPtr, T: typedesc, o: jobject, c: JClass, m: jmethodID, a: ptr jvalue): T {.inline.} =
  when T is jobject: e.CallNonvirtualObjectMethodA(e, o, c, m, a)
  elif T is jchar: e.CallNonvirtualCharMethodA(e, o, c, m, a)
  elif T is jbyte: e.CallNonvirtualByteMethodA(e, o, c, m, a)
  elif T is jshort: e.CallNonvirtualShortMethodA(e, o, c, m, a)
  elif T is jint: e.CallNonvirtualIntMethodA(e, o, c, m, a)
  elif T is jlong: e.CallNonvirtualLongMethodA(e, o, c, m, a)
  elif T is jfloat: e.CallNonvirtualFloatMethodA(e, o, c, m, a)
  elif T is jdouble: e.CallNonvirtualDoubleMethodA(e, o, c, m, a)
  elif T is jboolean: e.CallNonvirtualBooleanMethodA(e, o, c, m, a)
  elif T is void: e.CallNonvirtualVoidMethodA(e, o, c, m, a)
  else: unexpectedType(result)

proc callNonvirtualMethod*(e: JNIEnvPtr, T: typedesc, o: jobject, c: JClass, m: jmethodID, a: openarray[jvalue]): T {.inline.} =
  e.callNonvirtualMethod(T, o, c, m, cast[ptr jvalue](a))

proc getField*(e: JNIEnvPtr, T: typedesc, o: jobject, f: jfieldID): T {.inline.} =
  when T is jobject: e.GetObjectField(e, o, f)
  elif T is jchar: e.GetCharField(e, o, f)
  elif T is jbyte: e.GetByteField(e, o, f)
  elif T is jshort: e.GetShortField(e, o, f)
  elif T is jint: e.GetIntField(e, o, f)
  elif T is jlong: e.GetLongField(e, o, f)
  elif T is jfloat: e.GetFloatField(e, o, f)
  elif T is jdouble: e.GetDoubleField(e, o, f)
  elif T is jboolean: e.GetBooleanField(e, o, f)
  else: unexpectedType(result)

proc setField*[T](e: JNIEnvPtr, o: jobject, f: jfieldID, v: T) {.inline.} =
  when T is jobject: e.SetObjectField(e, o, f, v)
  elif T is jchar: e.SetCharField(e, o, f, v)
  elif T is jbyte: e.SetByteField(e, o, f, v)
  elif T is jshort: e.SetShortField(e, o, f, v)
  elif T is jint: e.SetIntField(e, o, f, v)
  elif T is jlong: e.SetLongField(e, o, f, v)
  elif T is jfloat: e.SetFloatField(e, o, f, v)
  elif T is jdouble: e.SetDoubleField(e, o, f, v)
  elif T is jboolean: e.SetBooleanField(e, o, f, v)
  else: unexpectedType(v)

proc callStaticMethod*(e: JNIEnvPtr, T: typedesc, c: JClass, m: jmethodID, a: ptr jvalue): T {.inline.} =
  when T is jobject: e.CallStaticObjectMethodA(e, c, m, a)
  elif T is jchar: e.CallStaticCharMethodA(e, c, m, a)
  elif T is jbyte: e.CallStaticByteMethodA(e, c, m, a)
  elif T is jshort: e.CallStaticShortMethodA(e, c, m, a)
  elif T is jint: e.CallStaticIntMethodA(e, c, m, a)
  elif T is jlong: e.CallStaticLongMethodA(e, c, m, a)
  elif T is jfloat: e.CallStaticFloatMethodA(e, c, m, a)
  elif T is jdouble: e.CallStaticDoubleMethodA(e, c, m, a)
  elif T is jboolean: e.CallStaticBooleanMethodA(e, c, m, a)
  elif T is void: e.CallStaticVoidMethodA(e, c, m, a)
  else: unexpectedType(result)

proc callStaticMethod*(e: JNIEnvPtr, T: typedesc, c: JClass, m: jmethodID, a: openarray[jvalue]): T {.inline.} =
  e.callStaticMethod(T, c, m, cast[ptr jvalue](a))

proc getStaticField*(e: JNIEnvPtr, T: typedesc, o: JClass, f: jfieldID): T {.inline.} =
  when T is jobject: e.GetStaticObjectField(e, o, f)
  elif T is jchar: e.GetStaticCharField(e, o, f)
  elif T is jbyte: e.GetStaticByteField(e, o, f)
  elif T is jshort: e.GetStaticShortField(e, o, f)
  elif T is jint: e.GetStaticIntField(e, o, f)
  elif T is jlong: e.GetStaticLongField(e, o, f)
  elif T is jfloat: e.GetStaticFloatField(e, o, f)
  elif T is jdouble: e.GetStaticDoubleField(e, o, f)
  elif T is jboolean: e.GetStaticBooleanField(e, o, f)
  else: unexpectedType(result)

proc setStaticField*[T](e: JNIEnvPtr, o: JClass, f: jfieldID, v: T) {.inline.} =
  when T is jobject: e.SetStaticObjectField(e, o, f, v)
  elif T is jchar: e.SetStaticCharField(e, o, f, v)
  elif T is jbyte: e.SetStaticByteField(e, o, f, v)
  elif T is jshort: e.SetStaticShortField(e, o, f, v)
  elif T is jint: e.SetStaticIntField(e, o, f, v)
  elif T is jlong: e.SetStaticLongField(e, o, f, v)
  elif T is jfloat: e.SetStaticFloatField(e, o, f, v)
  elif T is jdouble: e.SetStaticDoubleField(e, o, f, v)
  elif T is jboolean: e.SetStaticBooleanField(e, o, f, v)
  else: unexpectedType(v)

proc newArray*(e: JNIEnvPtr, T: typedesc, l: jsize): jtypedArray[T] {.inline.} =
  when T is jchar: e.NewCharArray(e, l)
  elif T is jbyte: e.NewByteArray(e, l)
  elif T is jshort: e.NewShortArray(e, l)
  elif T is jint: e.NewIntArray(e, l)
  elif T is jlong: e.NewLongArray(e, l)
  elif T is jfloat: e.NewFloatArray(e, l)
  elif T is jdouble: e.NewDoubleArray(e, l)
  elif T is jboolean: e.NewBooleanArray(e, l)
  else: unexpectedType(T)

proc getArrayElements*[T](e: JNIEnvPtr, a: jtypedArray[T], c: ptr jboolean): ptr T {.inline.} =
  when T is jchar: e.GetCharArrayElements(e, a, c)
  elif T is jbyte: e.GetByteArrayElements(e, a, c)
  elif T is jshort: e.GetShortArrayElements(e, a, c)
  elif T is jint: e.GetIntArrayElements(e, a, c)
  elif T is jlong: e.GetLongArrayElements(e, a, c)
  elif T is jfloat: e.GetFloatArrayElements(e, a, c)
  elif T is jdouble: e.GetDoubleArrayElements(e, a, c)
  elif T is jboolean: e.GetBooleanArrayElements(e, a, c)
  else: unexpectedType(T)

proc releaseArrayElements*[T](e: JNIEnvPtr, a: jtypedArray[T], v: ptr T, m: jint) {.inline.} =
  when T is jchar: e.ReleaseCharArrayElements(e, a, v, m)
  elif T is jbyte: e.ReleaseByteArrayElements(e, a, v, m)
  elif T is jshort: e.ReleaseShortArrayElements(e, a, v, m)
  elif T is jint: e.ReleaseIntArrayElements(e, a, v, m)
  elif T is jlong: e.ReleaseLongArrayElements(e, a, v, m)
  elif T is jfloat: e.ReleaseFloatArrayElements(e, a, v, m)
  elif T is jdouble: e.ReleaseDoubleArrayElements(e, a, v, m)
  elif T is jboolean: e.ReleaseBooleanArrayElements(e, a, v, m)
  else: unexpectedType(T)

proc getArrayRegion*[T](e: JNIEnvPtr, a: jtypedArray[T], s, l: jsize, b: ptr T) {.inline.} =
  when T is jchar: e.GetCharArrayRegion(e, a, s, l, b)
  elif T is jbyte: e.GetByteArrayRegion(e, a, s, l, b)
  elif T is jshort: e.GetShortArrayRegion(e, a, s, l, b)
  elif T is jint: e.GetIntArrayRegion(e, a, s, l, b)
  elif T is jlong: e.GetLongArrayRegion(e, a, s, l, b)
  elif T is jfloat: e.GetFloatArrayRegion(e, a, s, l, b)
  elif T is jdouble: e.GetDoubleArrayRegion(e, a, s, l, b)
  elif T is jboolean: e.GetBooleanArrayRegion(e, a, s, l, b)
  else: unexpectedType(T)

proc setArrayRegion*[T](e: JNIEnvPtr, a: jtypedArray[T], s, l: jsize, b: ptr T) {.inline.} =
  when T is jchar: e.SetCharArrayRegion(e, a, s, l, b)
  elif T is jbyte: e.SetByteArrayRegion(e, a, s, l, b)
  elif T is jshort: e.SetShortArrayRegion(e, a, s, l, b)
  elif T is jint: e.SetIntArrayRegion(e, a, s, l, b)
  elif T is jlong: e.SetLongArrayRegion(e, a, s, l, b)
  elif T is jfloat: e.SetFloatArrayRegion(e, a, s, l, b)
  elif T is jdouble: e.SetDoubleArrayRegion(e, a, s, l, b)
  elif T is jboolean: e.SetBooleanArrayRegion(e, a, s, l, b)
  else: unexpectedType(T)
