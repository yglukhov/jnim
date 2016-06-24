import jbridge,
       javaapi.containers,
       common,
       unittest

suite "javaapi.containers":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()
