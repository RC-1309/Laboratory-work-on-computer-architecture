import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

public class SymbolTableSegment {
    private static final String SYMTAB_FORMAT = "[%4d] 0x%-13X %5d %-7s %-6s %-6s %5s %s";
    private final int symbol;
    private final int value;
    private final int size;
    private final String type;
    private final String bind;
    private final String vis;
    private final String index;
    private final String name;

    public SymbolTableSegment(int symbol, int value, int size,
                              String type, String bind, String vis,
                              String index, String name) {
        this.symbol = symbol;
        this.value = value;
        this.size = size;
        this.type = type;
        this.bind = bind;
        this.vis = vis;
        this.index = index;
        this.name = name;
    }

    public int getSymbol() {
        return symbol;
    }

    public int getValue() {
        return value;
    }

    public int getSize() {
        return size;
    }

    public String getType() {
        return type;
    }

    public String getBind() {
        return bind;
    }

    public String getVis() {
        return vis;
    }

    public String getIndex() {
        return index;
    }

    public String getName() {
        return name;
    }

    @Override
    public String toString() {
        return String.format((SYMTAB_FORMAT), symbol, value, size, type, bind, vis, index, name);
    }
}
