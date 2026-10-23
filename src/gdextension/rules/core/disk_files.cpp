// content::DiskFiles: res:// files from a project folder.

#include "aurelion_rules/disk_files.hpp"

#include <filesystem>
#include <fstream>
#include <iterator>
#include <system_error>

namespace aurelion::rules::content {

namespace {

bool is_regular_file(const std::string &path) {
	std::error_code error;
	return std::filesystem::is_regular_file(std::filesystem::u8path(path), error);
}

bool ends_with(const std::string &text, const char *suffix) {
	const std::string tail(suffix);
	return text.size() >= tail.size() && text.compare(text.size() - tail.size(), tail.size(), tail) == 0;
}

} // namespace

DiskFiles::DiskFiles(std::string project, bool editor) :
		project_(std::move(project)), editor_(editor) {
	while (!project_.empty() && (project_.back() == '/' || project_.back() == '\\')) {
		project_.pop_back();
	}
}

void DiskFiles::add(const std::string &path, std::string bytes) {
	added_[path] = std::move(bytes);
}

bool DiskFiles::disk_path(const std::string &path, std::string &out) const {
	static const std::string scheme = "res://";
	if (path.compare(0, scheme.size(), scheme) != 0) {
		return false;
	}
	out = project_ + "/" + path.substr(scheme.size());
	return true;
}

bool DiskFiles::exists(const std::string &path) {
	if (added_.count(path) != 0) {
		return true;
	}
	std::string disk;
	return disk_path(path, disk) && is_regular_file(disk);
}

bool DiskFiles::read(const std::string &path, std::string &bytes) {
	const auto found = added_.find(path);
	if (found != added_.end()) {
		bytes = found->second;
		return true;
	}
	std::string disk;
	if (!disk_path(path, disk)) {
		return false;
	}
	std::ifstream file(std::filesystem::u8path(disk), std::ios::binary);
	if (!file) {
		return false;
	}
	bytes.assign(std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>());
	return true;
}

bool DiskFiles::resource_exists(const std::string &path) {
	std::string disk;
	if (!disk_path(path, disk)) {
		return false;
	}
	if (is_regular_file(disk + ".import")) {
		return true;
	}
	static const char *const kLoaded[] = {".tres", ".tscn", ".res", ".scn", ".gd", ".json"};
	for (const char *extension : kLoaded) {
		if (ends_with(path, extension)) {
			return is_regular_file(disk);
		}
	}
	return false;
}

} // namespace aurelion::rules::content
