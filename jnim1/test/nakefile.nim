
import nake
import os

task defaultTask, "Run tests":
    for javaFile in walkFiles "*.java":
        direShell "javac", javaFile

    for nimFile in walkFiles "*.nim":
        if nimFile != "nakefile.nim":
            echo "Running: ", nimFile
            direShell nimExe, "c", "--run", nimFile

