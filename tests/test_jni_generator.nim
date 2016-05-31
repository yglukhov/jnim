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

    parseProcDefTest pd:
      proc new
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: pd.sig == "()V"
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: not pd.isExported

    parseProcDefTest pd:
      proc new*
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: pd.sig == "()V"
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: pd.isExported
      
    parseProcDefTest pd:
      proc new(o: JVMObject)
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: pd.sig == "(Ljava/lang/Object;)V"
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: not pd.isExported
      
    parseProcDefTest pd:
      proc new*(i: jint, s: string)
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: pd.sig == "(ILjava/lang/String;)V"
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: pd.isExported

  test "jni_generator - proc def - methods":
    var pd: ProcDef

    parseProcDefTest pd:
      proc `method`*(i: jint): jshort {.importc: "jmethod".}
    check: pd.name == "method"
    check: pd.jName == "jmethod"
    check: pd.sig == "(I)S"
    check: not pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: pd.isExported

    parseProcDefTest pd:
      proc staticMethod(i: jint): jshort {.`static`.}
    check: pd.name == "staticMethod"
    check: pd.jName == "staticMethod"
    check: pd.sig == "(I)S"
    check: not pd.isConstructor
    check: pd.isStatic
    check: not pd.isProp
    check: not pd.isFinal
    check: not pd.isExported

  test "jni_generator - proc def - properties":
    var pd: ProcDef

    parseProcDefTest pd:
      proc `out`*(): JVMObject {.prop, final, `static`.}
    
    check: pd.name == "out"
    check: pd.jName == "out"
    check: pd.sig == "()Ljava/lang/Object;"
    check: not pd.isConstructor
    check: pd.isStatic
    check: pd.isProp
    check: pd.isFinal
    check: pd.isExported

  test "jni_generator - import class":

    # jclass java.lang.String* of JVMObject:
    #   proc new
      # proc new(s: String)
      # proc length*: jint
      # proc test: String {.Static, Prop.}
    
    # jclass java.lang.String as JVMString* of JVMObject:
    #   proc length: jint {.importc: "length".}

    # jclass java.util.List*[T] as JVMList of JVMObject:
    #   proc get(i: jint): T
    
    echo "Hi!"
