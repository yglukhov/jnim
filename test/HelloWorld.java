public class HelloWorld {

    static int staticIntField = 5;
    static boolean staticBoolField = false;

    int intField = 3;
    boolean boolField = true;
    String stringField = "SomeString";
    char[] charArrayField = "ABC".toCharArray();

    public static class InnerHolder {
        public static class InnerClass {
            public void innerClassMethod() {
                System.out.println("Hi! I'm inner class!");
            }
        }
    }

    public HelloWorld() {
        System.out.println("HelloWorld default constructor called!");
    }

    public HelloWorld(int a) {
        System.out.println("HelloWorld constructor called with argument: " + Integer.toString(a));
    }

    public static void main(String[] args) {
        System.out.println("Hello, " + args[0]);
    }

    public int sum(int[] args) {
        int result = 0;
        for(int i: args) {
            result += i;
        }
        return result;
    }

    public int intMethodWithStringArg(String str) {
        return str.length();
    }

    public boolean booleanMethod() {
        return boolField;
    }

    public int getIntFieldValue() {
        return intField;
    }

    public void performThrow() {
        throw new IllegalArgumentException();
    }

    public int[] getIntArray() {
        int[] arr = new int[3];
        for(int i = 0; i < 3; i++)
            arr[i] = i+1;
        return arr;
    }

    public String[] getStringArray() {
        String[] arr = new String[2];
        arr[0] = "Hello";
        arr[1] = "world!";
        return arr;
    }
}
