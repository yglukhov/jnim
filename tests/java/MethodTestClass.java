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
}
