import java.util.List;
import java.util.ArrayList;

public class GenericsTestClass<T> {

    public T genericProp;
    
    public GenericsTestClass(T v) {
        genericProp = v;
    }

    public T getGenericValue() {
        return genericProp;
    }

    public void setGenericValue(T v) {
        genericProp = v;
    }

    public List<T> getListOfValues(int count) {
        List<T> res = new ArrayList<T>(count);
        for(int i = 0; i < count; i++) {
            res.add(genericProp);
        }

        return res;
    }
}
