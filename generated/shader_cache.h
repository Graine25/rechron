#pragma once

#include <cstddef>
#include <cstdint>

struct ShaderCacheEntry {
    uint64_t hash;
    uint32_t dxilOffset;
    uint32_t dxilSize;
    uint32_t spirvOffset;
    uint32_t spirvSize;
    uint32_t specConstantsMask;
};

extern ShaderCacheEntry g_shaderCacheEntries[];
extern const size_t g_shaderCacheEntryCount;

extern const uint8_t g_compressedDxilCache[];
extern const size_t g_dxilCacheCompressedSize;
extern const size_t g_dxilCacheDecompressedSize;

extern const uint8_t g_compressedSpirvCache[];
extern const size_t g_spirvCacheCompressedSize;
extern const size_t g_spirvCacheDecompressedSize;
