
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


template declareProcsForType(T, capitalizedTypeName: expr): stmt =
    template setField*(env: JNIEnvPtr, obj: jobject, fieldId: jfieldID, val: T) =
        env.`set capitalizedTypeName Field`(obj, fieldId, val)

    template setField*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID, val: T) =
        env.`setStatic capitalizedTypeName Field`(obj, fieldId, val)

    template `get capitalizedTypeName Field`*(env: JNIEnvPtr, obj: jclass, fieldId: jfieldID): T =
        env.`getStatic capitalizedTypeName Field`(obj, fieldId)

    template `call capitalizedTypeName Method`*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]): T {.inject.} =
        env.`callStatic capitalizedTypeName Method`(clazz, methodID, args)

declareProcsForType(jobject, Object)
declareProcsForType(jint, Int)
declareProcsForType(jboolean, Boolean)
declareProcsForType(jbyte, Byte)
declareProcsForType(jshort, Short)
declareProcsForType(jlong, Long)
declareProcsForType(jchar, Char)
declareProcsForType(jfloat, Float)
declareProcsForType(jdouble, Double)

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


proc callVoidMethod*(env: JNIEnvPtr, clazz: jclass, methodID: jmethodID, args: openarray[jvalue]) =
    env.callStaticVoidMethod(clazz, methodID, args)

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

template getFieldOfType*(env: JNIEnvPtr, T: typedesc, o: expr, fieldId: jfieldID): expr =
    when T is jint:
        env.getIntField(o, fieldId)
    elif T is jlong:
        env.getLongField(o, fieldId)
    elif T is jboolean:
        env.getBooleanField(o, fieldId)
    elif T is jchar:
        env.getCharField(o, fieldId)
    elif T is jbyte:
        env.getByteField(o, fieldId)
    elif T is jshort:
        env.getShortField(o, fieldId)
    elif T is string:
        env.getString(currentEnv.getObjectField(o, fieldId))
    else:
        T(env.getObjectField(o, fieldId))

template callMethodOfType*(env: JNIEnvPtr, T: typedesc, o: expr, methodId: jmethodID, args: varargs[jvalue, toJValue]): expr =
    when T is jint:
        env.callIntMethod(o, methodID, args)
    elif T is jlong:
        env.callLongMethod(o, methodID, args)
    elif T is jboolean:
        env.callBooleanMethod(o, methodID, args)
    elif T is jchar:
        env.callCharMethod(o, methodID, args)
    elif T is jbyte:
        env.callByteMethod(o, methodID, args)
    elif T is jshort:
        env.callShortMethod(o, methodID, args)
    elif T is string:
        env.getString(currentEnv.callObjectMethod(o, methodID, args))
    elif T is void:
        env.callVoidMethod(o, methodID, args)
    else:
        T(env.callObjectMethod(o, methodID, args))

proc concatStrings*(args: varargs[string]): string {.compileTime.} = args.join()

macro getArgumentsSignatureFromVararg(e: expr): expr =
    result = newCall("concatStrings")
    for i in e.children:
        result.add(newCall("methodSignatureForType", newCall("type", i)))

proc propertyGetter(name: string): string {.compileTime.} =
    result = ""
    if name[0] == '.':
        result = name[1 .. ^1]

proc propertySetter(name: string): string {.compileTime.} =
    result = ""
    if name[^1] == '=':
        result = name[0 .. ^2]

macro appendVarargToCall(c: expr, e: expr): expr =
    result = c
    for a in e.children:
        result.add(a)

