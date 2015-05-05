public class HelloWorld {

    static int someStaticIntValue = 5;

    int intValue = 3;

    public HelloWorld() {
        System.out.println("HelloWorld default constructor called!");
    }

    public HelloWorld(int a) {
        System.out.println("HelloWorld constructor called with argument: " + Integer.toString(a));
    }

    public static void main(String[] args) {
        System.out.println("Hello, " + args[0]);
    }

    public int getIntFieldValue() {
        return intValue;
    }
}
