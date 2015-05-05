
import "../jnim"

# Step 0. Prepare the Java environment. In this case we start a new VM.
# This implicitly sets jnim.currentEnv to the newly created environment.
let jvm = newJavaVM()

# Step 1. Import a couple of classes from Java runtime
jnimport java.lang.System

# You can also import classes in the following way:
jnimport:
    import HelloWorld
    import java.io.PrintStream

# Step 2. Import methods. Static maethods take a typedesc parameter
# as the first one.

# Constructor:
proc new(t: typedesc[HelloWorld]) {.jnimport.}

# Static method
proc main(t: typedesc[HelloWorld], args: openarray[string]) {.jnimport.}

# Instance method
proc getIntFieldValue(o: HelloWorld): jint {.jnimport.}

# Or like so:
jnimport:
    proc new(t: typedesc[HelloWorld], someInt: jint)

    proc println(s: PrintStream, str: string)

    # Static property:
    proc `.out`(s: typedesc[System]): PrintStream


echo "Calling first constructor..."
let hw1 = HelloWorld.new()

echo "Calling second constructor..."
let hw2 = HelloWorld.new(123)

echo "Calling static function with array of strings"
HelloWorld.main(["yglukhov"])

echo "Int field value is: ", hw2.getIntFieldValue()

System.`.out`().println("This string is printed with System.out.println().")
System.`.out`().println("Done!")

