public class ChildClass<T> extends BaseClass<T> {

    private T v;

    public ChildClass(T base, T ch) {
        super(base);
        this.v = ch;
    }

    public T childMethod() {
        return v;
    }

    @Override
    public T overridedMethod() {
        return childMethod();
    }
}
