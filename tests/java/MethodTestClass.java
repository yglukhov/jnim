public class MethodTestClass {

    // Static
    public static int addStatic(int x, int y) {
        return x + y;
    }

    int mem = 0;

    // Instance
    public int addToMem(int x) {
        mem += x;
        return mem;
    }

    public static MethodTestClass factory(int i) {
        MethodTestClass o = new MethodTestClass();
        o.addToMem(i);
        return o;
    }

    public String[] getStrings() {
        String[] arr = {"Hello", "world!"};
        return arr;
    }
}
