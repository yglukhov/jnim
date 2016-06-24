import jbridge,
       javaapi.containers,
       common,
       unittest

suite "javaapi.containers":
  setup:
    if not isJNIThreadInitialized():
      initJNIForTests()

  test "javaapi.containers - List":
    let xs = ArrayList[string].new()
    discard xs.add("Hello")
    xs.add(1, "world")
    check: xs.get(0) == "Hello"
    check: xs.get(1) == "world"
    expect JavaException:
      discard xs.get(3)
    var s = newSeq[string]()
    let it = xs.toIterator
    while it.hasNext:
      s.add it.next
    check: s == @["Hello", "world"]
    discard xs.removeAll(ArrayList[string].new(["world", "!"]))
    check: xs.toSeq == @["Hello"]
