
import dynlib
import strutils
import typetraits
import macros

const jniHeader = "jni.h"

when defined macosx:
    {.emit: """
    #include <CoreFoundation/CoreFoundation.h>
    """.}


type JavaVMPtr* {.header: jniHeader.} = pointer
type JNIEnv* {.header: jniHeader.} = object
type JNIEnvPtr* = ptr JNIEnv

var currentEnv* : JNIEnvPtr

const JAVA_HOME = gorge("/usr/libexec/java_home")
const JNI_LIB_DIR = JAVA_HOME & "/jre/lib"
const JNI_LIB_SERVER_DIR = JNI_LIB_DIR & "/server"
const JNI_INCLUDE_DIR = JAVA_HOME & "/include"

{.passC: "-I" & JNI_INCLUDE_DIR.}

when defined macosx:
    {.passC: "-I" & JNI_INCLUDE_DIR & "/darwin".}
    {.passL: "-framework CoreFoundation".}

type JavaVM* = ref object of RootObj
    env*: JNIEnvPtr

type JavaVMOption* {.header: jniHeader.} = object
    optionString: cstring
    extraInfo: pointer

type jint* {.header: jniHeader.} = cint
type jsize* {.header: jniHeader.} = jint
type jchar* {.header: jniHeader.} = uint16
type jlong* {.header: jniHeader.} = int64
type jshort* {.header: jniHeader.} = int16
type jbyte* {.header: jniHeader.} = int8
type jfloat* {.header: jniHeader.} = cfloat
type jdouble* {.header: jniHeader.} = cdouble
type jboolean* {.header: jniHeader.} = uint8
type jclass* {.header: jniHeader.} = distinct pointer
type jmethodID* {.header: jniHeader.} = pointer
type jobject* {.header: jniHeader.} = pointer
type jfieldID* {.header: jniHeader.} = pointer
type jstring* {.header: jniHeader.} = jobject
type jthrowable* {.header: jniHeader.} = jobject
type jarray* {.header: jniHeader.} = jobject
type jobjectArray* {.header: jniHeader.} = jarray

proc `isNil`* (x: jclass): bool {.borrow.}

type jvalue* {.header: jniHeader, union.} = object
    z: jboolean
    b: jbyte
    c: jchar
    s: jshort
    i: jint
    j: jlong
    f: jfloat
    d: jdouble
    l: jobject


type JavaVMInitArgs* {.header: jniHeader.} = object
    version: jint

    nOptions: jint
    options: ptr JavaVMOption
    ignoreUnrecognized: jboolean

var JNI_VERSION_1_1* {.header: jniHeader.} : jint
var JNI_VERSION_1_2* {.header: jniHeader.} : jint
var JNI_VERSION_1_4* {.header: jniHeader.} : jint
var JNI_VERSION_1_6* {.header: jniHeader.} : jint
var JNI_VERSION_1_8* {.header: jniHeader.} : jint

var JNI_CreateJavaVM: proc (pvm: ptr JavaVMPtr, penv: ptr pointer, args: pointer): jint {.cdecl.}
var JNI_GetDefaultJavaVMInitArgs: proc(vm_args: ptr JavaVMInitArgs): jint {.cdecl.}

proc linkWithJVMLib() =
    when defined(macosx):
        let libPath : cstring = "/Library/Java/JavaVirtualMachines/jdk1.8.0_25.jdk"

        {.emit: """
        CFURLRef url = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (const UInt8 *)`libPath`, strlen(`libPath`), true);
        CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, url);
        CFRelease(url);

        `JNI_CreateJavaVM` = CFBundleGetFunctionPointerForName(bundle, CFSTR("JNI_CreateJavaVM"));
        `JNI_GetDefaultJavaVMInitArgs` = CFBundleGetFunctionPointerForName(bundle, CFSTR("JNI_GetDefaultJavaVMInitArgs"));
        """.}
    else:
        assert(false, "Not implemented!")

