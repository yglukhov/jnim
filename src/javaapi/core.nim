import jbridge

# Forward declarations
jclassDef java.lang.Object* of JVMObject
jclassDef java.lang.Class* of Object
jclassDef java.lang.String* of Object

jclassImpl java.lang.Object* of JVMObject:
  proc jnew*
  proc equals*(o: Object): bool
  proc getClass*: Class
  proc hashCode*: jint
  proc notify*
  proc notifyAll*
  proc toString*: String
  proc wait*
  proc wait*(timeout: jlong)
  proc wait*(timeoute: jlong, nanos: jint)

proc `$`*(o: Object): string =
  o.toStringRaw

# Waiting for the https://github.com/nim-lang/Nim/issues/4267 issue
# proc `==`*(o1, o2: Object): bool =
#   o1.equals(o2)
  
jclassImpl java.lang.String* of Object:
  proc jnew*
  proc jnew*(s: string)
  proc length*: jint

#################################################################################################### 
# Exceptions

jclass java.lang.StackTraceElement* of Object:
  proc jnew*(declaringClass: String, methodName: String, fileName: String, lineNumber: jint)
  proc getClassName*: String
  proc getFileName*: String
  proc getLineNumber*: jint
  proc getMethodName*: String
  proc isNativeMethod*: bool

jclass java.lang.Throwable* of Object:
  proc jnew*
  proc jnew*(message: String)
  proc jnew*(message: String, cause: Throwable)
  proc jnew*(cause: Throwable)
  proc getCause*: Throwable
  proc getLocalizedMessage*: String
  proc getMessage*: String
  proc getStackTrace*: seq[StackTraceElement]
  proc printStackTrace*


proc asJVM*(ex: JavaException): Throwable =
  Throwable.fromJObject(ex.getJVMException.newRef)

proc getCurrentJVMException*: Throwable =
  ((ref JavaException)getCurrentException())[].asJVM
