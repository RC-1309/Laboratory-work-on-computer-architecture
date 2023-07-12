import java.io.*;
import java.util.ArrayList;
import java.util.List;

public class Main {
    private static final int FILE_HEADER_SIZE = 0x34;
    private static final String LINE_FEED = System.lineSeparator();
    private static final int PROGRAM_HEADER_SIZE = 0x20;
    private static List<Integer> marks = new ArrayList<>();
    private static List<String> linesInText = new ArrayList<>();
    private static final int SECTION_HEADER_SIZE = 0x28;
    private static final SymbolTable symbolTable = new SymbolTable();
    private static int strtabidx;
    private static int virtualAddressOfText;
    private static final String HEADER_OF_SYMTAB = "Symbol Value          	Size Type    Bind   Vis   	Index Name";
    private static final String THREE_ARGUMENTS = "   %05x:\t%08x\t%-7s\t%s,%s,%s";
    private static final String BRANCH_FORMAT = "   %05x:\t%08x\t%-7s\t%s,%s,0x%s <%s>";
    private static final String TWO_ARGUMENTS = "   %05x:\t%08x\t%-7s\t%s,0x%s";
    private static final String JAL_FORMAT = "   %05x:\t%08x\t%-7s\t%s,0x%s <%s>";
    private static final String LOAD_STORE_JARL = "   %05x:\t%08x\t%-7s\t%s,%s(%s)";
    private static final String S_AND_L_FORMAT = "   %05x:\t%08x\t%-7s\t%s,%s(%s)";
    private static final String[] REGISTER = {
            "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
            "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
            "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
            "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
    };
    private static final List<Integer> arr = new ArrayList<>();
    private static final int MASK_OPCODE = 0x7f;
    private static final int MASK_RD = 0xf80;
    private static final int MASK_FUNC3 = 0x7000;
    private static final int MASK_RS1 = 0xf8000;
    private static final int MASK_RS2 = 0x1f00000;
    private static final int MASK_FUNC7 = 0xfe000000;
    private static final int MASK_imm20 = 0xfffff000;

    private static String getBind(int val) {
        return switch (val) {
            case 0 -> "LOCAL";
            case 1 -> "GLOBAL";
            case 2 -> "WEAK";
            case 10 -> "LOOS";
            case 12 -> "HIOS";
            case 13 -> "LOPROC";
            case 15 -> "HIPROC";
            default -> "NULL";
        };
    }

    private static String getType(int val) {
        return switch (val) {
            case 0 -> "NOTYPE";
            case 1 -> "OBJECT";
            case 2 -> "FUNC";
            case 3 -> "SECTION";
            case 4 -> "FILE";
            case 5 -> "COMMON";
            case 6 -> "TLS";
            case 10 -> "LOOS";
            case 12 -> "HIOS";
            case 13 -> "LOPROC";
            case 15 -> "HIPROC";
            default -> "NULL";
        };
    }

    private static String getVis(int val) {
        return switch (val) {
            case 0 -> "DEFAULT";
            case 1 -> "INTERNAL";
            case 2 -> "HIDDEN";
            case 3 -> "PROTECTED";
            case 4 -> "EXPORTED";
            case 5 -> "SINGLETON";
            case 6 -> "ELIMINATE";
            default -> "NULL";
        };
    }

    private static String getNdx(int val) {
        return switch (val) {
            case 0 -> "UND";
            case 0xff00 -> "LORESERVE";
            case 0xff01 -> "AFTER";
            case 0xff02 -> "AMD64_LCOMMON";
            case 0xff1f -> "HIPROC";
            case 0xff20 -> "LOOS";
            case 0xff3f -> "LOSUNW";
            case 0xfff1 -> "ABS";
            case 0xfff2 -> "COMMON";
            case 0xffff -> "XINDEX";
            default -> Integer.toString(val);
        };
    }

    private static Exception error(String message) {
        return new Exception(message);
    }

    private static boolean checkELF() {
        return arr.size() > 3 && arr.get(0) == 127 && arr.get(1) == 69 && arr.get(2) == 76 && arr.get(3) == 70;
    }