proc findClass*(env: JNIEnvPtr, name: cstring): jclass =
    {.emit: "`result` = (*`env`)->FindClass(`env`, `name`);".}

proc getObjectClass*(env: JNIEnvPtr, obj: jobject): jclass =
    {.emit: "`result` = (*`env`)->GetObjectClass(`env`, `obj`);".}

proc newString*(env: JNIEnvPtr, s: cstring): jstring =
    {.emit: "`result` = (*`env`)->NewStringUTF(`env`, `s`);".}

proc getString*(env: JNIEnvPtr, s: jstring): string =
    var cstr: cstring
    {.emit: "`cstr` = (*`env`)->GetStringUTFChars(`env`, `s`, NULL);".}
    result = $cstr
    {.emit: "(*`env`)->ReleaseStringUTFChars(`env`, `s`, `cstr`);".}

proc getMethodID*(env: JNIEnvPtr, clazz: jclass, name, sig: cstring): jmethodID =
    {.emit: "`result` = (*`env`)->GetMethodID(`env`, `clazz`, `name`, `sig`);".}

proc getFieldID*(env: JNIEnvPtr, clazz: jclass, name, sig: cstring): jfieldID =
    {.emit: "`result` = (*`env`)->GetFieldID(`env`, `clazz`, `name`, `sig`);".}

proc getStaticFieldID*(env: JNIEnvPtr, clazz: jclass, name, sig: cstring): jfieldID =
    {.emit: "`result` = (*`env`)->GetStaticFieldID(`env`, `clazz`, `name`, `sig`);".}


proc getObjectField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jobject =
    {.emit: "`result` = (*`env`)->GetObjectField(`env`, `obj`, `fieldId`);".}

proc getBooleanField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jboolean =
    {.emit: "`result` = (*`env`)->GetBooleanField(`env`, `obj`, `fieldId`);".}

proc getByteField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jbyte =
    {.emit: "`result` = (*`env`)->GetByteField(`env`, `obj`, `fieldId`);".}

proc getCharField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jchar =
    {.emit: "`result` = (*`env`)->GetCharField(`env`, `obj`, `fieldId`);".}

proc getShortField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jshort =
    {.emit: "`result` = (*`env`)->GetShortField(`env`, `obj`, `fieldId`);".}

proc getIntField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jint =
    {.emit: "`result` = (*`env`)->GetIntField(`env`, `obj`, `fieldId`);".}

proc getLongField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jlong =
    {.emit: "`result` = (*`env`)->GetLongField(`env`, `obj`, `fieldId`);".}

proc getFloatField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jfloat =
    {.emit: "`result` = (*`env`)->GetFloatField(`env`, `obj`, `fieldId`);".}

proc getDoubleField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID): jdouble =
    {.emit: "`result` = (*`env`)->GetDoubleField(`env`, `obj`, `fieldId`);".}

proc setObjectField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jobject) =
    {.emit: "(*`env`)->SetObjectField(`env`, `obj`, `fieldId`, `val`);".}

proc setBooleanField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jboolean) =
    {.emit: "(*`env`)->SetBooleanField(`env`, `obj`, `fieldId`, `val`);".}

proc setByteField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jbyte) =
    {.emit: "(*`env`)->SetByteField(`env`, `obj`, `fieldId`, `val`);".}

proc setCharField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jchar) =
    {.emit: "(*`env`)->SetCharField(`env`, `obj`, `fieldId`, `val`);".}

proc setShortField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jshort) =
    {.emit: "(*`env`)->SetShortField(`env`, `obj`, `fieldId`, `val`);".}

proc setIntField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jint) =
    {.emit: "(*`env`)->SetIntField(`env`, `obj`, `fieldId`, `val`);".}

proc setLongField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jlong) =
    {.emit: "(*`env`)->SetLongField(`env`, `obj`, `fieldId`, `val`);".}

proc setFloatField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jfloat) =
    {.emit: "(*`env`)->SetFloatField(`env`, `obj`, `fieldId`, `val`);".}

