import private.jni_api,
       unittest

suite "jni_api":
  test "API - Initialization":
    initJNI(JNIVersion.v1_6, @[])
    expect JNIException:
      initJNI(JNIVersion.v1_6, @[])
