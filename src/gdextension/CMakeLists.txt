cmake_minimum_required(VERSION 3.22)
project(aurelion_map_persistence LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

get_property(AURELION_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT AURELION_MULTI_CONFIG AND NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

set(AURELION_PROJECT_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." CACHE PATH "Godot project root.")
set(GODOT_CPP_ROOT "${AURELION_PROJECT_ROOT}/third_party/godot-cpp" CACHE PATH "Pinned Godot 4 godot-cpp checkout.")

if(NOT EXISTS "${GODOT_CPP_ROOT}/CMakeLists.txt")
	message(FATAL_ERROR "Missing pinned godot-cpp checkout at ${GODOT_CPP_ROOT}. Run: git submodule update --init --recursive")
endif()

add_subdirectory("${GODOT_CPP_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/godot-cpp")

add_library(aurelion_map_persistence SHARED
	src/register_types.cpp
	src/map_document.cpp
	src/scenario_document.cpp
	src/map_package_service.cpp
	src/rmg_data_model.cpp
)

target_include_directories(aurelion_map_persistence PRIVATE
	include
)

target_link_libraries(aurelion_map_persistence PRIVATE godot::cpp)

target_compile_definitions(aurelion_map_persistence PRIVATE GDEXTENSION)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
	set(AURELION_GODOT_PLATFORM "linux")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows" OR WIN32)
	set(AURELION_GODOT_PLATFORM "windows")
else()
	message(FATAL_ERROR "Unsupported GDExtension target platform '${CMAKE_SYSTEM_NAME}'. Add Godot library naming rules before building this target.")
endif()

set(AURELION_GODOT_TARGET "$<IF:$<OR:$<CONFIG:Release>,$<CONFIG:MinSizeRel>>,template_release,template_debug>")

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
	OUTPUT_NAME "aurelion_map_persistence.${AURELION_GODOT_PLATFORM}.${AURELION_GODOT_TARGET}.${AURELION_GODOT_ARCH}"
)

foreach(AURELION_CONFIG DEBUG RELEASE RELWITHDEBINFO MINSIZEREL)
	set_target_properties(aurelion_map_persistence PROPERTIES
		LIBRARY_OUTPUT_DIRECTORY_${AURELION_CONFIG} "${AURELION_BIN_OUTPUT_DIR}"
		RUNTIME_OUTPUT_DIRECTORY_${AURELION_CONFIG} "${AURELION_BIN_OUTPUT_DIR}"
		ARCHIVE_OUTPUT_DIRECTORY_${AURELION_CONFIG} "${AURELION_BIN_OUTPUT_DIR}"
	)
endforeach()