proc setDoubleField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jdouble) =
    {.emit: "(*`env`)->SetDoubleField(`env`, `obj`, `fieldId`, `val`);".}




proc getStaticObjectField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jobject =
    {.emit: "`result` = (*`env`)->GetStaticObjectField(`env`, `obj`, `fieldId`);".}

proc getStaticBooleanField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jboolean =
    {.emit: "`result` = (*`env`)->GetStaticBooleanField(`env`, `obj`, `fieldId`);".}

proc getStaticByteField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jbyte =
    {.emit: "`result` = (*`env`)->GetStaticByteField(`env`, `obj`, `fieldId`);".}

proc getStaticCharField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jchar =
    {.emit: "`result` = (*`env`)->GetStaticCharField(`env`, `obj`, `fieldId`);".}

proc getStaticShortField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jshort =
    {.emit: "`result` = (*`env`)->GetStaticShortField(`env`, `obj`, `fieldId`);".}

proc getStaticIntField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jint =
    {.emit: "`result` = (*`env`)->GetStaticIntField(`env`, `obj`, `fieldId`);".}

proc getStaticLongField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jlong =
    {.emit: "`result` = (*`env`)->GetStaticLongField(`env`, `obj`, `fieldId`);".}

proc getStaticFloatField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jfloat =
    {.emit: "`result` = (*`env`)->GetStaticFloatField(`env`, `obj`, `fieldId`);".}

proc getStaticDoubleField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jdouble =
    {.emit: "`result` = (*`env`)->GetStaticDoubleField(`env`, `obj`, `fieldId`);".}



proc setStaticObjectField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jobject) =
    {.emit: "(*`env`)->SetStaticObjectField(`env`, `obj`, `fieldId`, `val`);".}

proc setStaticBooleanField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jboolean) =
    {.emit: "(*`env`)->SetStaticBooleanField(`env`, `obj`, `fieldId`, `val`);".}

proc setStaticByteField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jbyte) =
    {.emit: "(*`env`)->SetStaticByteField(`env`, `obj`, `fieldId`, `val`);".}

proc setStaticCharField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jchar) =
    {.emit: "(*`env`)->SetStaticCharField(`env`, `obj`, `fieldId`, `val`);".}

proc setStaticShortField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jshort) =
    {.emit: "(*`env`)->SetStaticShortField(`env`, `obj`, `fieldId`, `val`);".}

proc setStaticIntField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jint) =
    {.emit: "(*`env`)->SetStaticIntField(`env`, `obj`, `fieldId`, `val`);".}

proc setStaticLongField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jlong) =
    {.emit: "(*`env`)->SetStaticLongField(`env`, `obj`, `fieldId`, `val`);".}

proc setStaticFloatField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jfloat) =
    {.emit: "(*`env`)->SetStaticFloatField(`env`, `obj`, `fieldId`, `val`);".}

proc setStaticDoubleField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jdouble) =
    {.emit: "(*`env`)->SetStaticDoubleField(`env`, `obj`, `fieldId`, `val`);".}


proc getObjectField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jobject =
    env.getStaticObjectField(obj, fieldId)

proc getBooleanField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jboolean =
    env.getStaticBooleanField(obj, fieldId)

proc getByteField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jbyte =
    env.getStaticByteField(obj, fieldId)

proc getCharField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jchar =
    env.getStaticCharField(obj, fieldId)

proc getShortField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jshort =
    env.getStaticShortField(obj, fieldId)

proc getIntField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jint =
    env.getStaticIntField(obj, fieldId)

proc getLongField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jlong =
    env.getStaticLongField(obj, fieldId)

proc getFloatField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jfloat =
    env.getStaticFloatField(obj, fieldId)

proc getDoubleField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): jdouble =
    env.getStaticDoubleField(obj, fieldId)



proc getStaticMethodID*(env: JNIEnvPtr, clazz: jclass, name, sig: cstring): jmethodID =
    {.emit: "`result` = (*`env`)->GetStaticMethodID(`env`, `clazz`, `name`, `sig`);".}

