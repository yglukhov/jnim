#!/bin/sh

echo "BUILD.sh"
env

set -ev

installNim()
{
    git clone --depth 1 "https://github.com/nim-lang/Nim" ~/nim
    cd ~/nim
    sh bootstrap.sh
    export PATH=$PWD/bin:$PATH
    cd -
}

installNimble()
{
    git clone --depth 1 "https://github.com/nim-lang/nimble.git" ~/nimble
    cd ~/nimble
    nim c -r src/nimble install
    cd -
    export PATH=$HOME/.nimble/bin:$PATH
}

installLinuxDependencies()
{
    true
}

installMacOSDependencies()
{
    true
}

installDependencies()
{
    nimble install -y
}

buildTest()
{
    cd test
    nake
    cd -
}

if [ "$(uname)" = "Linux" ]
then
    installLinuxDependencies
else
    if [ "$(uname)" = "Darwin" ]
    then
        installMacOSDependencies
    fi
fi

echo "JAVA_HOME: "
ls -R $JAVA_HOME

installNim

installNimble

installDependencies

buildTest
