// Dump instructions and p-code over an address range from a loaded H3MapEd Ghidra program.
//
// Arguments:
//   1. Output directory.
//   2. Range start virtual address.
//   3. Range end virtual address, inclusive.
//   4. Optional comma-separated addresses to force-disassemble before dumping.

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressSet;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.pcode.PcodeOp;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

public class H3MapEdRmgRangeDump extends GhidraScript {
	@Override
	protected void run() throws Exception {
		String[] args = getScriptArgs();
		if (args.length < 3) {
			throw new IllegalArgumentException(
				"usage: H3MapEdRmgRangeDump <out_dir> <start_addr> <end_addr> [comma_disassemble_addrs]"
			);
		}

		File outDir = new File(args[0]);
		if (!outDir.exists() && !outDir.mkdirs()) {
			throw new IOException("failed to create output directory: " + outDir);
		}

		Address start = toAddr(args[1]);
		Address end = toAddr(args[2]);
		if (args.length >= 4) {
			for (String raw : args[3].split(",")) {
				String trimmed = raw.trim();
				if (!trimmed.isEmpty()) {
					disassemble(toAddr(trimmed));
				}
			}
		}

		Listing listing = currentProgram.getListing();
		AddressSet range = new AddressSet(start, end);
		StringBuilder out = new StringBuilder();
		out.append("range_start=").append(start).append("\n");
		out.append("range_end=").append(end).append("\n\n");
		out.append("instructions_and_pcode:\n");
		for (Instruction instruction : listing.getInstructions(range, true)) {
			out.append(instruction.getAddress()).append(": ").append(instruction).append("\n");
			for (PcodeOp op : instruction.getPcode()) {
				out.append("    ").append(op).append("\n");
			}
		}
		writeText(new File(outDir, "range_" + start + "_" + end + ".txt"), out.toString());
	}

	private void writeText(File file, String text) throws IOException {
		try (BufferedWriter writer = new BufferedWriter(new FileWriter(file))) {
			writer.write(text);
		}
	}
}