proc newObjectArray*(env: JNIEnvPtr, size: jsize, clazz: jclass, init: jobject): jobjectArray =
    {.emit: "`result` = (*`env`)->NewObjectArray(`env`, `size`, `clazz`, `init`);".}

proc getObjectArrayElement*(env: JNIEnvPtr, arr: jobjectArray, index: jsize): jobject =
    {.emit: "`result` = (*`env`)->GetObjectArrayElement(`env`, `arr`, `index`);".}

proc setObjectArrayElement*(env: JNIEnvPtr, arr: jobjectArray, index: jsize, val: jobject) =
    {.emit: "(*`env`)->SetObjectArrayElement(`env`, `arr`, `index`, `val`);".}

proc setObjectArrayElement*(env: JNIEnvPtr, arr: jobjectArray, index: jsize, str: string) =
    env.setObjectArrayElement(arr, index, env.newString(str))

proc newObject*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): jobject =
    {.emit: "`result` = (*`env`)->NewObjectA(`env`, `clazz`, `methodID`, `args`);".}

proc callStaticVoidMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]) =
    {.emit: "(*`env`)->CallStaticVoidMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callVoidMethod*(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: openarray[jvalue]) =
    {.emit: "(*`env`)->CallVoidMethodA(`env`, `obj`, `methodID`, `args`);".}

proc callStaticObjectMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): jobject =
    {.emit: "`result` = (*`env`)->CallStaticObjectMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callStaticBooleanMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): jboolean =
    {.emit: "`result` = (*`env`)->CallStaticBooleanMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callStaticByteMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): jbyte =
    {.emit: "`result` = (*`env`)->CallStaticByteMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callStaticCharMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): jchar =
    {.emit: "`result` = (*`env`)->CallStaticCharMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callStaticShortMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): jshort =
    {.emit: "`result` = (*`env`)->CallStaticShortMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callStaticIntMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): jint =
    {.emit: "`result` = (*`env`)->CallStaticIntMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callStaticLongMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): jlong =
    {.emit: "`result` = (*`env`)->CallStaticLongMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callStaticFloatMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): jfloat =
    {.emit: "`result` = (*`env`)->CallStaticFloatMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callStaticDoubleMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): jdouble =
    {.emit: "`result` = (*`env`)->CallStaticDoubleMethodA(`env`, `clazz`, `methodID`, `args`);".}


proc callObjectMethod*(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: openarray[jvalue]): jobject =
    {.emit: "`result` = (*`env`)->CallObjectMethodA(`env`, `obj`, `methodID`, `args`);".}

proc callBooleanMethod*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: openarray[jvalue]): jboolean =
    {.emit: "`result` = (*`env`)->CallBooleanMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callByteMethod*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: openarray[jvalue]): jbyte =
    {.emit: "`result` = (*`env`)->CallByteMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callCharMethod*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: openarray[jvalue]): jchar =
    {.emit: "`result` = (*`env`)->CallCharMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callShortMethod*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: openarray[jvalue]): jshort =
    {.emit: "`result` = (*`env`)->CallShortMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callIntMethod*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: openarray[jvalue]): jint =
    {.emit: "`result` = (*`env`)->CallIntMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callLongMethod*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: openarray[jvalue]): jlong =
    {.emit: "`result` = (*`env`)->CallLongMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callFloatMethod*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: openarray[jvalue]): jfloat =
    {.emit: "`result` = (*`env`)->CallFloatMethodA(`env`, `clazz`, `methodID`, `args`);".}

proc callDoubleMethod*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: openarray[jvalue]): jdouble =
    {.emit: "`result` = (*`env`)->CallDoubleMethodA(`env`, `clazz`, `methodID`, `args`);".}



proc exceptionOccurred*(env: JNIEnvPtr): jthrowable =
    {.emit: "`result` = (*`env`)->ExceptionOccurred(`env`);".}

proc exceptionDescribe*(env: JNIEnvPtr) =
    {.emit: "(*`env`)->ExceptionDescribe(`env`);".}


proc setField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jobject) =
    env.setObjectField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jboolean) =
    env.setBooleanField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jbyte) =
    env.setByteField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jchar) =
    env.setCharField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jshort) =
    env.setShortField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jint) =
    env.setIntField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jlong) =
    env.setLongField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jfloat) =
    env.setFloatField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: jdouble) =
    env.setDoubleField(obj, fieldId, val)


proc setField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jobject) =
    env.setStaticObjectField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jboolean) =
    env.setStaticBooleanField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jbyte) =
    env.setStaticByteField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jchar) =
    env.setStaticCharField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jshort) =
    env.setStaticShortField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jint) =
    env.setStaticIntField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jlong) =
    env.setStaticLongField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jfloat) =
    env.setStaticFloatField(obj, fieldId, val)

