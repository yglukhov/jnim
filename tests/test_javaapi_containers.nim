import jbridge,
       javaapi.containers,
       common,
       unittest

suite "javaapi.containers":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()

  test "javaapi.containers - List":
    let l = ArrayList.new[string]()
