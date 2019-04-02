package io.github.yglukhov.jnim;

public class ExportTestClass {
    public interface Interface {
      public void voidMethod();
      public int intMethod();
      public String stringMethod();
      public String stringMethodWithArgs(String s, int i);
    }

    public static class Implementation implements Interface {
      public void voidMethod() { }
      public int intMethod() { return 123; }
      public String stringMethod() { return "Jnim"; }
      public String stringMethodWithArgs(String s, int i) { return s; }
    }

    public static class Tester {
      public void callVoidMethod(Interface c) {
          c.voidMethod();
      }

      public int callIntMethod(Interface c) {
          return c.intMethod();
      }

      public String callStringMethod(Interface c) {
          return c.stringMethod();
      }

      public String callStringMethodWithArgs(Interface c, String s, int i) {
          return c.stringMethodWithArgs(s, i);
      }
    }
}

