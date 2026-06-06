// Dump H3MapEd RMG recovery targets from a Ghidra project.
//
// Arguments:
//   1. Output directory.
//   2. Comma-separated virtual addresses, for example:
//      0x499ea3,0x49a932,0x49aa63,0x49abd6,0x4aa3e9,0x4a4c8e

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSetView;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.pcode.PcodeOp;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.program.model.symbol.ReferenceManager;
import ghidra.util.task.ConsoleTaskMonitor;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class H3MapEdRmgDump extends GhidraScript {
	private static final int DECOMPILE_TIMEOUT_SECONDS = 90;
	private static final int MAX_CALLER_FUNCTIONS = 256;

	@Override
	protected void run() throws Exception {
		String[] args = getScriptArgs();
		if (args.length < 2) {
			throw new IllegalArgumentException("usage: H3MapEdRmgDump <out_dir> <comma_addresses>");
		}

		File outDir = new File(args[0]);
		if (!outDir.exists() && !outDir.mkdirs()) {
			throw new IOException("failed to create output directory: " + outDir);
		}

		List<Address> targets = parseAddresses(args[1]);
		Listing listing = currentProgram.getListing();
		ReferenceManager referenceManager = currentProgram.getReferenceManager();

		DecompInterface decompiler = new DecompInterface();
		decompiler.openProgram(currentProgram);

		Map<String, Object> manifest = new LinkedHashMap<>();
		manifest.put("schema_id", "h3maped_rmg_ghidra_dump_v1");
		manifest.put("program", currentProgram.getName());
		manifest.put("image_base", currentProgram.getImageBase().toString());
		manifest.put("target_count", targets.size());

		Set<Function> targetFunctions = new LinkedHashSet<>();
		Set<Function> callerFunctions = new LinkedHashSet<>();
		StringBuilder summary = new StringBuilder();

		for (Address target : targets) {
			Function function = listing.getFunctionContaining(target);
			Instruction instruction = listing.getInstructionAt(target);
			summary.append("TARGET ").append(target);
			if (function != null) {
				targetFunctions.add(function);
				summary.append(" function=").append(function.getName())
					.append(" entry=").append(function.getEntryPoint());
			} else {
				summary.append(" function=<none>");
			}
			if (instruction != null) {
				summary.append(" instruction=").append(instruction);
			}
			summary.append("\n");

			writeTargetReferenceReport(outDir, target, function, referenceManager, listing, callerFunctions);
		}

		for (Function function : targetFunctions) {
			writeFunctionDump(outDir, "target", function, decompiler, listing);
		}

		int emittedCallers = 0;
		for (Function function : callerFunctions) {
			if (function == null || targetFunctions.contains(function)) {
				continue;
			}
			writeFunctionDump(outDir, "caller", function, decompiler, listing);
			emittedCallers += 1;
			if (emittedCallers >= MAX_CALLER_FUNCTIONS) {
				break;
			}
		}
		summary.append("target_functions=").append(targetFunctions.size()).append("\n");
		summary.append("caller_functions=").append(callerFunctions.size()).append("\n");
		summary.append("caller_function_dumps=").append(emittedCallers).append("\n");
		writeText(new File(outDir, "summary.txt"), summary.toString());
		writeText(new File(outDir, "manifest.json"), jsonObject(manifest) + "\n");
		decompiler.dispose();
	}

	private List<Address> parseAddresses(String raw) {
		List<Address> addresses = new ArrayList<>();
		for (String part : raw.split(",")) {
			String trimmed = part.trim();
			if (trimmed.isEmpty()) {
				continue;
			}
			addresses.add(toAddr(trimmed));
		}
		return addresses;
	}

	private void writeTargetReferenceReport(
		File outDir,
		Address target,
		Function function,
		ReferenceManager referenceManager,
		Listing listing,
		Set<Function> callerFunctions
	) throws IOException {
		StringBuilder out = new StringBuilder();
		out.append("target=").append(target).append("\n");
		out.append("target_function=").append(function == null ? "<none>" : function.getName()).append("\n");
		out.append("target_entry=").append(function == null ? "<none>" : function.getEntryPoint()).append("\n\n");
		out.append("references_to:\n");

		ReferenceIterator references = referenceManager.getReferencesTo(target);
		while (references.hasNext()) {
			Reference ref = references.next();
			Function caller = listing.getFunctionContaining(ref.getFromAddress());
			if (caller != null) {
				callerFunctions.add(caller);
			}
			Instruction instruction = listing.getInstructionAt(ref.getFromAddress());
			out.append("  from=").append(ref.getFromAddress())
				.append(" type=").append(ref.getReferenceType())
				.append(" caller=").append(caller == null ? "<none>" : caller.getName())
				.append(" caller_entry=").append(caller == null ? "<none>" : caller.getEntryPoint())
				.append(" instruction=").append(instruction == null ? "<none>" : instruction.toString())
				.append("\n");
		}

		if (function != null) {
			out.append("\nreferences_from_target_function:\n");
			AddressSetView body = function.getBody();
			for (Instruction instruction : iterable(listing.getInstructions(body, true))) {
				for (Reference ref : instruction.getReferencesFrom()) {
					out.append("  at=").append(instruction.getAddress())
						.append(" type=").append(ref.getReferenceType())
						.append(" to=").append(ref.getToAddress())
						.append(" instruction=").append(instruction)
						.append("\n");
				}
			}
		}

		writeText(new File(outDir, "target_" + target + "_references.txt"), out.toString());
	}

	private void writeFunctionDump(File outDir, String prefix, Function function, DecompInterface decompiler, Listing listing) throws IOException {
		String safeName = function.getName().replaceAll("[^A-Za-z0-9_.-]", "_");
		File outFile = new File(outDir, prefix + "_" + function.getEntryPoint() + "_" + safeName + ".txt");
		StringBuilder out = new StringBuilder();
		out.append("function=").append(function.getName()).append("\n");
		out.append("entry=").append(function.getEntryPoint()).append("\n");
		out.append("body=").append(function.getBody()).append("\n");
		out.append("signature=").append(function.getSignature()).append("\n\n");

		out.append("decompile:\n");
		DecompileResults results = decompiler.decompileFunction(function, DECOMPILE_TIMEOUT_SECONDS, new ConsoleTaskMonitor());
		if (results != null && results.decompileCompleted()) {
			out.append(results.getDecompiledFunction().getC()).append("\n");
		} else {
			out.append("<failed>");
			if (results != null) {
				out.append(" ").append(results.getErrorMessage());
			}
			out.append("\n");
		}

		out.append("\ninstructions_and_pcode:\n");
		for (Instruction instruction : iterable(listing.getInstructions(function.getBody(), true))) {
			out.append(instruction.getAddress()).append(": ").append(instruction).append("\n");
			for (PcodeOp op : instruction.getPcode()) {
				out.append("    ").append(op).append("\n");
			}
		}
		writeText(outFile, out.toString());
	}

	private Iterable<Instruction> iterable(final ghidra.program.model.listing.InstructionIterator iterator) {
		return () -> iterator;
	}

	private void writeText(File file, String text) throws IOException {
		try (BufferedWriter writer = new BufferedWriter(new FileWriter(file))) {
			writer.write(text);
		}
	}

	private String jsonObject(Map<String, Object> map) {
		StringBuilder out = new StringBuilder();
		out.append("{");
		boolean first = true;
		for (Map.Entry<String, Object> entry : map.entrySet()) {
			if (!first) {
				out.append(",");
			}
			first = false;
			out.append("\n  \"").append(escapeJson(entry.getKey())).append("\": ");
			Object value = entry.getValue();
			if (value instanceof Number || value instanceof Boolean) {
				out.append(value);
			} else {
				out.append("\"").append(escapeJson(String.valueOf(value))).append("\"");
			}
		}
		out.append("\n}");
		return out.toString();
	}

	private String escapeJson(String value) {
		return value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
	}
}
