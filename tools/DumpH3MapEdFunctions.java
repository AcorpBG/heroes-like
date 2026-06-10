// Ghidra headless script for focused H3MapEd recovery dumps.
// @category HeroesLike

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileOptions;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSetView;
import ghidra.program.model.listing.CodeUnit;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.pcode.PcodeOp;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.util.task.ConsoleTaskMonitor;

import java.io.File;
import java.io.PrintWriter;

public class DumpH3MapEdFunctions extends GhidraScript {
    private Address parseRawAddress(String raw) {
        String value = raw.trim();
        if (value.startsWith("0x") || value.startsWith("0X")) {
            value = value.substring(2);
        }
        return toAddr(value);
    }

    private String safeName(Function function) {
        return function.getName().replaceAll("[^A-Za-z0-9_\\-]", "_");
    }

    private void dumpFunction(PrintWriter out, Function function, DecompInterface decompiler) {
        Address entry = function.getEntryPoint();
        out.println("function=" + function.getName());
        out.println("entry=" + entry);
        out.println("body=" + function.getBody());
        out.println("signature=" + function.getSignature());
        out.println();
        out.println("decompile:");
        try {
            DecompileResults results = decompiler.decompileFunction(function, 30, new ConsoleTaskMonitor());
            if (results != null && results.decompileCompleted() && results.getDecompiledFunction() != null) {
                out.println(results.getDecompiledFunction().getC());
            } else {
                out.println("<failed>");
            }
        } catch (Exception exc) {
            out.println("<exception " + exc.getClass().getSimpleName() + ": " + exc.getMessage() + ">");
        }
        out.println();
        out.println("instructions_and_pcode:");
        Listing listing = currentProgram.getListing();
        AddressSetView body = function.getBody();
        for (Instruction instruction : listing.getInstructions(body, true)) {
            out.println(instruction.getAddress() + ": " + instruction.toString());
            try {
                for (PcodeOp op : instruction.getPcode()) {
                    out.println("    " + op.toString());
                }
            } catch (Exception exc) {
                out.println("    <pcode exception " + exc.getClass().getSimpleName() + ">");
            }
        }
    }

    private void dumpReferences(PrintWriter out, Function function) {
        Address entry = function.getEntryPoint();
        out.println("function=" + function.getName());
        out.println("entry=" + entry);
        out.println();
        out.println("references_to:");
        ReferenceIterator toIter = currentProgram.getReferenceManager().getReferencesTo(entry);
        while (toIter.hasNext()) {
            Reference ref = toIter.next();
            out.println(ref.getFromAddress() + " -> " + ref.getToAddress() + " type=" + ref.getReferenceType() + " source=" + ref.getSource());
        }
        out.println();
        out.println("references_from_target_function:");
        Listing listing = currentProgram.getListing();
        for (CodeUnit unit : listing.getCodeUnits(function.getBody(), true)) {
            Reference[] refs = unit.getReferencesFrom();
            for (Reference ref : refs) {
                out.println(unit.getAddress() + " -> " + ref.getToAddress() + " type=" + ref.getReferenceType() + " source=" + ref.getSource());
            }
        }
    }

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 2) {
            println("usage: DumpH3MapEdFunctions <out-dir> <addr> [<addr> ...]");
            return;
        }
        File outDir = new File(args[0]);
        outDir.mkdirs();

        DecompInterface decompiler = new DecompInterface();
        DecompileOptions options = new DecompileOptions();
        options.grabFromProgram(currentProgram);
        decompiler.setOptions(options);
        decompiler.openProgram(currentProgram);

        PrintWriter manifest = new PrintWriter(new File(outDir, "summary.txt"), "UTF-8");
        manifest.println("schema_id=h3maped_rmg_ghidra_dump_v1");
        manifest.println("program=" + currentProgram.getName());
        manifest.println("function_count=" + (args.length - 1));

        for (int i = 1; i < args.length; i++) {
            Address address = parseRawAddress(args[i]);
            Function function = currentProgram.getFunctionManager().getFunctionAt(address);
            if (function == null) {
                function = currentProgram.getFunctionManager().getFunctionContaining(address);
            }
            if (function == null) {
                manifest.println(args[i] + "=missing_function");
                continue;
            }
            String base = "target_" + function.getEntryPoint().toString() + "_" + safeName(function);
            try (PrintWriter out = new PrintWriter(new File(outDir, base + ".txt"), "UTF-8")) {
                dumpFunction(out, function, decompiler);
            }
            try (PrintWriter out = new PrintWriter(new File(outDir, "target_" + function.getEntryPoint().toString() + "_references.txt"), "UTF-8")) {
                dumpReferences(out, function);
            }
            manifest.println(args[i] + "=" + function.getEntryPoint() + " " + function.getName());
        }
        manifest.close();
        decompiler.dispose();
    }
}
