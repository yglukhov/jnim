import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;

public class NativeInvocationHandler implements InvocationHandler {
    public static Object m(Class cl, long nimObjRef, long nimFuncPtr) {
        NativeInvocationHandler handler = new NativeInvocationHandler();
        handler.h = nimObjRef;
        handler.fp = nimFuncPtr;
        return Proxy.newProxyInstance(cl.getClassLoader(), new Class[] { cl }, handler);
    }

    public Object invoke(Object obj, Method m, Object[] args) throws Throwable {
        return i(h, fp, obj, m, args);
    }

    protected void finalize() {
        f(h);
    }

    public void d() {
        h = 0;
        fp = 0;
    }

    static native Object i(long nimObjRef, long nimFuncPtr, Object obj, Method m, Object[] args);
    static native void f(long nimObjRef);
    long h, fp;
}