proc setField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: jdouble) =
    env.setStaticDoubleField(obj, fieldId, val)


template declareProcsForType(typeName, capitalizedTypeName: expr): stmt =
    template `call capitalizedTypeName Methodv`*(env: JNIEnvPtr, obj: jobject, methodID: jmethodID, args: varargs[jvalue, toJValue]): typeName {.inject.} =
        env.`call capitalizedTypeName Method`(obj, methodID, args)

    template `call capitalizedTypeName Methodv`*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: varargs[jvalue, toJValue]): typeName {.inject.} =
        env.`callStatic capitalizedTypeName Method`(clazz, methodID, args)

declareProcsForType(jint, Int)

proc getClassName(env: JNIEnvPtr, clazz: jclass): string =
    assert(not clazz.isNil)
    # Now get the class object's class descriptor
    let cls = env.getObjectClass(cast[jobject](clazz))
    # Find the getName() method on the class object
    let mid = env.getMethodID(cls, "getName", "()Ljava/lang/String;")
    let strObj = env.callObjectMethod(clazz.jobject, mid, [])
    result = env.getString(strObj)

proc getMethods(env: JNIEnvPtr, clazz: jclass): jobject =
    let cls = env.getObjectClass(cast[jobject](clazz))
    # Find the getName() method on the class object
    let mid = env.getMethodID(cls, "getMethods", "()[Ljava/lang/reflect/Method;")
    result = env.callObjectMethod(clazz.jobject, mid, [])


proc callObjectMethodv*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: varargs[jvalue, toJValue]): jobject =
    env.callStaticObjectMethod(clazz, methodID, args)

proc callObjectMethodv*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: varargs[jvalue, toJValue]): jobject =
    env.callObjectMethod(clazz, methodID, args)

proc callVoidMethodv*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: varargs[jvalue, toJValue]) =
    env.callStaticVoidMethod(clazz, methodID, args)

proc callVoidMethodv*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: varargs[jvalue, toJValue]) =
    env.callVoidMethod(clazz, methodID, args)

proc callBooleanMethodv*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: varargs[jvalue, toJValue]): jboolean =
    env.callStaticBooleanMethod(clazz, methodID, args)

proc callBooleanMethodv*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: varargs[jvalue, toJValue]): jboolean =
    env.callBooleanMethod(clazz, methodID, args)

proc callByteMethodv*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: varargs[jvalue, toJValue]): jbyte =
    env.callStaticByteMethod(clazz, methodID, args)

proc callByteMethodv*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: varargs[jvalue, toJValue]): jbyte =
    env.callByteMethod(clazz, methodID, args)

proc callCharMethodv*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: varargs[jvalue, toJValue]): jchar =
    env.callStaticCharMethod(clazz, methodID, args)

proc callCharMethodv*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: varargs[jvalue, toJValue]): jchar =
    env.callCharMethod(clazz, methodID, args)

proc callShortMethodv*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: varargs[jvalue, toJValue]): jshort =
    env.callStaticShortMethod(clazz, methodID, args)

proc callShortMethodv*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: varargs[jvalue, toJValue]): jshort =
    env.callShortMethod(clazz, methodID, args)

#proc callIntMethodv*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: varargs[jvalue, toJValue]): jint =
#    env.callStaticIntMethod(clazz, methodID, args)

