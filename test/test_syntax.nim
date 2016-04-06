import "../jnim", private.jmodule, unittest

let jvm = newJavaVM()

suite "Syntax":
  test "Syntax - Import class":
    check: declared(TestSyntax)

  test "Syntax - Import method":
    let o = TestSyntax.new
    check: o.say == "Hello from TestSyntax"

  test "Syntax - Import class with qualified name":
    check: declared(JTestSyntax)
    
  test "Syntax - Import method with qualified name":
    let o = JTestSyntax.new
    check: o.jsay.`$` == "Hello from TestSyntax"
