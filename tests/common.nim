import ../jnim/private/jni_api

proc initJNIForTests* =
  initJNI(JNIVersion.v1_6, @["-Djava.class.path=build"])
  