    private static int getBytes(int pos, int num) {
        int ans = 0;
        for (int i = pos + num - 1; i >= pos; i--) {
            ans <<= 8;
            ans += arr.get(i);
        }
        return ans;
    }

    private static String getName(int start) {
        StringBuilder sb = new StringBuilder();
        int pos = start;
        while (arr.get(pos) > 0) {
            sb.append((char)(int)arr.get(pos));
            pos++;
        }
        return sb.toString();
    }

    private static String getB(int a) {
        return switch (a) {
            case 0b000 -> "beq";
            case 0b001 -> "bne";
            case 0b100 -> "blt";
            case 0b101 -> "bge";
            case 0b110 -> "bltu";
            case 0b111 -> "bgeu";
            default -> "unknown_instruction";
        };
    }

    private static String getL(int a) {
        return switch (a) {
            case 0b000 -> "lb";
            case 0b001 -> "lh";
            case 0b010 -> "lw";
            case 0b100 -> "lbu";
            case 0b101 -> "lhu";
            default -> "unknown_instruction";
        };
    }

    private static String getS(int a) {
        return switch (a) {
            case 0b000 -> "sb";
            case 0b001 -> "sh";
            case 0b010 -> "sw";
            default -> "unknown_instruction";
        };
    }

    private static String getIType(int a, int b) {
        return switch (a) {
            case 0b000 -> "addi";
            case 0b010 -> "slti";
            case 0b011 -> "sltiu";
            case 0b100 -> "xori";
            case 0b110 -> "ori";
            case 0b111 -> "andi";
            case 0b001 -> "slli";
            case 0b101 -> b == 0 ? "srli" : "srai";
            default -> "unknown_instruction";
        };
    }

    private static String getStandard(int a, int b) {
        return switch (b) {
            case 0b0000000 -> switch (a) {
                case 0b000 -> "add";
                case 0b001 -> "sll";
                case 0b010 -> "slt";
                case 0b011 -> "sltu";
                case 0b100 -> "xor";
                case 0b101 -> "srl";
                case 0b110 -> "or";
                case 0b111 -> "and";
                default -> "unknown_instruction";
            };
            case 0b0100000 -> switch (a) {
                case 0b000 -> "sub";
                case 0b101 -> "sra";
                default -> "unknown_instruction";
            };
            case 0b0000001 -> switch (a) {
                case 0b000 -> "mul";
                case 0b001 -> "mulh";
                case 0b010 -> "mulhsu";
                case 0b011 -> "mulhu";
                case 0b100 -> "div";
                case 0b101 -> "divu";
                case 0b110 -> "rem";
                case 0b111 -> "remu";
                default -> "unknown_instruction";
            };
            default -> "unknown_instruction";
        };
    }

    private static int getBits(int num, int start, int end) {
        return (num >>> start) % (1 << (end - start + 1));
    }

    private static int createInts31(int size, int val) {
        int answer = 0;
        for (int i = 0; i < size; i++) {
            answer <<= 1;
            answer += val;
        }
        return answer;
    }

    private static int getImmediate(int a, char t) {
        return switch (Character.toUpperCase(t)) {
            case 'I' -> getBits(a, 20, 30) + (createInts31(21, getBits(a, 31, 31)) << 11);
            case 'S' -> getBits(a, 7, 11) + (getBits(a, 25, 30) << 5)
                    + (createInts31(21, getBits(a, 31, 31)) << 11);
            case 'B' -> (getBits(a, 8, 11) << 1) + (getBits(a, 25, 30) << 5)
                    + (getBits(a, 7, 7) << 11) + (createInts31(20, getBits(a, 31, 31)) << 12);
            case 'U' -> ((a >> 12));
            case 'J' -> (getBits(a, 21, 30) << 1) + (getBits(a, 20, 20) << 11)
                    + (getBits(a, 12, 19) << 12) + (createInts31(12, getBits(a, 31, 31)) << 20);
            default -> a;
        };
    }

