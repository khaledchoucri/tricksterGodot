// Dumps each seed function and its callees to <depth>, skipping callees with
// more than <maxCallers> callers (engine helpers), creating functions where
// Ghidra has none. Writes <outdir>/<addr>.c and <outdir>/_tree.txt.
// Args: <seeds file> <outdir> <depth> <maxCallers>
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.app.cmd.function.CreateFunctionCmd;
import ghidra.app.cmd.disassemble.DisassembleCommand;
import java.nio.file.*;
import java.util.*;

public class DumpTree extends GhidraScript {
    DecompInterface d;
    Path out;
    Set<Address> done = new HashSet<>();
    StringBuilder tree = new StringBuilder();
    int maxCallers;

    Function fn(Address a) {
        Function f = getFunctionAt(a);
        if (f == null) {
            new DisassembleCommand(a, null, true).applyTo(currentProgram, monitor);
            new CreateFunctionCmd(a).applyTo(currentProgram, monitor);
            f = getFunctionAt(a);
        }
        return f;
    }

    void dump(Function f, int depth, String indent) throws Exception {
        if (f == null || !done.add(f.getEntryPoint())) return;
        String name = "0x" + Long.toHexString(f.getEntryPoint().getOffset());
        String text = "";
        DecompileResults r = d.decompileFunction(f, 60, monitor);
        if (r != null && r.decompileCompleted()) text = r.getDecompiledFunction().getC();
        Files.writeString(out.resolve(name + ".c"), text);
        tree.append(indent).append(name).append(" ").append(text.length()).append("\n");
        if (depth <= 0) return;
        for (Function c : f.getCalledFunctions(monitor)) {
            if (c.isThunk() || c.isExternal()) continue;
            if (c.getCallingFunctions(monitor).size() > maxCallers) continue;
            dump(c, depth - 1, indent + "  ");
        }
    }

    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        out = Paths.get(args[1]);
        int depth = Integer.parseInt(args[2]);
        maxCallers = Integer.parseInt(args[3]);
        d = new DecompInterface();
        d.openProgram(currentProgram);
        for (String line : Files.readAllLines(Paths.get(args[0]))) {
            line = line.trim();
            if (line.isEmpty()) continue;
            String[] p = line.split("\s+");
            tree.append("# ").append(p.length > 1 ? p[1] : "").append("\n");
            dump(fn(toAddr(Long.parseLong(p[0].substring(2), 16))), depth, "");
        }
        Files.writeString(out.resolve("_tree.txt"), tree.toString());
        d.dispose();
    }
}
