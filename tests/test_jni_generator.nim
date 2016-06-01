import private.jni_generator,
       private.jni_api,
       ./common,
       macros,
       unittest

suite "jni_generator":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()
  
  test "jni_generator - proc def - constructors":
    var pd: ProcDef
    var sig: string

    parseProcDefTest pd:
      proc new
    procSigTest sig:
      proc new
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: sig == "()V"
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: not pd.isExported

    parseProcDefTest pd:
      proc new*
    procSigTest sig:
      proc new*
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: sig == "()V"
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: pd.isExported
      
    parseProcDefTest pd:
      proc new(o: JVMObject)
    procSigTest sig:
      proc new(o: JVMObject)
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: sig == "(Ljava/lang/Object;)V"
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: not pd.isExported
      
    parseProcDefTest pd:
      proc new*(i: jint, s: string)
    procSigTest sig:
      proc new*(i: jint, s: string)
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: sig == "(ILjava/lang/String;)V"
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: pd.isExported

  test "jni_generator - proc def - methods":
    var pd: ProcDef
    var sig: string

    parseProcDefTest pd:
      proc `method`*(i: jint): jshort {.importc: "jmethod".}
    procSigTest sig:
      proc `method`*(i: jint): jshort {.importc: "jmethod".}
    check: pd.name == "method"
    check: pd.jName == "jmethod"
    check: sig == "(I)S"
    check: not pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: pd.isExported

    parseProcDefTest pd:
      proc staticMethod(i: jint): jshort {.`static`.}
    procSigTest sig:
      proc staticMethod(i: jint): jshort {.`static`.}
    check: pd.name == "staticMethod"
    check: pd.jName == "staticMethod"
    check: sig == "(I)S"
    check: not pd.isConstructor
    check: pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: not pd.isExported

  test "jni_generator - proc def - properties":
    var pd: ProcDef
    var sig: string

    parseProcDefTest pd:
      proc `out`*(): JVMObject {.prop, final, `static`.}
    procSigTest sig:
      proc `out`*(): JVMObject {.prop, final, `static`.}
    check: pd.name == "out"
    check: pd.jName == "out"
    check: sig == "()Ljava/lang/Object;"
    check: not pd.isConstructor
    check: pd.isStatic
    check: pd.isProp
    check: pd.isFinal
    check: pd.isExported

  test "jni_generator - class def - header":
    var cd: ClassDef
    
    parseClassDefTest cd:
      java.lang.String of JVMObject

    check: cd.name == "String"
    check: cd.jName == "java.lang.String"
    check: cd.parent == "JVMObject"
    check: not cd.isExported

    parseClassDefTest cd:
      java.lang.String as JVMString of JVMObject

    check: cd.name == "JVMString"
    check: cd.jName == "java.lang.String"
    check: cd.parent == "JVMObject"
    check: not cd.isExported

    parseClassDefTest cd:
      java.lang.String* of JVMObject

    check: cd.name == "String"
    check: cd.jName == "java.lang.String"
    check: cd.parent == "JVMObject"
    check: cd.isExported

    parseClassDefTest cd:
      java.lang.String as JVMString* of JVMObject

    check: cd.name == "JVMString"
    check: cd.jName == "java.lang.String"
    check: cd.parent == "JVMObject"
    check: cd.isExported

  test "jni_generator - import class":

    jclass java.lang.String of JVMObject:
      proc new
    jclass java.lang.String as JVMString of JVMObject:
      proc length: jint {.importc: "length".}
    jclass java.lang.String* of JVMObject:
      proc new
    jclass java.lang.String as JVMString* of JVMObject:
      proc length: jint {.importc: "length".}