    private static String parseOpcode(int command, int idx) {
        int rd_i = (command & MASK_RD) >> 7;
        String rd = REGISTER[rd_i];
        int func3 = (command & MASK_FUNC3) >> 12;
        int rs1_i = (command & MASK_RS1) >> 15;
        String rs1 = REGISTER[rs1_i];
        int rs2_i = (command & MASK_RS2) >> 20;
        String rs2 = REGISTER[rs2_i];
        int func7 = (command & MASK_FUNC7) >> 25;
        return switch (command & (MASK_OPCODE)) {
            // LUI
            case 0b0110111 -> String.format(TWO_ARGUMENTS, idx, command, "lui",
                    rd, Integer.toHexString(getImmediate(command, 'U')));
            // AUIPC
            case 0b0010111 -> String.format(TWO_ARGUMENTS, idx, command, "auipc",
                    rd, Integer.toHexString(getImmediate(command, 'U')));
            // JAL
            case 0b1101111 -> {
                int addr = idx + getImmediate(command, 'J');
                yield String.format(JAL_FORMAT, idx, command, "jal",
                        rd, Integer.toHexString(addr), symbolTable.getMark(addr));
            }
            // JALR (у константы зануляется самый младший бит в силу особенности JALR)
            case 0b1100111 -> String.format(LOAD_STORE_JARL, idx, command, "jalr",
                    rd, Integer.toHexString((getImmediate(command, 'I') >> 1) << 1), rs1);
            // BEQ, BNE, BLT, BGE, BLTU, BGEU
            case 0b1100011 -> {
                int addr = idx + getImmediate(command, 'B');
                yield String.format(BRANCH_FORMAT, idx, command, getB(func3),
                        rs1, rs2, Integer.toHexString(addr), symbolTable.getMark(addr));
            }
            // LB, LH, LW, LBU, LHU
            case 0b0000011 -> String.format(S_AND_L_FORMAT, idx, command, getL(func3),
                    rd, getImmediate(command, 'I'), rs1);
            // SB, SH, SW
            case 0b0100011 -> String.format(S_AND_L_FORMAT, idx, command, getS(func3), rs2, rd_i, rs1);
            // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
            case 0b0010011 -> {
                String name = getIType(func3, func7);
                String answer;
                if ("srai".equals(name) || "srli".equals(name) || "slli".equals(name)) {
                    answer = String.format(THREE_ARGUMENTS, idx, command, getStandard(func3, func7), rd, rs1, rs2_i);
                } else {
                    answer = String.format(THREE_ARGUMENTS, idx, command, getIType(func3, func7),
                            rd, rs1, getImmediate(command, 'I'));
                }
                yield answer;
            }
            // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
            // MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU
            case 0b0110011 -> String.format(THREE_ARGUMENTS, idx, command, getStandard(func3, func7), rd, rs1, rs2);
            // FENCE
            case 0b0001111 -> String.format("   %05x:\t%08x\t%-7s", idx, command, "unknown_instruction");
            // ECALL, EBREAK
            case 0b1110011 -> {
                String name = "ebreak";
                if ((command >> 7) == 0) {
                    name = "ecall";
                }
                yield String.format("   %05x:\t%08x\t%-7s", idx, command, name);
            }
            default -> String.format("   %05x:\t%08x\t%-7s", idx, command, "unknown_instruction");
        };
    }

    private static void parseSymTab(int start, int size) {
        int pos = 0;
        for (int i = start; i < start + size; i += 16) {
            int nameI = getBytes(i, 4);
            String name = nameI == 0 ? "" : getName(strtabidx + nameI);
            int value = getBytes(i + 4, 4);
            int size_ = getBytes(i + 8, 4);
            int info = getBytes(i + 12, 1);
            String bind = getBind(info >> 4);
            String type = getType(info & (0xf));
            String vis = getVis(getBytes(i + 13, 1) & (0x3));
            String ndx = getNdx(getBytes(i + 14, 2));
            symbolTable.add(new SymbolTableSegment(pos, value, size_, type, bind, vis, ndx, name));
            pos++;
        }
    }

