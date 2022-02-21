jnim - JNI library for Nim language [![Build Status](https://github.com/yglukhov/jnim/workflows/CI/badge.svg?branch=master)](https://github.com/yglukhov/jnim/actions?query=branch%3Amaster) [![nimble](https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble.png)](https://github.com/yglukhov/nimble-tag) 
======================================

Native language integration with Java VM has never been easier!
```nim
import jnim

# Import a couple of classes
jclass java.io.PrintStream of JVMObject:
  proc println(s: string)
jclass java.lang.System of JVMObject:
  proc `out`: PrintStream {.prop, final, `static`.}

# Call!
System.`out`.println("This string is printed with System.out.println!")
```

Overview
--------

The list of the main features:

* API splitted in two parts: low and high level.
* It supports Java inheritance and generics.

The documentation is coming soon. Now you can look the examples in the [tests](tests) directory.
For example, [tests/test_java_lang.nim](tests/test_java_lang.nim) and [tests/test_java_util.nim](tests/test_java_util.nim)
shows how to use high level API.

If you want to run the tests, use ``nimble test`` command.

## Installation
```sh
nimble install jnim
```

Thanks
-------

- The current version of the library is a complete rewrite done by @vegansk.
- Also thanks a lot to all the [contributors](https://github.com/yglukhov/jnim/graphs/contributors)
