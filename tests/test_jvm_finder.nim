import ../jnim, unittest, options

const CT_JVM = findJVM().get # findJVM should work in compile time

suite "jvm_finder":
  test "jvm_finder - Find JVM":
    echo findJVM()
    echo CT_JVM