    private static void parseText(int start, int size, OutputStream out) throws IOException {
        System.out.println(".text:");
        out.write((".text:" + LINE_FEED).getBytes());
        for (int i = start; i < start + size; i+=4) {
            int addr = virtualAddressOfText + i - start;
            marks.add(addr);
            linesInText.add(parseOpcode(getBytes(i, 4), addr));
        }
        for (int i = 0; i < marks.size(); i++) {
            int addr = marks.get(i);
            if (symbolTable.checkMarks(addr)) {
                out.write(LINE_FEED.getBytes());
                out.write((String.format("%08x <%s>:", addr, symbolTable.getMark(addr)) + LINE_FEED).getBytes());
                System.out.println();
                System.out.printf("%08x <%s>:%n", addr, symbolTable.getMark(addr));
            }
            String line = linesInText.get(i);
            out.write((line + LINE_FEED).getBytes());
            System.out.println(line);
        }
    }

    private static void printSymTab(OutputStream out) throws IOException {
        out.write((".symtab:" + LINE_FEED).getBytes());
        System.out.println(".symtab:");
        out.write(HEADER_OF_SYMTAB.getBytes());
        out.write(LINE_FEED.getBytes());
        List<SymbolTableSegment> symbolTableSegments = symbolTable.getSegments();
        for (SymbolTableSegment symbolTableSegment : symbolTableSegments) {
            out.write((symbolTableSegment.toString() + LINE_FEED).getBytes());
        }
        System.out.println(HEADER_OF_SYMTAB);
        symbolTable.print();
    }

    private static void parse(OutputStream out) throws Exception {
        try {
            if (arr.size() < FILE_HEADER_SIZE + PROGRAM_HEADER_SIZE) {
                throw error("File is not full");
            }
            int shstrndx = getBytes(50, 2);
            int startOfStringTableHeader = shstrndx * SECTION_HEADER_SIZE + getBytes(32, 2);
            if (startOfStringTableHeader > arr.size()) {
                throw error("File is not full");
            }
            if (!checkELF()) {
                throw error("This file is not ELF");
            }
            if (arr.get(4) != 1) {
                throw error("Our system are 32-bit");
            }
            if (arr.get(5) != 1) {
                throw error("It's not a little endian");
            }
            if (getBytes(18, 2) != 0xF3) {
                throw error("It's not a RISC-V");
            }
            int startOfStringTable = getBytes(startOfStringTableHeader + 16, 4);
            for (int i = getBytes(32, 2); i < arr.size(); i += SECTION_HEADER_SIZE) {
                String name = getName(startOfStringTable + getBytes(i, 4));
                if (name.equals(".strtab")) {
                    strtabidx = getBytes(i + 16, 4);
                    break;
                }
            }
            for (int i = getBytes(32, 2); i < arr.size(); i += SECTION_HEADER_SIZE) {
                int posInStringTable = getBytes(i, 4);
                String name = getName(startOfStringTable + posInStringTable);
                if (name.equals(".symtab")) {
                    parseSymTab(getBytes(i + 16, 4), getBytes(i + 20, 4));
                    break;
                }
            }
            for (int i = getBytes(32, 2); i < arr.size(); i += SECTION_HEADER_SIZE) {
                int posInStringTable = getBytes(i, 4);
                String name = getName(startOfStringTable + posInStringTable);
                if (name.equals(".text")) {
                    virtualAddressOfText = getBytes(i + 12, 4);
                    parseText(getBytes(i + 16, 4), getBytes(i + 20, 4), out);
                }
            }
            out.write(LINE_FEED.getBytes());
            printSymTab(out);
        } catch (Exception e) {
            throw error("Something wrong: " + e.getMessage() + " I give up");
        }
    }

    public static void main(String[] args) throws Exception {
        try (
                InputStream inputStream = new FileInputStream(args[0])
        ) {
            int byteRead = inputStream.read();
            while (byteRead != -1) {
                arr.add(byteRead);
//                System.out.println((arr.size() - 1) + ": " + (char)byteRead + ", " + byteRead);
                byteRead = inputStream.read();
            }
        } catch (IOException ex) {
            throw error("IO exception: " + ex.getMessage());
        }
        try (OutputStream outputStream = new FileOutputStream(args[1])) {
            parse(outputStream);
        } catch (IOException ex) {
            throw error("IO exception: " + ex.getMessage());
        } catch (Exception e) {
            throw error(e.getMessage());
        }
    }
}