#proc callIntMethodv*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: varargs[jvalue, toJValue]): jint =
#    env.callIntMethod(clazz, methodID, args)

proc callLongMethodv*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: varargs[jvalue, toJValue]): jlong =
    env.callStaticLongMethod(clazz, methodID, args)

proc callLongMethodv*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: varargs[jvalue, toJValue]): jlong =
    env.callLongMethod(clazz, methodID, args)

proc callFloatMethodv*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: varargs[jvalue, toJValue]): jfloat =
    env.callStaticFloatMethod(clazz, methodID, args)

proc callFloatMethodv*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: varargs[jvalue, toJValue]): jfloat =
    env.callFloatMethod(clazz, methodID, args)

proc callDoubleMethodv*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: varargs[jvalue, toJValue]): jdouble =
    env.callStaticDoubleMethod(clazz, methodID, args)

proc callDoubleMethodv*(env: JNIEnvPtr, clazz: jobject, methodID: jmethodID, args: varargs[jvalue, toJValue]): jdouble =
    env.callDoubleMethod(clazz, methodID, args)

proc newObjectv*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: varargs[jvalue, toJValue]): jobject =
    env.newObject(clazz, methodID, args)


proc toJValue*(s: string): jvalue =
    result.l = currentEnv.newString(s)

proc toJValue*(s: cstring): jvalue =
    result.l = currentEnv.newString(s)

proc toJValue*(f: cfloat): jvalue =
    result.f = f

#proc toJValue*(i: int): jvalue =
#    result.i = i.jint

proc toJValue*(i: jint): jvalue =
    result.i = i

proc toJValue*(i: jlong): jvalue =
    result.j = i

proc toJValue*(a: openarray[string]): jvalue =
    result.l = currentEnv.newObjectArray(a.len.jsize, currentEnv.findClass("java/lang/String"), nil)
    for i, v in a:
        currentEnv.setObjectArrayElement(result.l, i.jsize, v)

proc toJValue*(a: openarray[jobject]): jvalue =
    assert(a.len > 0, "Unknown element type")
    let cl = currentEnv.getObjectClass(a[0])
    result.l = currentEnv.newObjectArray(a.len.jsize, cl, nil)
    for i, v in a:
        currentEnv.setObjectArrayElement(result.l, i.jsize, v)

proc newJavaVM*(options: openarray[string] = []): JavaVM =
    linkWithJVMLib()
    result.new()

    var args: JavaVMInitArgs
    args.version = JNI_VERSION_1_8

    var opts = newSeq[JavaVMOption](options.len)
    for i, o in options:
        opts[i].optionString = o

    args.nOptions = options.len.jint
    if options.len > 0:
        args.options = addr opts[0]

    var vm : JavaVMPtr

    let res = JNI_CreateJavaVM(addr vm, cast[ptr pointer](addr result.env), addr args)
    if res < 0:
        result = nil
    else:
        currentEnv = result.env

proc dotExprToString(e: NimNode): string {.compileTime.} =
    if e[0].kind == nnkIdent:
        result = $(e[0]) & "." & $(e[1])
    else:
        result = dotExprToString(e[0]) & "." & $e[1]

template methodSignatureForType*(t: typedesc[jlong]): string = "J"
template methodSignatureForType*(t: typedesc[jint]): string = "I"
template methodSignatureForType*(t: typedesc[jboolean]): string = "Z"
template methodSignatureForType*(t: typedesc[jbyte]): string = "B"
template methodSignatureForType*(t: typedesc[jchar]): string = "C"
template methodSignatureForType*(t: typedesc[jshort]): string = "S"
template methodSignatureForType*(t: typedesc[jfloat]): string = "F"
template methodSignatureForType*(t: typedesc[jdouble]): string = "D"
template methodSignatureForType*(t: typedesc[string]): string = "Ljava/lang/String;"
template methodSignatureForType*(t: typedesc[void]): string = "V"

