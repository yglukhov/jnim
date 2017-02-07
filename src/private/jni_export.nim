import macros

import jni_wrapper, jni_api, jni_generator
import java.lang except Exception

type ProxyFunc = proc(env: pointer, obj: RootRef, proxiedThis, meth: jobject, args: jobjectArray): jobject {.cdecl.}

jclass java.lang.reflect.Method of JVMObject:
    proc getName(): string

proc rawHandleInvocation(env: pointer, clazz: jclass, nimRef, fnPtr: jlong, proxiedThis, meth: jobject, args: jobjectArray): jobject {.cdecl.} =
    let o = cast[RootRef](nimRef)
    let f = cast[ProxyFunc](fnPtr)
    f(env, o, proxiedThis, meth, args)

proc finalizeInvocationHandler(env: pointer, clazz: jclass, nimRef: jlong) {.cdecl.} =
    if nimRef != 0:
        let o = cast[RootRef](nimRef)
        GC_unref(o)

proc getHandlerClass(): jclass =
    checkInit
    result = theEnv.FindClass(theEnv, "io/github/vegansk/jnim/NativeInvocationHandler")
    if result.pointer.isNil:
        theEnv.ExceptionClear(theEnv)
        result = theEnv.FindClass(theEnv, "NativeInvocationHandler")
        if result.pointer.isNil:
            theEnv.ExceptionClear(theEnv)
            raise newException(Exception, "invalid jnim integration, NativeInvocationHandler not found")

    var nativeMethods: array[2, JNINativeMethod]
    nativeMethods[0].name = "i"
    nativeMethods[0].signature = "(JJLjava/lang/Object;Ljava/lang/reflect/Method;[Ljava/lang/Object;)Ljava/lang/Object;"
    nativeMethods[0].fnPtr = cast[pointer](rawHandleInvocation)
    nativeMethods[1].name = "f"
    nativeMethods[1].signature = "(J)V"
    nativeMethods[1].fnPtr = cast[pointer](finalizeInvocationHandler)

    let r = callVM theEnv.RegisterNatives(theEnv, result, addr nativeMethods[0], nativeMethods.len.jint)
    assert(r == 0)

proc makeProxy*(clazz: jclass, o: RootRef, fn: ProxyFunc): jobject =
    let handlerClazz = getHandlerClass()

    GC_ref(o)

    var mkArgs: array[3, jvalue]
    mkArgs[0].l = cast[jobject](clazz)
    mkArgs[1].j = cast[jlong](o)
    mkArgs[2].j = cast[jlong](fn)

    let mkId = callVM theEnv.GetStaticMethodID(theEnv, handlerClazz, "m", "(Ljava/lang/Class;JJ)Ljava/lang/Object;")
    assert(mkId != nil)

    result = callVM theEnv.CallStaticObjectMethodA(theEnv, handlerClazz, mkId, addr mkArgs[0])
    assert(result != nil)
    theEnv.DeleteLocalRef(theEnv, cast[jobject](handlerClazz))

template makeProxy*[T](javaInterface: typedesc, o: ref T, fn: proc(env: pointer, obj: ref T, proxiedThis, meth: jobject, args: jobjectArray): jobject {.cdecl.}): untyped =
    let clazz = javaInterface.getJVMClassForType()
    javaInterface.fromJObject(makeProxy(clazz.get(), cast[RootRef](o), cast[ProxyFunc](fn)))

################################################################################


proc getMethodName(m: jobject): string {.inline.} =
    let m = Method.fromJObject(m)
    result = m.getName()
    m.free()

proc objToStr(o: jobject): string =
    result = $o

template objToVal(typ: typedesc, valIdent: untyped, o: jobject): untyped =
    let ob = typ.fromJObject(o)
    let res = valIdent(ob)
    ob.free()
    res

proc getArg(t: typedesc, args: jobjectArray, i: int): t {.inline.} =
    let a = theEnv.GetObjectArrayElement(theEnv, args, i.jint)
    when t is jobject: a
    elif t is string: objToStr(a)
    elif t is jint: objToVal(Number, intValue, a)
    elif t is jfloat: objToVal(Number, floatValue, a)
    elif t is jdouble: objToVal(Number, doubleValue, a)
    elif t is jlong: objToVal(Number, longValue, a)
    elif t is jshort: objToVal(Number, shortValue, a)
    elif t is jbyte: objToVal(Number, byteValue, a)
    elif t is jboolean: objToVal(Boolean, booleanValue, a)
    elif t is JVMObject: t.fromJObject(a)
    else: {.error: "Dont know how to convert type".}

proc toJObject(r: JVMObject): jobject =
    result = r.get()
    r.setObj(nil) # Release the reference

proc toJObject(i: jint | jfloat | jdouble | jlong | jshort | jbyte): jobject = toWrapperType(i).toJObject()
proc toJObject(i: jboolean): jobject = toWrapperType(i).toJObject()
proc toJObject(i: string): jobject = newJVMObject(i).toJObject()

proc makeCallForProc(p: NimNode): NimNode =
    result = newCall(p.name)
    result.add(ident("obj"))
    for i in 2 ..< p.params.len:
        result.add(newCall(bindSym "getArg", p.params[i][1], ident "args", newLit(i - 2)))
    if p.params[0].kind != nnkEmpty:
        result = newAssignment(ident("result"), newCall(bindSym "toJObject", result))

proc makeDispatcherImpl(typ: NimNode, name: NimNode, body: NimNode): NimNode =
    let methid = ident("meth")
    result = newProc(name, [ident("jobject"),
        newIdentDefs(ident("env"), ident("pointer")),
        newIdentDefs(ident("obj"), typ),
        newIdentDefs(ident("proxiedThis"), ident("jobject")),
        newIdentDefs(methid, ident("jobject")),
        newIdentDefs(ident("args"), ident("jobjectArray"))])
    result.addPragma(ident("cdecl"))

    result.body = body

    let caseStmt = newNimNode(nnkCaseStmt).add(newCall(bindSym "getMethodName", methid))

    for p in body:
        caseStmt.add(newNimNode(nnkOfBranch).add(newLit($p.name), makeCallForProc(p)))

    result.body.add(caseStmt)

macro implementDispatcher*(typ: untyped, name: untyped, body: untyped): untyped =
    result = makeDispatcherImpl(typ, name, body)
