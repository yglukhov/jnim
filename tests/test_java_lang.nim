import jnim,
       java.lang,
       common,
       unittest,
       encodings

suite "javaapi.core":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()

  test "java.lang.Object":
    let o1 = Object.new
    let o2 = Object.new
    check: not o1.toString.equals(o2.toString)
    check: not o1.equals(o2)
    check: o1.getClass.equals(o2.getClass)

  test "java.lang.String":
    let s1 = String.new("Hi")
    let s2 = String.new("Hi")
    let s3 = String.new("Hello")
    # Check inheritance
    check: s1 of String
    check: s1 of Object
    # Check operations
    check: $s1 == "Hi"
    check: s1.equals(s2)
    check: not s2.equals(s3)
    let s = String.new("Привет!")
    check: String.new(s.getBytes("CP1251"), "CP1251") == s

  jclass ExceptionTestClass of Object:
    proc throwEx(msg: string) {.`static`.}

  test "java.lang.Exception":
    expect(JavaException):
      ExceptionTestClass.throwEx("test")
    try:
      ExceptionTestClass.throwEx("test")
    except JavaException:
      let ex = getCurrentJVMException()
      check: ex.getStackTrace.len == 1

  test "java.lang - Numbers":
    check: Byte.MIN_VALUE == low(int8)
    check: Byte.MAX_VALUE == high(int8)
    check: Byte.SIZE == 8
    check: $Byte.TYPE == "byte"
    check: Byte.new(100).byteValue == Byte.new("100").byteValue
    expect JavaException:
      discard Byte.new("1000")
    check: Short.MIN_VALUE == low(int16)
    check: Short.MAX_VALUE == high(int16)

    check: Integer.new(1) == Integer.new(1)
