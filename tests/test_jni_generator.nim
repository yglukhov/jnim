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
    var pd: ProcDef

    parseProcDefTest pd:
      proc new
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: pd.sig == "()V"
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isExported

    parseProcDefTest pd:
      proc new*
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: pd.sig == "()V"
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: pd.isExported
      
    parseProcDefTest pd:
      proc new(o: JVMObject)
    check: pd.name == "new"
    check: pd.jName == "<init>"
    check: pd.sig == "(Ljava/lang/Object;)V"
    check: pd.isConstructor
    check: not pd.isStatic
    check: not pd.isProp
    check: not pd.isExported
      
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
