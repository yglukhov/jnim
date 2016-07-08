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

    public int readBytes(byte[] buf) {
        byte[] bs = {0, 1, 2, 3};

        int result = 0;
        for (int i = 0; i < bs.length && i < buf.length; i++) {
            buf[i] = bs[i];
            result = i + 1;
        }

        return result;
    }
}
