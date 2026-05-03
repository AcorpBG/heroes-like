cmake_minimum_required(VERSION 3.22)
project(aurelion_map_persistence LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE)
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
)

target_include_directories(aurelion_map_persistence PRIVATE
	include
)

target_link_libraries(aurelion_map_persistence PRIVATE godot::cpp)

target_compile_definitions(aurelion_map_persistence PRIVATE GDEXTENSION)

string(TOLOWER "${CMAKE_BUILD_TYPE}" AURELION_BUILD_TYPE)
if(AURELION_BUILD_TYPE STREQUAL "release" OR AURELION_BUILD_TYPE STREQUAL "minsizerel")
	set(AURELION_GODOT_TARGET "template_release")
else()
	set(AURELION_GODOT_TARGET "template_debug")
endif()

if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64|AMD64)$")
	set(AURELION_GODOT_ARCH "x86_64")
else()
	set(AURELION_GODOT_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
endif()

set_target_properties(aurelion_map_persistence PROPERTIES
	LIBRARY_OUTPUT_DIRECTORY "${AURELION_PROJECT_ROOT}/bin"
	RUNTIME_OUTPUT_DIRECTORY "${AURELION_PROJECT_ROOT}/bin"
	ARCHIVE_OUTPUT_DIRECTORY "${AURELION_PROJECT_ROOT}/bin"
	OUTPUT_NAME "aurelion_map_persistence.linux.${AURELION_GODOT_TARGET}.${AURELION_GODOT_ARCH}"
)
