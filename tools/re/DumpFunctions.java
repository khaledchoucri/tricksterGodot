// Creates a function at each listed address (if none) and writes its
// decompiled C to <outdir>/<addr>.c. Args: <address list file> <outdir>
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.app.cmd.function.CreateFunctionCmd;
import ghidra.app.cmd.disassemble.DisassembleCommand;
import java.nio.file.*;
import java.util.*;

public class DumpFunctions extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        List<String> addrs = Files.readAllLines(Paths.get(args[0]));
        Path out = Paths.get(args[1]);
        DecompInterface d = new DecompInterface();
        d.openProgram(currentProgram);
        for (String s : addrs) {
            s = s.trim();
            if (s.isEmpty()) continue;
            Address a = toAddr(Long.parseLong(s.substring(2), 16));
            Function f = getFunctionAt(a);
            if (f == null) {
                new DisassembleCommand(a, null, true).applyTo(currentProgram, monitor);
                new CreateFunctionCmd(a).applyTo(currentProgram, monitor);
                f = getFunctionAt(a);
            }
            String text = "";
            if (f != null) {
                DecompileResults r = d.decompileFunction(f, 60, monitor);
                if (r != null && r.decompileCompleted()) text = r.getDecompiledFunction().getC();
            }
            Files.writeString(out.resolve(s + ".c"), text);
        }
        d.dispose();
    }
}
