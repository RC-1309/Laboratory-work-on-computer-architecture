import java.util.*;

public class SymbolTable {
    private final Set<Integer> functions = new TreeSet<>();
    private int counterMarks = 0;
    private final Map<Integer, String> names = new TreeMap<>();
    private final List<SymbolTableSegment> segments = new ArrayList<>();

    public SymbolTable() {
    }

    public void add(SymbolTableSegment segment) {
        segments.add(segment);
        String name = segment.getName();
        int value = segment.getValue();
        if (!name.isEmpty()) {
            names.put(value, name);
        }
        if ("FUNC".equals(segment.getType())) {
            functions.add(value);
        }
    }

    public String getMark(int addr) {
        if (!names.containsKey(addr)) {
            names.put(addr, "L" + (counterMarks++));
        }
        return names.get(addr);
    }

    public void print() {
        for (SymbolTableSegment segment : segments) {
            System.out.println(segment);
        }
    }

    public List<SymbolTableSegment> getSegments() {
        return segments;
    }

    public boolean checkMarks(int addr) {
        return names.containsKey(addr);
    }

    public boolean checkFunc(int addr) {
        return functions.contains(addr);
    }
}
