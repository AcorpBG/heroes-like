cmake_minimum_required(VERSION 3.22)
project(aurelion_map_persistence LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

get_property(AURELION_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT AURELION_MULTI_CONFIG AND NOT CMAKE_BUILD_TYPE)
	# The editor/debug library is what every Godot smoke and editor session
	# loads, so it is optimized by default. Pass -DCMAKE_BUILD_TYPE=Debug only
	# when stepping through the code in a debugger.
	set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type" FORCE)
endif()

# godot-cpp compiles one flavour per build tree (template_debug keeps the
# debug checks and hot-reload bookkeeping, template_release drops them).
# "auto" picks the flavour that matches the library name this tree writes:
# Release/MinSizeRel -> template_release, anything else -> template_debug.
# Multi-config generators (Visual Studio) cannot switch per --config, so use
# one build tree per flavour there and pass the flavour explicitly.
set(AURELION_GODOTCPP_TARGET "auto" CACHE STRING "godot-cpp flavour: auto, template_debug or template_release")
set_property(CACHE AURELION_GODOTCPP_TARGET PROPERTY STRINGS "auto;template_debug;template_release")
if(AURELION_GODOTCPP_TARGET STREQUAL "auto")
	if(AURELION_MULTI_CONFIG)
		set(AURELION_RESOLVED_GODOTCPP_TARGET "template_debug")
		message(STATUS "Multi-config generator: godot-cpp is built as template_debug. Configure a separate tree with -DAURELION_GODOTCPP_TARGET=template_release for the Release library.")
	elseif(CMAKE_BUILD_TYPE STREQUAL "Release" OR CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
		set(AURELION_RESOLVED_GODOTCPP_TARGET "template_release")
	else()
		set(AURELION_RESOLVED_GODOTCPP_TARGET "template_debug")
	endif()
elseif(AURELION_GODOTCPP_TARGET STREQUAL "template_debug" OR AURELION_GODOTCPP_TARGET STREQUAL "template_release")
	set(AURELION_RESOLVED_GODOTCPP_TARGET "${AURELION_GODOTCPP_TARGET}")
else()
	message(FATAL_ERROR "AURELION_GODOTCPP_TARGET must be auto, template_debug or template_release, got '${AURELION_GODOTCPP_TARGET}'.")
endif()
set(GODOTCPP_TARGET "${AURELION_RESOLVED_GODOTCPP_TARGET}" CACHE STRING "Which target to generate. valid values are: template_debug, template_release, and editor" FORCE)

set(AURELION_PROJECT_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." CACHE PATH "Godot project root.")
set(GODOT_CPP_ROOT "${AURELION_PROJECT_ROOT}/third_party/godot-cpp" CACHE PATH "Pinned Godot 4 godot-cpp checkout.")

if(NOT EXISTS "${GODOT_CPP_ROOT}/CMakeLists.txt")
	message(FATAL_ERROR "Missing pinned godot-cpp checkout at ${GODOT_CPP_ROOT}. Run: git submodule update --init --recursive")
endif()

add_subdirectory("${GODOT_CPP_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/godot-cpp")

add_library(aurelion_map_persistence SHARED
	src/register_types.cpp
	src/h3maped_rmg_core.cpp
	src/h3maped_rmg_object_catalog.cpp
	src/h3maped_rmg_template_catalog.cpp
	src/map_document.cpp
	src/scenario_document.cpp
	src/map_package_service.cpp
	src/rmg_data_model.cpp
)

add_executable(rmg_native_batch_export_cli
	src/h3maped_rmg_core.cpp
	src/h3maped_rmg_object_catalog.cpp
	src/h3maped_rmg_template_catalog.cpp
	src/rmg_native_core.cpp
	src/rmg_native_batch_export_cli.cpp
)

add_executable(h3maped_rmg_core_selftest
	src/h3maped_rmg_core.cpp
	src/h3maped_rmg_object_catalog.cpp
	src/h3maped_rmg_template_catalog.cpp
	src/h3maped_rmg_core_selftest.cpp
)

target_include_directories(aurelion_map_persistence PRIVATE
	include
)

target_include_directories(rmg_native_batch_export_cli PRIVATE
	include
)

target_include_directories(h3maped_rmg_core_selftest PRIVATE
	include
)

target_link_libraries(aurelion_map_persistence PRIVATE godot::cpp)
# Treat the godot-cpp headers as system headers so the warnings enabled below
# report this project's code, not dozens of godot-cpp lines per source file.
get_target_property(AURELION_GODOT_CPP_INCLUDES godot::cpp INTERFACE_INCLUDE_DIRECTORIES)
if(AURELION_GODOT_CPP_INCLUDES)
	target_include_directories(aurelion_map_persistence SYSTEM PRIVATE ${AURELION_GODOT_CPP_INCLUDES})
endif()

target_compile_definitions(aurelion_map_persistence PRIVATE GDEXTENSION)

foreach(AURELION_NATIVE_TARGET aurelion_map_persistence rmg_native_batch_export_cli h3maped_rmg_core_selftest)
	if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
		target_compile_options(${AURELION_NATIVE_TARGET} PRIVATE -Wall -Wextra)
	elseif(MSVC)
		target_compile_options(${AURELION_NATIVE_TARGET} PRIVATE /W4)
	endif()
endforeach()

if(WIN32)
	if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
		foreach(AURELION_NATIVE_TARGET aurelion_map_persistence rmg_native_batch_export_cli h3maped_rmg_core_selftest)
			target_compile_options(${AURELION_NATIVE_TARGET} PRIVATE -Wa,-mbig-obj)
			target_link_options(${AURELION_NATIVE_TARGET} PRIVATE -static-libgcc -static-libstdc++)
		endforeach()
	elseif(MSVC)
		foreach(AURELION_NATIVE_TARGET aurelion_map_persistence rmg_native_batch_export_cli h3maped_rmg_core_selftest)
			target_compile_options(${AURELION_NATIVE_TARGET} PRIVATE /bigobj)
		endforeach()
	endif()
	# The generator core overflows the default 1 MiB Windows main-thread stack
	# (the self-test stops with 0xC00000FD), so the standalone tools reserve the
	# 8 MiB Linux gives every process. The extension runs on Godot's threads.
	foreach(AURELION_NATIVE_TOOL rmg_native_batch_export_cli h3maped_rmg_core_selftest)
		if(MSVC)
			target_link_options(${AURELION_NATIVE_TOOL} PRIVATE /STACK:8388608)
		elseif(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
			target_link_options(${AURELION_NATIVE_TOOL} PRIVATE -Wl,--stack,8388608)
		endif()
	endforeach()
endif()

set(AURELION_OUTPUT_PREFIX "")

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
	set(AURELION_GODOT_PLATFORM "linux")
	set(AURELION_OUTPUT_PREFIX "lib")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows" OR WIN32)
	set(AURELION_GODOT_PLATFORM "windows")
	set(AURELION_OUTPUT_PREFIX "")
else()
	message(FATAL_ERROR "Unsupported GDExtension target platform '${CMAKE_SYSTEM_NAME}'. Add Godot library naming rules before building this target.")
endif()

if(NOT AURELION_GODOTCPP_TARGET STREQUAL "auto")
	# An explicit flavour names the library, whatever build type or --config
	# compiles it, so the name always matches the godot-cpp it links.
	set(AURELION_GODOT_TARGET "${AURELION_RESOLVED_GODOTCPP_TARGET}")
else()
	set(AURELION_GODOT_TARGET "$<IF:$<OR:$<CONFIG:Release>,$<CONFIG:MinSizeRel>>,template_release,template_debug>")
endif()

string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" AURELION_SYSTEM_PROCESSOR)
if(AURELION_SYSTEM_PROCESSOR STREQUAL "" AND CMAKE_SIZEOF_VOID_P EQUAL 8)
	set(AURELION_GODOT_ARCH "x86_64")
elseif(AURELION_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|x64)$")
	set(AURELION_GODOT_ARCH "x86_64")
else()
	set(AURELION_GODOT_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
endif()

set(AURELION_BIN_OUTPUT_DIR "${AURELION_PROJECT_ROOT}/bin")

set_target_properties(aurelion_map_persistence PROPERTIES
	LIBRARY_OUTPUT_DIRECTORY "${AURELION_BIN_OUTPUT_DIR}"
	RUNTIME_OUTPUT_DIRECTORY "${AURELION_BIN_OUTPUT_DIR}"
	ARCHIVE_OUTPUT_DIRECTORY "${AURELION_BIN_OUTPUT_DIR}"
	PREFIX "${AURELION_OUTPUT_PREFIX}"
	OUTPUT_NAME "aurelion_map_persistence.${AURELION_GODOT_PLATFORM}.${AURELION_GODOT_TARGET}.${AURELION_GODOT_ARCH}"
)

foreach(AURELION_CONFIG DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
	set_target_properties(aurelion_map_persistence PROPERTIES
		LIBRARY_OUTPUT_DIRECTORY_${AURELION_CONFIG} "${AURELION_BIN_OUTPUT_DIR}"
		RUNTIME_OUTPUT_DIRECTORY_${AURELION_CONFIG} "${AURELION_BIN_OUTPUT_DIR}"
		ARCHIVE_OUTPUT_DIRECTORY_${AURELION_CONFIG} "${AURELION_BIN_OUTPUT_DIR}"
	)
endforeach()

set_target_properties(rmg_native_batch_export_cli PROPERTIES
	RUNTIME_OUTPUT_DIRECTORY "${AURELION_BIN_OUTPUT_DIR}"
)

set_target_properties(h3maped_rmg_core_selftest PROPERTIES
	RUNTIME_OUTPUT_DIRECTORY "${AURELION_BIN_OUTPUT_DIR}"
)

foreach(AURELION_CONFIG DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
	set_target_properties(rmg_native_batch_export_cli PROPERTIES
		RUNTIME_OUTPUT_DIRECTORY_${AURELION_CONFIG} "${AURELION_BIN_OUTPUT_DIR}"
	)
	set_target_properties(h3maped_rmg_core_selftest PROPERTIES
		RUNTIME_OUTPUT_DIRECTORY_${AURELION_CONFIG} "${AURELION_BIN_OUTPUT_DIR}"
	)
endforeach()
