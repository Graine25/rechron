
# rechron - ReXGlue Recompiled Project
#
# This file is yours to edit. 'rexglue migrate' will NOT overwrite it.
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(rechron LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)

# Sources
set(RECHRON_SOURCES
    src/main.cpp
    src/goliath_engine/common/misc.cpp
)

if(WIN32)
    add_executable(rechron WIN32 ${RECHRON_SOURCES})
else()
    add_executable(rechron ${RECHRON_SOURCES})
endif()

rexglue_setup_target(rechron)
