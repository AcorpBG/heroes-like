// Scan H3MapEd instructions for byte/dword accesses to selected small offsets.
//
// Arguments:
//   1. Output file path.
//   2. Comma-separated offsets, for example: 0x8,0x9,0xa

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.AddressSetView;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.Listing;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.util.ArrayList;
import java.util.List;

public class H3MapEdRmgOffsetAccessScan extends GhidraScript {
	@Override
	protected void run() throws Exception {
		String[] args = getScriptArgs();
		if (args.length < 2) {
			throw new IllegalArgumentException("usage: H3MapEdRmgOffsetAccessScan <out_file> <comma_offsets>");
		}

		File outFile = new File(args[0]);
		File parent = outFile.getParentFile();
		if (parent != null && !parent.exists() && !parent.mkdirs()) {
			throw new IllegalArgumentException("failed to create output directory: " + parent);
		}

		List<String> offsets = parseOffsets(args[1]);
		Listing listing = currentProgram.getListing();
		AddressSetView memory = currentProgram.getMemory();

		try (BufferedWriter out = new BufferedWriter(new FileWriter(outFile))) {
			out.write("schema_id=h3maped_rmg_offset_access_scan_v1\n");
			out.write("program=" + currentProgram.getName() + "\n");
			out.write("offsets=" + String.join(",", offsets) + "\n\n");
			for (Instruction instruction : iterable(listing.getInstructions(memory, true))) {
				String text = instruction.toString();
				String lower = text.toLowerCase();
				String matchedOffset = matchedOffset(lower, offsets);
				if (matchedOffset == null) {
					continue;
				}
				Function function = listing.getFunctionContaining(instruction.getAddress());
				out.write(instruction.getAddress().toString());
				out.write("\toffset=");
				out.write(matchedOffset);
				out.write("\taccess=");
				out.write(classifyAccess(lower));
				out.write("\tfunction=");
				out.write(function == null ? "<none>" : function.getName());
				out.write("\tentry=");
				out.write(function == null ? "<none>" : function.getEntryPoint().toString());
				out.write("\tinstruction=");
				out.write(text);
				out.write("\n");
			}
		}
	}

	private List<String> parseOffsets(String raw) {
		List<String> offsets = new ArrayList<>();
		for (String part : raw.split(",")) {
			String trimmed = part.trim().toLowerCase();
			if (!trimmed.isEmpty()) {
				offsets.add(trimmed);
			}
		}
		return offsets;
	}

	private String matchedOffset(String instruction, List<String> offsets) {
		for (String offset : offsets) {
			String withoutPrefix = offset.startsWith("0x") ? offset.substring(2) : offset;
			if (instruction.contains(" + 0x" + withoutPrefix + "]")
				|| instruction.contains("+0x" + withoutPrefix + "]")
				|| instruction.contains(" + " + withoutPrefix + "]")
				|| instruction.contains("+" + withoutPrefix + "]")) {
				return offset.startsWith("0x") ? offset : "0x" + offset;
			}
		}
		return null;
	}

	private String classifyAccess(String instruction) {
		if (instruction.startsWith("cmp ") || instruction.startsWith("test ")) {
			return "read";
		}
		if (instruction.startsWith("mov ")) {
			int comma = instruction.indexOf(',');
			String left = comma >= 0 ? instruction.substring(0, comma) : instruction;
			if (left.contains("[")) {
				return "write";
			}
			return "read";
		}
		if (instruction.startsWith("and ")
			|| instruction.startsWith("or ")
			|| instruction.startsWith("xor ")
			|| instruction.startsWith("add ")
			|| instruction.startsWith("sub ")
			|| instruction.startsWith("inc ")
			|| instruction.startsWith("dec ")) {
			return "read_write";
		}
		return "unknown";
	}

	private Iterable<Instruction> iterable(final ghidra.program.model.listing.InstructionIterator iterator) {
		return () -> iterator;
	}
}
