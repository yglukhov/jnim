import jnim
from typetraits import name

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
  proc length*: jint

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
  proc NaN*: jfloat {.prop, `static`, final.}
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
  proc NaN*: jdouble {.prop, `static`, final.}
  proc NEGATIVE_INFINITY*: jdouble {.prop, `static`, final.}
  proc POSITIVE_INFINITY*: jdouble {.prop, `static`, final.}
  proc SIZE*: jint {.prop, `static`, final.}
  proc TYPE*: Class[Long] {.prop, `static`, final.}

  proc new*(v: jdouble)
  proc new*(s: string)

converter toValueType*(v: Double): jdouble = v.doubleValue
converter toWrapperType*(v: jdouble): Double = Double.new(v)

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


proc asJVM*(ex: JavaException): Throwable =
  Throwable.fromJObject(ex.getJVMException.newRef)

proc getCurrentJVMException*: Throwable =
  ((ref JavaException)getCurrentException())[].asJVM


#################################################################################################### 
# Operators


proc instanceOf*[T: JVMObject](obj: JVMObject, t: typedesc[T]): bool =
  ## Returns true if java object `obj` is an instance of class, represented
  ## by `T`. Behaves the same as `instanceof` operator in Java.
  ## **WARNING**: since generic parameters are not represented on JVM level,
  ## they are ignored (even though they are required by Nim syntax). This
  ## means that the following returns true:
  ## .. code-block:: nim
  ##   let a = ArrayList[Integer].new()
  ##   # true!
  ##   a.instanceOf[List[String]]

  instanceOfRaw(obj, T.getJVMClassForType)

proc jcast*[T: JVMObject](obj: JVMObject): T =
  ## Downcast operator for Java objects.
  ## Behaves like Java code `(T) obj`. That is:
  ## - If java object, referenced by `obj`, is an instance of class,
  ## represented by `T` - returns an object of `T` that references
  ## the same java object.
  ## - Otherwise raises an exception (`ObjectConversionError`).
  ## **WARNING**: since generic parameters are not represented on JVM level,
  ## they are ignored (even though they are required by Nim syntax). This
  ## means that the following won't raise an error:
  ## .. code-block:: nim
  ##   let a = ArrayList[Integer].new()
  ##   # no error here!
  ##   let b = jcast[List[String]](a)
  ## **WARNING**: To simplify reference handling, this implementation directly
  ## casts JVMObject to a subtype. This works, since all mapped classes have
  ## the same structure, but also breaks Nim's runtime type determination
  ## (such as `of` keyword and methods). However, native runtime type
  ## determination should not be used with mapped classes anyway.

  if not obj.instanceOf(T):
    raise newException(
      ObjectConversionError,
      "Failed to convert " & obj.type.name &
        " to " & typetraits.name(T)
    )
  # Since it is just a ref
  cast[T](obj)
