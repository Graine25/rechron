
# rechron - ReXGlue Recompiled Project
#
# This file is yours to edit. 'rexglue migrate' will NOT overwrite it.
# SDK boilerplate lives in generated/rexglue.cmake.

cmake_minimum_required(VERSION 3.25)
project(rechron LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(generated/rexglue.cmake)

# Native renderer backend (Plume RHI: D3D12/Vulkan).
add_subdirectory(thirdparty/plume)

# zstd (static only) for decompressing the XenosRecomp shader cache.
set(ZSTD_BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(ZSTD_BUILD_STATIC ON CACHE BOOL "" FORCE)
set(ZSTD_BUILD_TESTS OFF CACHE BOOL "" FORCE)
add_subdirectory(thirdparty/zstd/build/cmake zstd_build)

set(RECHRON_XENOSRECOMP_DIR
    "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/XenosRecomp"
    CACHE PATH "Path to the XenosRecomp checkout used for shader tooling")

find_program(RECHRON_DXC_EXECUTABLE
    NAMES dxc dxc.exe dxc-linux dxc-macos
    HINTS
        "$ENV{DXC_DIR}/bin"
        "${RECHRON_XENOSRECOMP_DIR}/thirdparty/dxc-bin/bin/x64"
        "${RECHRON_XENOSRECOMP_DIR}/thirdparty/dxc-bin/bin/arm64"
)

if(NOT RECHRON_DXC_EXECUTABLE)
    message(FATAL_ERROR
        "DXC is required to build rechron's embedded blit shaders. "
        "Install dxc or configure with -DRECHRON_DXC_EXECUTABLE=<path-to-dxc>.")
endif()

set(RECHRON_GENERATED_SHADER_INCLUDE_DIR
    "${CMAKE_CURRENT_BINARY_DIR}/generated/include")
set(RECHRON_GENERATED_SHADER_BINARY_DIR
    "${CMAKE_CURRENT_BINARY_DIR}/generated/shaders")

function(rechron_compile_dxil_shader OUT_VAR SOURCE_FILE PROFILE ARRAY_NAME)
    get_filename_component(shader_name "${SOURCE_FILE}" NAME)
    set(dxil_output
        "${RECHRON_GENERATED_SHADER_BINARY_DIR}/${shader_name}.dxil")
    set(header_output
        "${RECHRON_GENERATED_SHADER_INCLUDE_DIR}/goliath_engine/gpu/renderer/shaders/${shader_name}.dxil.h")

    add_custom_command(
        OUTPUT "${dxil_output}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory
            "${RECHRON_GENERATED_SHADER_BINARY_DIR}"
        COMMAND "${RECHRON_DXC_EXECUTABLE}"
            -E main
            -T "${PROFILE}"
            -Fo "${dxil_output}"
            "${CMAKE_CURRENT_SOURCE_DIR}/${SOURCE_FILE}"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${SOURCE_FILE}"
        COMMENT "DXC ${SOURCE_FILE}"
        VERBATIM
    )

    add_custom_command(
        OUTPUT "${header_output}"
        COMMAND "${CMAKE_COMMAND}"
            "-DINPUT_FILE=${dxil_output}"
            "-DOUTPUT_FILE=${header_output}"
            "-DARRAY_NAME=${ARRAY_NAME}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/EmbedBinaryHeader.cmake"
        DEPENDS
            "${dxil_output}"
            "${CMAKE_CURRENT_SOURCE_DIR}/cmake/EmbedBinaryHeader.cmake"
        COMMENT "Embedding ${shader_name}.dxil"
        VERBATIM
    )

    set_source_files_properties("${header_output}" PROPERTIES GENERATED TRUE)
    set(${OUT_VAR} ${${OUT_VAR}} "${header_output}" PARENT_SCOPE)
endfunction()

set(RECHRON_BLIT_SHADER_HEADERS)
rechron_compile_dxil_shader(RECHRON_BLIT_SHADER_HEADERS
    src/goliath_engine/gpu/renderer/shaders/copy_vs.hlsl vs_6_0 g_copy_vs_dxil)
rechron_compile_dxil_shader(RECHRON_BLIT_SHADER_HEADERS
    src/goliath_engine/gpu/renderer/shaders/copy_ps.hlsl ps_6_0 g_copy_ps_dxil)

add_custom_target(rechron_blit_shaders
    DEPENDS ${RECHRON_BLIT_SHADER_HEADERS})

# Sources
set(RECHRON_SOURCES
    src/main.cpp
    src/goliath_engine/common/misc.cpp
    # Native renderer (hooks guest D3DDevice_* -> Plume).
    src/goliath_engine/gpu/renderer/video.cpp
    src/goliath_engine/gpu/renderer/d3d_hooks.cpp
    src/goliath_engine/gpu/renderer/d3d_resource_hooks.cpp
    src/goliath_engine/gpu/renderer/pipeline.cpp
    src/goliath_engine/gpu/renderer/render_state.cpp
    # XenosRecomp-translated shader cache (DXIL/SPIRV blobs + entry table).
    generated/shader_cache.cpp
)

if(WIN32)
    add_executable(rechron WIN32 ${RECHRON_SOURCES})
else()
    add_executable(rechron ${RECHRON_SOURCES})
endif()

rexglue_setup_target(rechron)
add_dependencies(rechron rechron_blit_shaders)
target_sources(rechron PRIVATE ${RECHRON_BLIT_SHADER_HEADERS})
target_include_directories(rechron BEFORE PRIVATE
    "${RECHRON_GENERATED_SHADER_INCLUDE_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/goliath_engine/gpu/renderer"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${CMAKE_CURRENT_SOURCE_DIR}/generated")

# Link the native renderer backend. Plume exposes its headers as PUBLIC, so the
# include path for <plume_render_interface.h> propagates to rechron sources.
target_link_libraries(rechron PRIVATE plume)
if(WIN32)
    target_link_libraries(rechron PRIVATE d3d12 dxgi)
    target_compile_definitions(rechron PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
    target_include_directories(rechron PRIVATE "${REXSDK_DIR}/thirdparty/dxc/include")
    add_custom_command(TARGET rechron POST_BUILD
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${RECHRON_XENOSRECOMP_DIR}/thirdparty/dxc-bin/bin/x64/dxcompiler.dll"
            "${RECHRON_XENOSRECOMP_DIR}/thirdparty/dxc-bin/bin/x64/dxil.dll"
            $<TARGET_FILE_DIR:rechron>
        COMMAND_EXPAND_LISTS
    )
endif()

# rex/hash.h includes <xxhash.h> (header-only via XXH_INLINE_ALL) but the SDK
# does not propagate the xxHash include dir to consumers.
target_include_directories(rechron PRIVATE "${REXSDK_DIR}/thirdparty/xxHash")

# zstd: decompress the shader cache.
target_link_libraries(rechron PRIVATE libzstd_static)
target_include_directories(rechron PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/zstd/lib")