template jniImpl*(methodName: string, isStaticWorkaround: int, obj: expr, args: varargs[expr]): stmt =
    const isStatic = isStaticWorkaround == 1

    const argsSignature = getArgumentsSignatureFromVararg(args)
    const propGetter = propertyGetter(methodName)
    const propSetter = propertySetter(methodName)

    const propName = when propGetter.len > 0: propGetter else: propSetter
    const isCtor = methodName == "new"
    const isProp = propSetter.len > 0 or propGetter.len > 0

    const javaSymbolName = when isCtor:
            "<init>"
        elif isProp:
            propName
        else:
            methodName

    var fieldOrMethodId {.global.} = when isProp: jfieldID(nil) else: jmethodID(nil)

    const fullyQualifiedName = when isStatic:
            fullyQualifiedClassName(obj)
        else:
            fullyQualifiedClassName(type(obj))

    when isStatic:
        var clazz {.global.}: jclass

    if fieldOrMethodId.isNil:
        const retTypeSig = when isCtor or not declared(result):
                "V"
            else:
                methodSignatureForType(type(result))

        const sig = when propGetter.len > 0:
                retTypeSig
            elif propSetter.len > 0:
                argsSignature
            else:
                "(" & argsSignature & ")" & retTypeSig

        let localClazz = currentEnv.findClass(fullyQualifiedName)
        assert(not localClazz.isNil, "Can not find class: " & fullyQualifiedName)

        when isStatic:
            clazz = localClazz

        var symbolKind = ""

        when isProp:
            when isStatic:
                symbolKind = "static field"
                fieldOrMethodId = currentEnv.getStaticFieldID(localClazz, javaSymbolName, sig)
            else:
                symbolKind = "field"
                fieldOrMethodId = currentEnv.getFieldID(localClazz, javaSymbolName, sig)
        elif isStatic and not isCtor:
            symbolKind = "static method"
            fieldOrMethodId = currentEnv.getStaticMethodID(localClazz, javaSymbolName, sig)
        else:
            symbolKind = "method"
            fieldOrMethodId = currentEnv.getMethodID(localClazz, javaSymbolName, sig)
        assert(not fieldOrMethodId.isNil, "Can not find " & symbolKind & ": " & fullyQualifiedName & "::" & javaSymbolName & "sig: " & sig)

    let obj = when isStatic: clazz else: jobject(obj)

    when propGetter.len > 0:
        result = currentEnv.getFieldOfType(type(result), obj, fieldOrMethodId)
    elif propSetter.len > 0:
        appendVarargToCall(setField(currentEnv, obj, fieldOrMethodId), args)
    elif isCtor:
        result = type(result)(appendVarargToCall(newObjectv(currentEnv, obj, fieldOrMethodId), args))
    elif declared(result):
        result = appendVarargToCall(callMethodOfType(currentEnv, type(result), obj, fieldOrMethodId), args)
    else:
        appendVarargToCall(callMethodOfType(currentEnv, void, obj, fieldOrMethodId), args)

    if currentEnv.exceptionOccurred() != nil:
        currentEnv.exceptionDescribe()

proc nodeToString(e: NimNode): string {.compileTime.} =
    if e.kind == nnkIdent:
        result = $e
    elif e.kind == nnkAccQuoted:
        result = ""
        for s in e.children:
            result &= nodeToString(s)
    elif e.kind == nnkDotExpr:
        result = nodeToString(e[0]) & "." & nodeToString(e[1])
    else:
        echo treeRepr(e)
        assert(false, "Cannot stringize node")

proc generateJNIProc(e: NimNode): NimNode {.compileTime.} =
    result = e
    let isStatic = e.params[1][1].kind == nnkBracketExpr
    let procName = nodeToString(result[0])
    if procName == "new":
        var className = ""
        if not isStatic:
            className = $(result.params[1][1])
        else:
            className = $(result.params[1][1][1])
        result.params[0] = newIdentNode(className)

    let bodyStmt = newCall("jniImpl", newLit(procName), newLit(isStatic), result.params[1][0])
    for i in 2 .. < result.params.len:
        for j in 0 .. < result.params[i].len - 2:
            bodyStmt.add(result.params[i][j])

    result.body = bodyStmt

template defineJNIType*(className: expr, fullyQualifiedName: string): stmt =
    type `className`* {.inject.} = distinct jobject
    template fullyQualifiedClassName*(t: typedesc[`className`]): string = fullyQualifiedName.replace(".", "/")
    template methodSignatureForType*(t: typedesc[`className`]): string = "L" & fullyQualifiedClassName(t) & ";"
    proc toJValue*(t: `className`): jvalue = result.l = jobject(t)

proc generateTypeDefinition(className: NimNode, fullyQualifiedName: string): NimNode {.compileTime.} =
    result = newCall("defineJNIType", className, newLit(fullyQualifiedName))

proc processJnimportNode(e: NimNode): NimNode {.compileTime.} =
    if e.kind == nnkDotExpr:
        result = generateTypeDefinition(e[1], nodeToString(e))
    elif e.kind == nnkIdent:
        result = generateTypeDefinition(e, $e)
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

