public class ConstructorTestClass {
    private String consResult = "";

    public String toString() {
        return consResult;
    }

    public ConstructorTestClass() {
        consResult = "Empty constructor called";
    }

    public ConstructorTestClass(int i) {
        consResult = "Int constructor called, " + i;
    }

    public ConstructorTestClass(String s) {
        consResult = "String constructor called, " + s;
    }

    public ConstructorTestClass(int i, double d, String s) {
        consResult = "Multiparameter constructor called, " + i + ", " + d + ", " + s;
    }

    public ConstructorTestClass(int[] ints) {
        consResult = "Int array constructor called";
        for(int i: ints) {
            consResult += ", " + i;
        }
    }

    public ConstructorTestClass(String[] strings) {
        consResult = "String array constructor called";
        for(String s: strings) {
            consResult += ", " + s;
        }
    }

    public ConstructorTestClass(ConstructorTestClass c) {
        consResult = c.consResult;
    }

    public ConstructorTestClass(ConstructorTestClass[] cc) {
        consResult = "";
        for(ConstructorTestClass c: cc) {
            consResult += c.consResult + "\n";
        }
    }
}
