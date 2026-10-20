# Finds the pinned godot-cpp checkout for the native projects under src/gdextension.
#
# A fresh clone needs `git submodule update --init --recursive`. A git worktree
# has no submodule checkout of its own, so it uses the main checkout's when that
# one holds the commit this tree pins. Pass -DGODOT_CPP_ROOT=<path> to choose one
# explicitly (the remote Linux build does, from a source archive without .git).
function(aurelion_resolve_godot_cpp_root project_root out_var)
	set(candidate "${project_root}/third_party/godot-cpp")
	if(DEFINED GODOT_CPP_ROOT AND NOT GODOT_CPP_ROOT STREQUAL "")
		set(candidate "${GODOT_CPP_ROOT}")
	endif()
	if(EXISTS "${candidate}/CMakeLists.txt")
		set(${out_var} "${candidate}" PARENT_SCOPE)
		return()
	endif()

	find_package(Git QUIET)
	if(GIT_FOUND)
		execute_process(
			COMMAND "${GIT_EXECUTABLE}" -C "${project_root}" rev-parse --path-format=absolute --git-common-dir
			OUTPUT_VARIABLE common_dir OUTPUT_STRIP_TRAILING_WHITESPACE
			RESULT_VARIABLE common_result ERROR_QUIET)
		execute_process(
			COMMAND "${GIT_EXECUTABLE}" -C "${project_root}" ls-tree HEAD third_party/godot-cpp
			OUTPUT_VARIABLE pinned_entry OUTPUT_STRIP_TRAILING_WHITESPACE
			RESULT_VARIABLE pinned_result ERROR_QUIET)
		if(common_result EQUAL 0 AND pinned_result EQUAL 0 AND pinned_entry MATCHES "commit ([0-9a-f]+)")
			set(pinned "${CMAKE_MATCH_1}")
			get_filename_component(main_root "${common_dir}" DIRECTORY)
			set(main_candidate "${main_root}/third_party/godot-cpp")
			if(EXISTS "${main_candidate}/CMakeLists.txt")
				execute_process(
					COMMAND "${GIT_EXECUTABLE}" -C "${main_candidate}" rev-parse HEAD
					OUTPUT_VARIABLE main_head OUTPUT_STRIP_TRAILING_WHITESPACE
					RESULT_VARIABLE main_result ERROR_QUIET)
				if(main_result EQUAL 0 AND main_head STREQUAL pinned)
					message(STATUS "godot-cpp: using the main checkout's ${main_candidate} (pinned ${pinned})")
					set(${out_var} "${main_candidate}" PARENT_SCOPE)
					return()
				endif()
				message(FATAL_ERROR "The main checkout's godot-cpp is at ${main_head}, this tree pins ${pinned}. Run: git submodule update --init --recursive")
			endif()
		endif()
	endif()
	message(FATAL_ERROR "Missing pinned godot-cpp checkout at ${candidate}. Run: git submodule update --init --recursive")
endfunction()
