package io.github.yglukhov.jnim;

class ExportTestClass {
    public interface OverridableInterface {
        public void voidMethod();
        public int intMethod();
        public String stringMethod();
        public String stringMethodWithArgs(String s, int i);
    }

    public void callVoidMethod(OverridableInterface c) {
        c.voidMethod();
    }

    public int callIntMethod(OverridableInterface c) {
        return c.intMethod();
    }

    public String callStringMethod(OverridableInterface c) {
        return c.stringMethod();
    }

    public String callStringMethodWithArgs(OverridableInterface c, String s, int i) {
        return c.stringMethodWithArgs(s, i);
    }
}
