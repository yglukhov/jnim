public class BaseClass<T> {

    private T v;

    public BaseClass(T v) {
        this.v = v;
    }

    public T baseMethod() {
        return v;
    }
    
    public T overridedMethod() {
        return baseMethod();
    }
}
