
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
proc intMethodWithStringArg(o: HelloWorld, s: string): jint {.jnimport.}

# Or like so:
jnimport:
    proc new(t: typedesc[HelloWorld], someInt: jint)

    proc println(s: PrintStream, str: string)

    # Static property:
    proc `out`(s: typedesc[System]): PrintStream {.property.}

    proc sum(h: HelloWorld, args: openarray[jint]): jint

    # Instance method
    proc getIntFieldValue(h: HelloWorld): jint

    proc `intField=`(h: HelloWorld, v: jint)
    proc intField(h: HelloWorld): jint {.property.}

    proc performThrow(h: HelloWorld)


echo "Calling first constructor..."
let hw1 = HelloWorld.new()

echo "Calling second constructor..."
let hw2 = HelloWorld.new(123)

echo "Calling static function with array of strings"
HelloWorld.main(["yglukhov"])

echo "Calling function with array of ints"
doAssert(hw2.sum([1.jint, 2, 3]) == 6)

doAssert(hw1.intMethodWithStringArg("Hello") == "Hello".len)

hw1.intField = 5
doAssert(hw1.getIntFieldValue() == 5)
doAssert(hw1.intField == 5)
hw1.intField = 8
doAssert(hw1.getIntFieldValue() == 8)
doAssert(hw1.intField == 8)

# The following mwthod should throw
var thrown = false
try:
    hw1.performThrow()
except JavaError:
    thrown = true

doAssert(thrown)

System.`out`.println("This string is printed with System.out.println().")
System.`out`.println("Done!")
