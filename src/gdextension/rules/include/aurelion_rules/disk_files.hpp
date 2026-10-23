#pragma once

// The game's res:// files from a project folder on disk, for a host without
// Godot (Phase 8, P8-7): the content::Files that ContentService and the map
// package loads read through FileAccess and ResourceLoader in the game. Files
// added with add() (a package a snapshot carries) answer before the disk.

#include "aurelion_rules/content_store.hpp"

#include <string>
#include <unordered_map>

namespace aurelion::rules::content {

class DiskFiles : public Files {
public:
	// project: the folder res:// stands for. editor: OS.has_feature("editor"),
	// true for the editor binary the batches run.
	DiskFiles(std::string project, bool editor);

	// The file at path holds bytes, whatever the disk has there.
	void add(const std::string &path, std::string bytes);

	bool exists(const std::string &path) override;
	bool read(const std::string &path, std::string &bytes) override;
	// ResourceLoader.exists(path) of the editor: an imported file (its .import
	// beside it) or a resource the engine loads as it is (.tres, .tscn, .res,
	// .scn, .gd, .json).
	bool resource_exists(const std::string &path) override;
	bool editor() override { return editor_; }

private:
	// The disk path of a res:// path; false for another scheme.
	bool disk_path(const std::string &path, std::string &out) const;

	std::string project_;
	bool editor_ = true;
	std::unordered_map<std::string, std::string> added_;
};

} // namespace aurelion::rules::content
