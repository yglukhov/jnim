import jnim

# Import a couple of classes
jclass java.io.PrintStream of JVMObject:
  proc println(s: string)

jclass java.lang.System of JVMObject:
  proc `out`: PrintStream {.prop, final, `static`.}

# Initialize JVM
initJNI()
# Call!
System.`out`.println("This string is printed with System.out.println!")
