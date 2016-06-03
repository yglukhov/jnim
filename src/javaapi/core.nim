import jbridge

jclassDef java.lang.Object* of JVMObject
jclassDef java.lang.String* of Object

jclassImpl java.lang.Object* of JVMObject:
  proc new*
  proc equals*(o: Object): bool
  proc toString*: String

jclassImpl java.lang.String* of Object:
  proc new*
  proc new*(s: string)

proc `$`*(o: Object): string =
  o.toStringRaw

# Waiting for the https://github.com/nim-lang/Nim/issues/4267 issue
# proc `==`*(o1, o2: Object): bool =
#   o1.equals(o2)
  
