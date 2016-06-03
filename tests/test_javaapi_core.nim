import jbridge,
       javaapi.core,
       common,
       unittest

suite "javaapi.core":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()
    
  test "javaapi.core - Object":
    let o1 = Object.new
    let o2 = Object.new
    check: not o1.toString.equals(o2.toString)
    check: not o1.equals(o2)
    check: o1.toString != o2.toString
    check: o1 != o2

  test "javaapi.core - String":
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
