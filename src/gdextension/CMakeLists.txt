cmake_minimum_required(VERSION 3.22)
project(aurelion_map_persistence LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(GODOT_CPP_ROOT "" CACHE PATH "Path to a Godot 4 godot-cpp checkout/build.")

if(NOT GODOT_CPP_ROOT)
	message(FATAL_ERROR "Set GODOT_CPP_ROOT to a Godot 4 godot-cpp checkout before building this skeleton.")
endif()

add_library(aurelion_map_persistence SHARED
	src/register_types.cpp
	src/map_document.cpp
	src/scenario_document.cpp
	src/map_package_service.cpp
)

target_include_directories(aurelion_map_persistence PRIVATE
	include
	${GODOT_CPP_ROOT}/include
	${GODOT_CPP_ROOT}/gen/include
	${GODOT_CPP_ROOT}/gdextension
)

find_library(GODOT_CPP_LIBRARY
	NAMES godot-cpp
	PATHS ${GODOT_CPP_ROOT}/bin ${GODOT_CPP_ROOT}/lib
	NO_DEFAULT_PATH
)

if(NOT GODOT_CPP_LIBRARY)
	message(FATAL_ERROR "Could not find a built godot-cpp library under GODOT_CPP_ROOT/bin or GODOT_CPP_ROOT/lib.")
endif()

target_link_libraries(aurelion_map_persistence PRIVATE ${GODOT_CPP_LIBRARY})

target_compile_definitions(aurelion_map_persistence PRIVATE GDEXTENSION)