# TODO: This should be templatized somehow...
template methodSignatureForType*(t: typedesc[openarray[string]]): string = "[Ljava/lang/String;"

proc propertySetter(e: NimNode): string {.compileTime.} =
    result = ""
    if e[0].kind == nnkAccQuoted and e[0].len == 2 and $(e[0][1]) == "=":
        result = $(e[0][0])

proc propertyGetter(e: NimNode): string {.compileTime.} =
    result = ""
    if e[0].kind == nnkAccQuoted and e[0].len == 2 and $(e[0][0]) == ".":
        result = $(e[0][1])

proc generateJNIProc(e: NimNode): NimNode {.compileTime.} =
    let isStatic = e.params[1][1].kind == nnkBracketExpr
    result = e
    var isConstructor = result[0]
    var className = ""

    if not isStatic:
        result = newNimNode(nnkProcDef)
        e.copyChildrenTo(result)
        className = $(result.params[1][1])
    else:
        className = $(result.params[1][1][1])

    var argListStr = ""
    var methodSignature = ""
    for i in 2 .. < result.params.len:
        for j in 0 .. < result.params[i].len - 2:
            let paramName = $(result.params[i][j])
            argListStr &= ", " & paramName
            methodSignature &= " & methodSignatureForType(type(" & paramName & "))"

    if methodSignature == "":
        methodSignature = " & \"\" "

    var isCtor = false

    let propSetter = propertySetter(result)
    let propGetter = propertyGetter(result)

    let isProp = propSetter != "" or propGetter != ""

    var methodName = ""
    if not isProp:
        methodName = $result[0]
        if methodName == "new":
            methodName = "<init>"
            result.params[0] = newIdentNode(className)
            isCtor = true
    elif propSetter.len > 0:
        methodName = propSetter
    else:
        methodName = propGetter

    let firstArgName = $(result.params[1][0])

    let bodyStmt = """
const isStatic = """ & $isStatic & """

const methodName = """ & "\"" & methodName & "\"" & """

const propSetter = """ & "\"" & propSetter & "\"" & """

const propGetter = """ & "\"" & propGetter & "\"" & """

const isCtor = """ & $isCtor & """

const isProp = """ & $isProp & """

when isProp:
    var fieldOrMethodId {.global.}: jfieldID
else:
    var fieldOrMethodId {.global.}: jmethodID

when isStatic:
    var clazz {.global.}: jclass

if fieldOrMethodId.isNil:
    when isCtor:
        const retTypeSig = "V"
    elif declared(result):
        const retTypeSig = methodSignatureForType(type(result))
    else:
        const retTypeSig = "V"

    when propGetter.len > 0:
        const sig = retTypeSig
    elif propSetter.len > 0:
        const sig = "" """ & methodSignature & """
    else:
        const sig = ("(" """ & methodSignature & """ & ")" & retTypeSig )
    let fullyQualifiedName = fullyQualifiedClassName(""" & className & """)
    when not isStatic:
        var clazz : jclass
    clazz = currentEnv.findClass(fullyQualifiedName)
    assert(not clazz.isNil, "Can not find class: " & fullyQualifiedName)
    when isProp:
        when isStatic:
            fieldOrMethodId = currentEnv.getStaticFieldID(clazz, methodName, sig)
        else:
            fieldOrMethodId = currentEnv.getFieldID(clazz, methodName, sig)
    elif isStatic and not isCtor:
        fieldOrMethodId = currentEnv.getStaticMethodID(clazz, methodName, sig)
        assert(not fieldOrMethodId.isNil, "Can not find static method: " & fullyQualifiedName & "::" & methodName & " sig: " & sig)
    else:
        fieldOrMethodId = currentEnv.getMethodID(clazz, methodName, sig)
        assert(not fieldOrMethodId.isNil, "Can not find method: " & fullyQualifiedName & "::" & methodName & " sig: " & sig)

when isStatic:
    let obj = clazz
else:
    let obj = jobject(""" & firstArgName & """)

when propGetter.len > 0:
    when type(result) is jint:
        result = currentEnv.getIntField(obj, fieldOrMethodId)
    elif type(result) is jlong:
        result = currentEnv.getLongField(obj, fieldOrMethodId)
    elif type(result) is jchar:
        result = currentEnv.getCharField(obj, fieldOrMethodId)
    elif type(result) is jbyte:
        result = currentEnv.getByteField(obj, fieldOrMethodId)
    elif type(result) is jshort:
        result = currentEnv.getShortField(obj, fieldOrMethodId)
    elif type(result) is jboolean:
        result = currentEnv.getBooleanField(obj, fieldOrMethodId)
    elif type(result) is string:
        result = currentEnv.getString(currentEnv.getObjectField(obj, fieldOrMethodId))
    else:
        result = type(result)(currentEnv.getObjectField(obj, fieldOrMethodId))
elif propSetter.len > 0:
    currentEnv.setField(obj, fieldOrMethodId """ & argListStr &""")
elif isCtor:
    result = type(result)((currentEnv.newObjectv(obj, fieldOrMethodId """ & argListStr & """)))
elif declared(result):
    when type(result) is jint:
        result = currentEnv.callIntMethodv(obj, fieldOrMethodId """ & argListStr & """)
    elif type(result) is jboolean:
        result = currentEnv.callBooleanMethodv(obj, fieldOrMethodId """ & argListStr & """)
    elif type(result) is string:
        result = currentEnv.getString(currentEnv.callObjectMethodv(obj, fieldOrMethodId """ & argListStr & """))
    elif type(result) is jshort:
        result = currentEnv.callShortMethodv(obj, fieldOrMethodId """ & argListStr & """)
    elif type(result) is jlong:
        result = currentEnv.callLongMethodv(obj, fieldOrMethodId """ & argListStr & """)
    elif type(result) is jbyte:
        result = currentEnv.callByteMethodv(obj, fieldOrMethodId """ & argListStr & """)
    elif type(result) is jchar:
        result = currentEnv.callCharMethodv(obj, fieldOrMethodId """ & argListStr & """)
    else:
        result = type(result)(currentEnv.callObjectMethodv(obj, fieldOrMethodId """ & argListStr & """))
else:
    currentEnv.callVoidMethodv(obj, fieldOrMethodId """ & argListStr & """)

if currentEnv.exceptionOccurred() != nil:
    currentEnv.exceptionDescribe()
"""
    result.body = parseStmt(bodyStmt)

