# rechron TODO

## [XenosRecomp] Int4 constant register support

**Affected shaders:** 2 out of 8,069 (currently skipped in shader cache)
- `0x355745B65E301B6C`
- `0x6BCAD8E35EE02B27`

**Root cause:**  
`RegisterSet::Int4` exists in `constant_table.h` but is never handled in
`shader_recompiler.cpp`'s constant declaration paths. When a shader receives
its integer loop count as a *runtime* uniform (via `SetVertexShaderConstantI`)
rather than a baked-in default, the variable is used but never declared — DXC
errors with `use of undeclared identifier 'i0'`.

The baked-in path *does* work: when Int4 default values are embedded in the
shader binary, `shader_recompiler.cpp:~1533` emits `int4 i0 = int4(...)` inline.
The gap is the `RegisterSet::Int4` branch in the two constant-table loops:

```
// SPIRV path (~line 1200-1290): handles Float4 + Sampler only
// DXIL cbuffer path (~line 1295-1395): handles Float4 + Sampler + Bool only
// → Int4 missing from both
```

**What needs to happen:**

1. **Decide cbuffer layout for `i` registers.**  
   Xbox 360 vertex shaders have 256 float4 slots (c0–c255) and 16 integer slots
   (i0–i15). In the rechron cbuffer layout these need to live somewhere that
   doesn't collide with float constants or the sampler descriptor block.  
   Natural choice:  
   - Vertex shader: `int4 i{n} : packoffset(c256 + n)` (after all float4 slots)  
   - Pixel shader: `int4 i{n} : packoffset(c224 + n)` (pixel float4 stops at c223)  
   - SPIRV: `vk::RawBufferLoad<int4>(g_PushConstants.VertexShaderConstants + 4096 + n*16)`
     / `... PixelShaderConstants + 3584 + n*16`

2. **Add `RegisterSet::Int4` to the SPIRV emit path** in
   `shader_recompiler.cpp` (around line 1255, after the Sampler block):
   emit a `#define {name} vk::RawBufferLoad<int4>(... + registerIndex*16)`.
   The generated HLSL uses the register index directly (`i0`, `i1`, ...) rather
   than the constant name, so the define should map the name but the *inline*
   variable declaration must still use `i{registerIndex}`.

3. **Add `RegisterSet::Int4` to the DXIL cbuffer emit path** (around line 1337,
   after the Sampler block): emit
   `int4 i{registerIndex} : packoffset(c{256+registerIndex})` (vertex) or
   `c{224+registerIndex}` (pixel) inside the VertexShaderConstants /
   PixelShaderConstants cbuffer.

4. **Wire runtime support**: the native renderer's constant-upload path
   (`SetVertexShaderConstantI` / `SetPixelShaderConstantI` hooks) must copy
   integer constants into the corresponding byte range of the cbuffer so the
   GPU sees the right loop count.

**Estimated effort:** 2–3 hours (shader recompiler changes + runtime constant
upload). Not a blocker since the 2 affected shaders are low-priority skinning
variants (they're skipped with a warning today).
