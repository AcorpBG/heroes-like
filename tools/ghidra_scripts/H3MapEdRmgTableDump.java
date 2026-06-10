// Dump a small dword table from a loaded H3MapEd Ghidra program.
//
// Arguments:
//   1. Output directory.
//   2. Table virtual address, for example 0x43ae9a.
//   3. Entry count.

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.mem.Memory;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

public class H3MapEdRmgTableDump extends GhidraScript {
	@Override
	protected void run() throws Exception {
		String[] args = getScriptArgs();
		if (args.length < 3) {
			throw new IllegalArgumentException("usage: H3MapEdRmgTableDump <out_dir> <table_addr> <count>");
		}

		File outDir = new File(args[0]);
		if (!outDir.exists() && !outDir.mkdirs()) {
			throw new IOException("failed to create output directory: " + outDir);
		}

		Address table = toAddr(args[1]);
		int count = Integer.decode(args[2]);
		Memory memory = currentProgram.getMemory();
		Listing listing = currentProgram.getListing();

		StringBuilder text = new StringBuilder();
		StringBuilder json = new StringBuilder();
		text.append("table=").append(table).append("\n");
		text.append("count=").append(count).append("\n");
		json.append("{\n");
		json.append("  \"schema_id\": \"h3maped_rmg_table_dump_v1\",\n");
		json.append("  \"program\": \"").append(escapeJson(currentProgram.getName())).append("\",\n");
		json.append("  \"image_base\": \"").append(currentProgram.getImageBase()).append("\",\n");
		json.append("  \"table\": \"").append(table).append("\",\n");
		json.append("  \"count\": ").append(count).append(",\n");
		json.append("  \"entries\": [\n");

		for (int i = 0; i < count; i++) {
			Address entry = table.add((long) i * 4L);
			long value = Integer.toUnsignedLong(memory.getInt(entry));
			Address target = toAddr(value);
			Function function = listing.getFunctionContaining(target);
			Instruction instruction = listing.getInstructionAt(target);
			text.append("index=").append(i)
				.append(" entry=").append(entry)
				.append(" value=0x").append(Long.toHexString(value))
				.append(" function=").append(function == null ? "<none>" : function.getName())
				.append(" function_entry=").append(function == null ? "<none>" : function.getEntryPoint())
				.append(" instruction=").append(instruction == null ? "<none>" : instruction.toString())
				.append("\n");
			if (i > 0) {
				json.append(",\n");
			}
			json.append("    {");
			json.append("\"index\": ").append(i).append(", ");
			json.append("\"entry\": \"").append(entry).append("\", ");
			json.append("\"value\": \"0x").append(Long.toHexString(value)).append("\", ");
			json.append("\"function\": \"").append(escapeJson(function == null ? "<none>" : function.getName())).append("\", ");
			json.append("\"function_entry\": \"").append(function == null ? "<none>" : function.getEntryPoint()).append("\", ");
			json.append("\"instruction\": \"").append(escapeJson(instruction == null ? "<none>" : instruction.toString())).append("\"");
			json.append("}");
		}
		json.append("\n  ]\n}\n");

		writeText(new File(outDir, "table_" + table + ".txt"), text.toString());
		writeText(new File(outDir, "table_" + table + ".json"), json.toString());
	}

	private void writeText(File file, String text) throws IOException {
		try (BufferedWriter writer = new BufferedWriter(new FileWriter(file))) {
			writer.write(text);
		}
	}

	private String escapeJson(String value) {
		return value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
	}
}
