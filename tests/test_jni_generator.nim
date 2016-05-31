import private.jni_generator,
       private.jni_api,
       ./common,
       macros,
       unittest

suite "jni_generator":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()
  
  test "jni_generator - proc def":
    const pd1 = parseProcDef("proc new".parseExpr)
    procSig pd1sig:
      proc new
    check: pd1.name == "new"
    check: pd1.jName == "<init>"
    check: pd1.isConstructor
    check: not pd1.isStatic
    check: not pd1.isProp
    check: not pd1.isExported
    check: pd1sig == "()V"

    const pd2 = parseProcDef("proc new*".parseExpr)
    procSig pd2sig:
      proc new*
    check: pd2.name == "new"
    check: pd2.jName == "<init>"
    check: pd2sig == "()V"
    check: pd2.isConstructor
    check: not pd2.isStatic
    check: not pd2.isProp
    check: pd2.isExported
      
    const pd3 = parseProcDef("proc new(o: JVMObject)".parseExpr)
    procSig pd3sig:
      proc new(o: JVMObject)
    check: pd3.name == "new"
    check: pd3.jName == "<init>"
    check: pd3sig == "(Ljava/lang/Object;)V"
    check: pd3.isConstructor
    check: not pd3.isStatic
    check: not pd3.isProp
    check: not pd3.isExported
      
  test "jni_generator - import class":

    jclass java.lang.String* of JVMObject:
      proc new
      proc new(o: JVMObject)
      # proc new(s: String)
      # proc length*: jint
      # proc test: String {.Static, Prop.}
    
    # jclass java.lang.String as JVMString* of JVMObject:
    #   proc length: jint {.importc: "length".}

    # jclass java.util.List*[T] as JVMList of JVMObject:
    #   proc get(i: jint): T
    
    echo "Hi!"
