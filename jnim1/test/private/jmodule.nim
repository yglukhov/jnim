import "../../jnim"

jnimportEx:
  import TestSyntax
  import TestSyntax as JTestSyntax
  
  import java.lang.String as JString

  proc `$`(o: JString): string {.importc: "toString".}

  proc new(s: typedesc[TestSyntax])
  proc say(o: TestSyntax): string

  proc new(s: typedesc[JTestSyntax])
  proc jsay(o: JTestSyntax): JString {.importc: "say".}
