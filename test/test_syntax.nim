import "../jnim", unittest

let jvm = newJavaVM()

jnimport:
  import TestSyntax
  import TestSyntax as JTestSyntax
  
  import java.lang.String as JString

  proc `$`(o: JString): string {.importc: "toString".}

  proc new(s: typedesc[TestSyntax])
  proc say(o: TestSyntax): string

  proc new(s: typedesc[JTestSyntax])
  proc jsay(o: JTestSyntax): JString {.importc: "say".}

suite "Syntax":
  test "Syntax - Import class":
    # Check if class is declared
    check: declared(TestSyntax)

  test "Syntax - Import method":
    let o = TestSyntax.new
    check: o.say == "Hello from TestSyntax"

  test "Syntax - Import class with qualified name":
    check: declared(JTestSyntax)
    
  test "Syntax - Import method with qualified name":
    let o = JTestSyntax.new
    check: o.jsay.`$` == "Hello from TestSyntax"
