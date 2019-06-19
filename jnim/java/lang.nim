import ../../jnim

# Forward declarations
jclassDef java.lang.Object* of JVMObject
jclassDef java.lang.Class*[T] of Object
jclassDef java.lang.String* of Object

jclassImpl java.lang.Object* of JVMObject:
  proc new*
  proc equals*(o: Object): bool
  proc getClass*: Class[Object]
  proc hashCode*: jint
  proc notify*
  proc notifyAll*
  proc toString*: String
  proc wait*
  proc wait*(timeout: jlong)
  proc wait*(timeoute: jlong, nanos: jint)

proc `$`*(o: Object): string =
  o.toStringRaw

jclassImpl java.lang.String* of Object:
  proc new*
  proc new*(s: string)
  proc new*(chars: seq[jbyte])
  proc new*(chars: seq[jbyte], charsetName: string)
  proc length*: jint
  proc getBytes*: seq[jbyte]
  proc getBytes*(charsetName: string): seq[jbyte]

####################################################################################################
# Wrapper types

jclass java.lang.Number* of Object:
  proc byteValue*: jbyte
  proc doubleValue*: jdouble
  proc floatValue*: jfloat
  proc intValue*: jint
  proc longValue*: jlong
  proc shortValue*: jshort

jclass java.lang.Byte* of Number:
  # Static fields
  proc MAX_VALUE*: jbyte {.prop, `static`, final.}
  proc MIN_VALUE*: jbyte {.prop, `static`, final.}
  proc SIZE*: jint {.prop, `static`, final.}
  proc TYPE*: Class[Byte] {.prop, `static`, final.}

  proc new*(v: jbyte)
  proc new*(s: string)

converter toValueType*(v: Byte): jbyte = v.byteValue
converter toWrapperType*(v: jbyte): Byte = Byte.new(v)

jclass java.lang.Short* of Number:
  # Static fields
  proc MAX_VALUE*: jshort {.prop, `static`, final.}
  proc MIN_VALUE*: jshort {.prop, `static`, final.}
  proc SIZE*: jint {.prop, `static`, final.}
  proc TYPE*: Class[Short] {.prop, `static`, final.}

  proc new*(v: jshort)
  proc new*(s: string)

converter toValueType*(v: Short): jshort = v.shortValue
converter toWrapperType*(v: jshort): Short = Short.new(v)

jclass java.lang.Integer* of Number:
  # Static fields
  proc MAX_VALUE*: jint {.prop, `static`, final.}
  proc MIN_VALUE*: jint {.prop, `static`, final.}
  proc SIZE*: jint {.prop, `static`, final.}
  proc TYPE*: Class[Integer] {.prop, `static`, final.}

  proc new*(v: jint)
  proc new*(s: string)

converter toValueType*(v: Integer): jint = v.intValue
converter toWrapperType*(v: jint): Integer = Integer.new(v)

jclass java.lang.Long* of Number:
  # Static fields
  proc MAX_VALUE*: jlong {.prop, `static`, final.}
  proc MIN_VALUE*: jlong {.prop, `static`, final.}
  proc SIZE*: jint {.prop, `static`, final.}
  proc TYPE*: Class[Long] {.prop, `static`, final.}

  proc new*(v: jlong)
  proc new*(s: string)

converter toValueType*(v: Long): jlong = v.longValue
converter toWrapperType*(v: jlong): Long = Long.new(v)

jclass java.lang.Float* of Number:
  # Static fields
  proc MAX_EXPONENT*: jint {.prop, `static`, final.}
  proc MAX_VALUE*: jfloat {.prop, `static`, final.}
  proc MIN_EXPONENT*: jint {.prop, `static`, final.}
  proc MIN_NORMAL*: jfloat {.prop, `static`, final.}
  proc MIN_VALUE*: jfloat {.prop, `static`, final.}
  # proc NaN*: jfloat {.prop, `static`, final.} # Collides with system.Nan
  proc NEGATIVE_INFINITY*: jfloat {.prop, `static`, final.}
  proc POSITIVE_INFINITY*: jfloat {.prop, `static`, final.}
  proc SIZE*: jint {.prop, `static`, final.}
  proc TYPE*: Class[Long] {.prop, `static`, final.}

  proc new*(v: jfloat)
  proc new*(v: jdouble)
  proc new*(s: string)

converter toValueType*(v: Float): jfloat = v.floatValue
converter toWrapperType*(v: jfloat): Float = Float.new(v)

jclass java.lang.Double* of Number:
  # Static fields
  proc MAX_EXPONENT*: jint {.prop, `static`, final.}
  proc MAX_VALUE*: jdouble {.prop, `static`, final.}
  proc MIN_EXPONENT*: jint {.prop, `static`, final.}
  proc MIN_NORMAL*: jdouble {.prop, `static`, final.}
  proc MIN_VALUE*: jdouble {.prop, `static`, final.}
  # proc NaN*: jdouble {.prop, `static`, final.} # Collides with system.Nan
  proc NEGATIVE_INFINITY*: jdouble {.prop, `static`, final.}
  proc POSITIVE_INFINITY*: jdouble {.prop, `static`, final.}
  proc SIZE*: jint {.prop, `static`, final.}
  proc TYPE*: Class[Long] {.prop, `static`, final.}

  proc new*(v: jdouble)
  proc new*(s: string)

converter toValueType*(v: Double): jdouble = v.doubleValue
converter toWrapperType*(v: jdouble): Double = Double.new(v)

jclass java.lang.Boolean* of Object:
  # Static fields
  proc FALSE*: Boolean {.prop, `static`, final.}
  proc TRUE*: Boolean {.prop, `static`, final.}

  proc booleanValue*: jboolean

  proc new*(v: jboolean)
  proc new*(s: string)

converter toValueType*(v: Boolean): jboolean = v.booleanValue
converter toWrapperType*(v: jboolean): Boolean = Boolean.new(v)

####################################################################################################
# Exceptions

jclass java.lang.StackTraceElement* of Object:
  proc new*(declaringClass: String, methodName: String, fileName: String, lineNumber: jint)
  proc getClassName*: String
  proc getFileName*: String
  proc getLineNumber*: jint
  proc getMethodName*: String
  proc isNativeMethod*: bool

jclass java.lang.Throwable* of Object:
  proc new*
  proc new*(message: String)
  proc new*(message: String, cause: Throwable)
  proc new*(cause: Throwable)
  proc getCause*: Throwable
  proc getLocalizedMessage*: String
  proc getMessage*: String
  proc getStackTrace*: seq[StackTraceElement]
  proc printStackTrace*

jclass java.lang.Exception* of Throwable:
  proc new*
  proc new*(message: String)
  proc new*(message: String, cause: Throwable)
  proc new*(
    message: String,
    cause: Throwable,
    enableSuppression, writableStackTrace: bool)
  proc new*(cause: Throwable)

proc asJVM*(ex: JavaException): Throwable =
  Throwable.fromJObject(ex.getJVMException.get)

proc getCurrentJVMException*: Throwable =
  ((ref JavaException)getCurrentException())[].asJVM