proc generateTypeDefinition(className, fullyQualifiedName: string): NimNode {.compileTime.} =
    result = newStmtList()
    result.add(parseStmt("type " & className & "* = distinct jobject"))
    result.add(parseStmt("template fullyQualifiedClassName*(t: typedesc[" & className & "]): string = \"" & fullyQualifiedName.replace(".", "/") & "\""))
    result.add(parseStmt("template methodSignatureForType*(t: typedesc[" & className & "]): string = \"L\" & fullyQualifiedClassName(t) & \";\""))
    result.add(parseStmt("proc toJValue*(t:" & className & "): jvalue = result.l = jobject(t)"))

proc generateTypeDefinitionFromDotExpr(e: NimNode): NimNode {.compileTime.} =
    generateTypeDefinition($e[1], dotExprToString(e))

proc processJnimportNode(e: NimNode): NimNode {.compileTime.} =
    if e.kind == nnkDotExpr:
        result = generateTypeDefinitionFromDotExpr(e)
    elif e.kind == nnkIdent:
        result = generateTypeDefinition($e, $e)
    elif e.kind == nnkImportStmt:
        result = processJnimportNode(e[0])
    elif e.kind == nnkProcDef:
        result = generateJNIProc(e)
    else:
        echo treeRepr(e)
        assert(false, "Invalid use of jnimport")

macro jnimport*(e: expr): stmt =
    if e.kind == nnkStmtList:
        result = newStmtList()
        for c in e.children:
            result.add(processJnimportNode(c))
    else:
        result = processJnimportNode(e)

