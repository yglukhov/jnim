# jnim [![Build Status](https://semaphoreci.com/api/v1/projects/0d22c364-1d81-4f38-8ba9-c440e1b6cd64/611216/badge.svg)](https://semaphoreci.com/yglukhov/jnim)

Native language integration with Java VM has never been easier!
```nim
import jnim

jnimport:
    # Import a couple of classes
    import java.lang.System
    import java.io.PrintStream

    # Import static property declaration
    proc `out`(s: typedesc[System]): PrintStream {.property.}

    # Import method declaration
    proc println(s: PrintStream, str: string)

# Prepare the Java environment. In this case we start a new VM.
# Not needed if you are already in JNI context.
let jvm = newJavaVM()

# Call! :)
System.`out`.println("This string is printed with System.out.println!")
```

## Installation
```sh
nimble install jnim
```
