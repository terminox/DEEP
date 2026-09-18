# Earth3D on Android — GLES 3.0 feasibility spike

**Week 1 of 8. Ships no code. Answers one question seven weeks before the work is due.**

Scope: can an OpenGL ES 3.0 pipeline carry `Deep/Deep/Features/GlobalPause/Earth3D/` on a
mid-range phone, and what is the shape of that port. The GLES-3.0-over-AGSL decision is
settled in `ANDROID_ROADMAP.md` and is not revisited here.

## Verdict

**Go.** Every construct in `EarthSurface.metal` and `EarthBloom.metal` has a direct GLSL ES
3.00 equivalent. There is no feature cliff: no function constants, no `half`, no argument
buffers, no compute, no MSL-only intrinsic that lacks a GLSL counterpart. The shader body is
a **two-day mechanical translation** by a careful engineer.

The risk is not translation. It is **arithmetic cost**, and it is real: as written, the
surface pass costs roughly **7 billion ALU ops per frame at 1080×2400**, against a mid-range
mobile budget of 150–350 G ops/s. That is 20–45 ms for one pass. Three changes bring it to
4–9 ms, and all three are cheap:

1. one early-out that skips the light-volume loops for rays that miss every light volume
   (biggest single win, ~4× in the feed card),
2. a cosine-domain reject in `accumulateGlow` that removes ~126 `acos` per orb pixel,
3. a scene render scale of ~0.6, delivered by `SurfaceTexture.setDefaultBufferSize()`.

Two host-level decisions differ from iOS and should be made now rather than in week 7:
**the GL surface must be hosted in a `TextureView`, not a `GLSurfaceView`** (reasons in §2.6),
and `RGBA16F` colour attachments need `GL_EXT_color_buffer_half_float`, which must be
queried rather than assumed.

## 0. What the iOS renderer actually is

Numbers the rest of this document leans on.

| Fact | Value | Source |
|---|---|---|
| Surface shader | 894 lines, one fullscreen triangle, sphere-SDF, 2 hits/ray | `Shaders/EarthSurface.metal` |
| Bloom chain | 4 passes: threshold, blur H, blur V, composite | `Shaders/EarthBloom.metal` |
| HDR intermediates | `rgba16Float`, blending off on every pass | `EarthRenderer.swift:115,143-146` |
| Bloom render height | fixed 600 px regardless of drawable | `EarthRendererTypes.swift:139` |
| Uniform payload/frame | 208 B + 2048 B + 288 B = ~2.5 KB | `EarthRenderer.swift:149-171` |
| Max glow sources | 64 | `EarthRendererTypes.swift:115` |
| Orb screen radius | 0.2209 × view **height** | `EarthRendererTypes.swift:145-150` |
| Feed card | 200 pt tall; globe unit is a 634 pt square, clipped by the card | `GlobalPauseLobbyView.swift:86`, `GlobalPauseCardView.swift:93,178-195` |
| Frame rate | 60, paused when detached from window | `EarthMetalView.swift:36-41,80` |

Two defaults decide where the cost lands, and they are not the obvious ones:

- `glowPointStyle` defaults to **`.buried`** (`EarthGlowStore.swift:109`), so steady
  participants are packed into the **orb range**, not the classic range. Every fragment on
  screen — including empty sky — runs `accumulateLightVolumes` over up to 64 sources
  (`EarthSurface.metal:585,473-499`).
- `volBackGhost` defaults to **0.25** (`EarthTuning.swift:136`), so the far-side ghost's
  second `accumulateGlow` over all 64 sources (`EarthSurface.metal:772-779`) is **live**, not
  dormant. Orb pixels pay the 64-source `acos` loop twice.

Meanwhile `volIntensity` 0.85 keeps `volumetricShell` on, but it loops only the *classic*
range (`EarthSurface.metal:636,795`), which under the `.buried` default holds nothing but
spark seats — usually zero. That pass is nearly free in practice.

## 1. MSL to GLSL ES 3.00 translation risk

### 1.1 Needs redesign (3 items, all small)

**(a) `constant GlowSourceGPU* glowSources [[buffer(1)]]` — `EarthSurface.metal:522`.**
GLSL ES 3.00 has no pointers and no SSBOs (those are ES 3.1). The array must become a
uniform block. Do **not** declare it as an array of structs — std140 struct stride is a
well-trodden driver-bug area. Declare a flat array and keep the existing byte layout:

```glsl
layout(std140) uniform GlowBlock { highp vec4 glowData[128]; };  // 2 vec4 per source
// glowData[2*i]   == positionAndIntensity
// glowData[2*i+1] == radiusPacked
```

This is byte-identical to the iOS `glowBuffers` contents, so `EarthGlowStore`'s packing
(`EarthGlowStore.swift:244-323`) ports without a layout change. Dynamic indexing of a UBO
array by a loop variable is legal in ES 3.00 (the ES 2.0 constant-index restriction is gone).

**(b) Implicit-LOD texture sample inside divergent control flow —
`EarthSurface.metal:761`.** `continentTex.sample(texSampler, exitUV)` sits inside
`if (dot(refr,refr) > 1e-4) { if (disc2 > 0.0) { … } }`. In GLSL ES, a texture function that
computes its own derivatives has **undefined results in non-uniform control flow**. Apple's
GPUs tolerate it; Mali and Adreno need not. Symptom if ignored: the back-hemisphere ghost
flickers or picks a garbage mip near the silhouette. Fix: `textureLod(continentTex, exitUV, 2.0)`
— the ghost is a deliberately blurred whisper, so a fixed coarse LOD is a *better* result and
sidesteps the dateline-seam derivative problem the front face solves explicitly at `:652-659`.

**(c) In-shader sampler state — `EarthSurface.metal:529-532`, `EarthBloom.metal:31,47`.**
`constexpr sampler(filter::linear, mip_filter::linear, s_address::repeat,
t_address::clamp_to_edge)` has no GLSL ES equivalent. Move it to texture-object state
(`GL_TEXTURE_WRAP_S = GL_REPEAT`, `GL_TEXTURE_WRAP_T = GL_CLAMP_TO_EDGE`,
`GL_TEXTURE_MIN_FILTER = GL_LINEAR_MIPMAP_LINEAR`) or to a sampler object (`glGenSamplers`,
core in ES 3.0). The wrap split is load-bearing — without `REPEAT` on S the dateline prints a
seam, as the comment at `:526-528` records. The bloom textures need a separate
`CLAMP_TO_EDGE` / `LINEAR` / no-mip configuration, which is the argument for sampler objects.

### 1.2 Mechanical, but each has a way to get it wrong

| MSL | GLSL ES 3.00 | Line | Trap |
|---|---|---|---|
| (implicit precision) | `precision highp float;` + `uniform highp sampler2D` | whole file | **Most likely silent bug.** Default fragment sampler precision in ES 3.00 is `lowp`. A `lowp sampler2D` on the `RGBA16F` bloom textures quantises HDR to ~8 bits over a tiny range — bloom bands and clips. Declare `highp` on both samplers and all geometry. |
| `float3`/`float4x4` | `vec3`/`mat4` | throughout | — |
| `float3x3(U.sphereOrientation[0].xyz, …)` | `mat3(U.sphereOrientation)` | `:557-562` | Both languages are column-major and `M[i]` is column `i` in both. `transpose()` is core in GLSL ES 3.00. Straight swap. |
| `atan2(p.x, p.z)` | `atan(p.x, p.z)` | `:178` | Same (y, x) argument order. |
| `M_PI_F` | `const float PI = 3.14159265;` | `:178-179,655-657` | No GLSL builtin. |
| `saturate(x)` | `clamp(x, 0.0, 1.0)` | `:621,638,882` | — |
| `dfdx`/`dfdy` | `dFdx`/`dFdy` | `:652-653` | Core in ES 3.00, no `OES_standard_derivatives` needed. Case change only. |
| `tex.sample(s, uv, gradient2d(dx,dy))` | `textureGrad(tex, uv, dx, dy)` | `:661-662` | Core in ES 3.00. |
| `src.get_width()` / `get_height()` | `textureSize(src, 0).x` / `.y` | `EarthBloom.metal:65,76` | Or pass texel size as a uniform — one fewer driver path. |
| `refract(I, N, eta)` | identical signature, identical TIR-returns-zero | `:745` | — |
| `constant float3 X = …` | `const vec3 X = …` | `:54-60` | — |
| `constant float W[5] = {…}` | `const float W[5] = float[5](…)` | `EarthBloom.metal:42-44` | Array-constructor syntax required. |
| `vertex_id` + local array | `gl_VertexID`, `vec2 p[3] = vec2[3](…)` | `:69-80` | Attributeless `glDrawArrays(GL_TRIANGLES,0,3)`; bind a VAO (object 0 exists in ES 3.0). |
| `[[stage_in]] in.position.xy` | `gl_FragCoord.xy` | `EarthBloom.metal:154` | `gl_FragCoord.y` is bottom-up vs Metal's top-down. Only feeds a hash dither — visually irrelevant. |
| `fragment float4 … return c;` | `layout(location=0) out vec4 fragColor;` | all | — |
| `uv.y = 1.0 - uv.y;` | **delete** | `EarthBloom.metal:33,63,74,129` | Present because Metal's texture origin is top-left. GL's is bottom-left and already agrees with NDC. Leaving it in flips the whole bloom chain. |
| structs returned from functions, `bool` members | legal as-is | `:123-128,232-235,448-454` | — |
| `static` free functions | drop the keyword | throughout | — |

### 1.3 Explicitly not a problem

- **Function constants** (`[[function_constant]]`): none in either shader. Every variant knob
  is a runtime uniform in `EarthTuningUniforms` (`Shaders/EarthTuningShared.h:13-32`). The
  hardest MSL-to-GLSL feature gap simply is not exercised here.
- **Half precision**: the shaders use `float` throughout; no `half`, no `packed_half`. The ES
  port has the *inverse* problem (must add explicit precision), not a conversion problem.
- **`simd`**: entirely CPU-side Swift. See §5.
- **Projection convention**: `perspectiveProjection` at `EarthRenderer.swift:499-511` builds
  the **OpenGL** z∈[-1,1] matrix, not Metal's [0,1] — and the shader reconstructs rays with
  ndc z of `-1.0` and `1.0` (`:535-536`). `android.opengl.Matrix.perspectiveM` produces
  exactly this matrix. Zero conversion. (It works on iOS only because there is no depth
  buffer: `depthStencilPixelFormat = .invalid`, `EarthMetalView.swift:73`.)
- **Numerical defensiveness**: the shader already guards every cancellation and NaN path it
  can hit (`max()` at `:396,432`, the `1e-4` floor at `:404`, "tMax is a finite sentinel,
  never INFINITY" at `:359-360`, "smoothstep(a,a,·) is NaN" at `:441`). Mobile drivers ship
  relaxed-precision fast math; a naive shader would break here and this one will not. The
  rebasing trick at `:353-359` — "unrebased the ~3e-5 absolute error is a visible fraction of
  a shell's thickness" — is a warning that this shader already lives at the fp32 edge:
  **every geometric value must be `highp`.** `mediump` (fp16, ~1e-3 relative) would destroy it.

## 2. The multi-pass pipeline on GLES

### 2.1 Pass-for-pass mapping

| Metal (`EarthRenderer.draw`, `:233-249`) | GLES |
|---|---|
| `encodeMainPass` into `sceneTexture` (`rgba16Float`, drawable-sized) | FBO 0, `GL_COLOR_ATTACHMENT0` = `RGBA16F` texture at scene resolution |
| `encodePostPass(threshold, scene, bloomA)` | FBO 1 (`RGBA16F`, 600 px reference height) |
| `encodePostPass(blurH, bloomA, bloomB)` | FBO 2 |
| `encodePostPass(blurV, bloomB, bloomA)` | FBO 1 again |
| `encodeCompositePass(scene + bloomA, drawable)` | default framebuffer (`glBindFramebuffer(GL_FRAMEBUFFER, 0)`) |

No depth, no stencil, no MSAA, no blending — every pipeline sets
`isBlendingEnabled = false` (`EarthRenderer.swift:116,136`). Mirror that with
`glDisable(GL_DEPTH_TEST)`, `glDisable(GL_BLEND)`, and no depth attachment at all: on a
tile-based GPU an unused depth attachment still costs tile allocation and a resolve.
Also `glDisable(GL_DITHER)` — GL enables it by default, and the shader does its own dither
at `EarthBloom.metal:153-155`.

Use **separate FBO objects** rather than re-attaching textures to one FBO. Re-attachment
triggers framebuffer revalidation on tilers, which is more expensive than the bind.

### 2.2 The HDR format — the one real extension dependency

`RGBA16F` is a required *texture* format in ES 3.0 and **is** texture-filterable, but it is
**not colour-renderable in core ES 3.0**. Attaching it to an FBO requires
`GL_EXT_color_buffer_half_float` (or `GL_EXT_color_buffer_float`, core since ES 3.2).

- This is the **only** extension the pipeline needs. Everything else — `textureGrad`,
  `textureLod`, `textureSize`, `dFdx`, `gl_VertexID`, sampler objects, UBOs,
  `glInvalidateFramebuffer`, `glFenceSync`, NPOT plus mipmaps — is core ES 3.0.
- It is very widely supported on ES-3.0 Android hardware, but **support must be established
  by both the extension string and a `glCheckFramebufferStatus` of
  `GL_FRAMEBUFFER_COMPLETE`**. Some drivers advertise and then fail, and some fail only at a
  particular size. Probe at startup with a small test attachment and cache the result.
- Half-float blending is not needed (blending is off everywhere), so `GL_EXT_float_blend` is
  irrelevant here.

**If it is absent, do not build a second HDR path.** Fall back to the week-6 2D placeholder
(§6). The alternatives are all bad: `RGB10_A2` is core-renderable but leaves alpha 2 bits,
and alpha is load-bearing (`EarthSurface.metal:882-891` — continent, rim, volumetric and
ghost all lift it, and `EarthBloom.metal:148` lifts it again). `RGBA8` with a fixed exposure
scale loses the headroom the design depends on: `emissive` deliberately exceeds 1.0 so bloom
keys off palette hue (`EarthSurface.metal:798-806`), and the hot terms at `:608-611` are
explicitly uncompressed HDR.

### 2.3 Load/store actions are not free on a tiler

The most-missed tiler rule, and it maps one-to-one:

- `loadAction = .clear` (`EarthRenderer.swift:311,327,364`) becomes `glClear` right after the bind.
- `loadAction = .dontCare` (`EarthRenderer.swift:347`, every post pass) becomes
  **`glInvalidateFramebuffer(GL_FRAMEBUFFER, 1, {GL_COLOR_ATTACHMENT0})` immediately after
  binding**, before drawing.

Skip the invalidate and the driver must assume the previous contents matter, so it *restores*
the whole attachment from DRAM into tile memory before every post pass. On a 600×270 bloom
target that is small; on the scene target it is a full read of an 8-bytes-per-pixel surface
every frame, for nothing.

### 2.4 Ping-pong

Trivial: `bloomTexA` / `bloomTexB` (`EarthRenderer.swift:302-303`) become two `RGBA16F`
textures each owned by its own FBO, and the swap is which FBO is bound and which texture is
in `GL_TEXTURE0`. Keep the **fixed 600 px reference height**
(`EarthRendererTypes.swift:131-139`) — the reasoning there (a drawable-sized bloom makes the
glow a constant number of *pixels* and pops when the card lift swaps render scale) applies
identically on Android, and matters more, because Android will also vary the scene render
scale per device class (§4).

### 2.5 The composite pass survives unchanged

Two samplers in, one `vec4` out, no blending, tonemap and dither in the shader
(`EarthBloom.metal:120-157`). The only edits are the y-flip deletion, `highp` samplers, and
`gl_FragCoord`. One parity note worth recording: the composite writes straight (not
premultiplied) colour with an independent alpha, and CoreAnimation treats the drawable as
premultiplied. It looks right because emissive is proportional to alpha by construction. HWUI
makes the same premultiplied assumption for a `TextureView` surface, so **keep the shader as
is** — "fixing" it to premultiply would move the look away from iOS.

### 2.6 Host the GL surface in a `TextureView`, not a `GLSurfaceView`

Still GLES 3.0, still an EGL context on a dedicated render thread. Only the host view changes.
`GLSurfaceView` is a `SurfaceView`: its surface is composited by SurfaceFlinger outside the
view hierarchy. Four things the iOS design does are impossible or ugly on it.

1. **Rounded-corner clipping.** The card clips an oversized globe unit
   (`GlobalPauseCardView.swift:107-108,178-195`: a 634 pt square inside a 200 pt card with
   `cornerRadius = .card`). A `SurfaceView` ignores parent clipping and outlines; it would
   poke square corners out of the rounded card.
2. **The z-order sandwich.** Halo and cradle gradients draw *behind* the orb, ripples and the
   country capsule draw *in front* (`EarthSceneView.swift:9-14`). A `SurfaceView` is either
   below the whole window (punching a transparent hole that erases the gradients *and* the
   night sky behind them) or above the whole window (burying the ripples and the capsule).
3. **The card lift.** `GlobalPauseCardView` animates the globe's frame and transform every
   frame (`:162-168,243-259`). A `SurfaceView` resize per frame means a surface reallocation
   per frame.
4. **Positional lag.** In a scrolling feed, HWUI composites a `TextureView` using the view's
   *current* transform even if the texture content is one frame old, so the globe cannot slide
   relative to its card. A `SurfaceView` — or a full-screen GL layer positioned by uniforms —
   lags the card by at least one frame during scroll and during the lift.

Costs of `TextureView`, accepted knowingly: one extra full-screen textured composite per
frame, roughly one frame of added latency on drag, and ~200 lines of EGL and render-thread
boilerplate that `GLSurfaceView` would have provided. The latency is masked by the momentum
model (`EarthInteraction.swift:256-271`); the composite cost is small next to the raymarch.

Two `TextureView` hazards to plan for:

- **Recycling in the feed.** A `LazyColumn` will detach and reattach the card. Return `false`
  from `onSurfaceTextureDestroyed` and re-attach the retained `SurfaceTexture`, and hoist the
  renderer and its EGL context above the composition — otherwise every scroll past the card
  rebuilds a GL context and recompiles a 900-line shader.
- **`isPaused = window == nil`** (`EarthMetalView.swift:36-41`) has no automatic equivalent.
  Wire the render thread to visibility and lifecycle explicitly, or the globe keeps burning
  GPU on other tabs.

### 2.7 Shader compile time

One ~900-line fragment shader with uniform-bounded loops will take several hundred
milliseconds — possibly over a second — to compile and link on a mid-range Mali or Adreno, on
the render thread, the first time Global Pause opens. Warm it at app start on a background
context, and persist `glGetProgramBinary` / `glProgramBinary` keyed on `GL_RENDERER` plus
driver version plus shader hash. (Android's EGL blob cache does much of this, but not on the
first run after install.)

If register pressure turns out to cap occupancy — plausible for a shader with this many live
values — the structural remedy is to split the surface pass and the light-volume pass into two
programs. Keep that in reserve; do not do it pre-emptively.

### 2.8 The continent texture

`Assets/earth_specular_2048.jpg`, 2048×1024 baseline JPEG, 218 KB. The shader reads **only
`.r`** (`EarthSurface.metal:661-663,761`). Upload as **`GL_R8`**, not RGBA8: 2 MB instead of
8 MB, and a third of the sampling bandwidth. `texture(...).r` on an R8 texture returns the
same value, so no shader change. `glGenerateMipmap` to match `.generateMipmaps: true`, a
linear (non-sRGB) internal format to match `.SRGB: false` (`EarthRenderer.swift:91-95`), and
anisotropy left off (Metal's sampler defaults to 1).

Do **not** flip the bitmap on upload. `MTKTextureLoader.Origin.topLeft` puts image row 0 at
v=0, and `GLUtils.texImage2D` also puts row 0 at v=0, so `sphericalUV`'s
`v = 0.5 - asin(y)/PI` — north pole at v=0, `:177-180` — already agrees on both platforms.
Flipping "to fix GL" would put Antarctica at the north pole.

Avoid ETC2/EAC compression here. The mask is consumed through hard smoothstep bands at
0.32/0.68 and 0.15/0.55 (`EarthTuning.swift:62-69`), which is exactly the input that turns
block artifacts into visibly blocky coastlines. 2 MB uncompressed is not worth that risk.

## 3. Uniform delivery

### 3.1 What replaces the triple-buffered MTLBuffer and its semaphore

iOS runs three copies of each buffer behind `DispatchSemaphore(value: 3)`
(`EarthRenderer.swift:33-40,186,251-253`) because Metal hands the CPU raw pointers into memory
the GPU may still be reading. **GL does not have that problem**: `glBufferSubData` is specified
to behave as if the data were copied at call time, and the driver either renames the buffer or
synchronises internally.

Recommendation: **one UBO per block, orphan-then-write each frame** — bind the buffer, call
`glBufferData` with a null pointer and the same size to orphan it, then `glBufferSubData` the
new contents.

Total per-frame payload is ~2.5 KB across three blocks (208 + 2048 + 288 bytes). At that size
the `glBufferSubData` cost is noise — well under 10 microseconds — and is not worth optimising
before it is measured. Do not skip the orphan: without it, a driver that chooses to
synchronise rather than rename will stall the render thread on the previous frame's GPU work,
reproducing exactly the bubble the iOS semaphore exists to avoid.

If profiling ever shows that stall, the exact analogue of the iOS design is available in core
ES 3.0: a ring of three buffers — or one triple-sized buffer with `glBindBufferRange` offsets,
respecting `GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT`, which can be as coarse as 256 — plus
`glFenceSync` and `glClientWaitSync` in place of the semaphore. Build it only on evidence.

### 3.2 Block layout

Three `layout(std140)` blocks, mirroring the three Metal buffer bindings.

| Block | Binding | Size | Metal source |
|---|---|---|---|
| `EarthUniforms` | 0 | 208 B (`mat4`, `vec4`, `mat4`, 4 x `vec4`) | `EarthRendererTypes.swift:28-42` |
| `GlowBlock` | 1 | 2048 B (`vec4 glowData[128]`) | `EarthRendererTypes.swift:23-26` |
| `EarthTuning` | 2 | 288 B (18 x `vec4`) | `Shaders/EarthTuningShared.h:13-32` |

All three are **already byte-identical to std140**, because every member is a `vec4` or a
`mat4` whose columns are `vec4`-aligned in both languages. The `assert(tuningLen == 288)`
tripwire at `EarthRenderer.swift:156` transfers directly as a Kotlin check on the ByteBuffer
size, and is worth keeping — it is the thing that catches drift between the Kotlin packer and
the GLSL block.

The bloom passes bind only the tuning block (`EarthRenderer.swift:351,374` bind it at fragment
buffer 0). One `glUniformBlockBinding` per program, done once at link time.

### 3.3 The glow-source ceiling

- **Spec floor:** `GL_MAX_UNIFORM_BLOCK_SIZE` is at least 16 384 bytes in ES 3.0, so
  **512 sources** at 32 bytes each. Adreno typically reports 64 KB; Mali often exactly 16 KB.
  Design to 16 KB.
- **Current need:** 64 (`EarthRendererConstants.maxGlowSources`). The block is 12.5 % full.
- **So the UBO is not the ceiling.** The ceiling is the per-fragment loop (§4). 64 is already
  near the practical arithmetic limit on a mid-range GPU; there is no reason to raise it and
  every reason not to.
- `GL_MAX_FRAGMENT_UNIFORM_BLOCKS` is at least 12 and `GL_MAX_UNIFORM_BUFFER_BINDINGS` at
  least 24 in ES 3.0 — three blocks sits far inside both.

**Do not put the glow array in the default uniform block.** `GL_MAX_FRAGMENT_UNIFORM_VECTORS`
has a spec minimum of **224 vectors**; a plain `uniform vec4 glow[128]` plus everything else
would exceed it on conformant hardware. UBO, not loose uniforms.

## 4. Frame budget

### 4.1 Method and assumptions

Counting ALU operations per fragment, weighting transcendentals (`acos`, `exp`, `atan`) at
roughly 8-12 ops each, which is what they cost as polynomial expansions on Adreno and Mali.
"Mid-range" is taken as an Adreno 619/710 or Mali-G57 MC2 class part: **150-350 G fp32 ops/s**
and **10-14 GB/s** of memory bandwidth. Because Global Pause runs a ten-minute meditation, the
target is not 16.6 ms but **6-8 ms of GPU per frame**, so the part does not throttle halfway
through a session.

Per-fragment costs, derived from the shader as written:

| Path | Ops | Where |
|---|---|---|
| Ray reconstruction + both sphere intersections | ~40 | `:535-566` |
| `accumulateLightVolumes` orb range, per **rejected** source | ~28 | `:473-499` (sigma, elevation, centre, then `orbCoreHalo`'s two dots and the `b2` test at `:370-376`) |
| `accumulateGlow`, per source | ~20 | `:246-261` — dot, **`acos`**, divide, compare, *before* the `x > 7.5` reject at `:254` |
| Surface shading (texture, bands, iridescence, three fresnels, refraction, emissive sum) | ~150 | `:645-891` |

So, with the shipped defaults (64 sources, `.buried` style, `volBackGhost` 0.25):

- **sky fragment** = 40 + 64x28 = **~1830 ops**
- **orb fragment** = 40 + 1830 + 2x(64x20) + 150 = **~4580 ops**

The orb fragment pays the 64-source `acos` loop **twice** — once for the surface at `:706`,
once for the far-side ghost at `:773`.

### 4.2 As written, at native resolution

**Full-screen session, 1080x2400.** Orb radius = 0.2209 x 2400 = 530 px, so the orb disc is
0.88 Mpx and the surrounding sky is 1.71 Mpx.

```
sky   1.71 Mpx x 1830 = 3.13 G
orb   0.88 Mpx x 4580 = 4.03 G
                        7.2 G ops per frame
```

At 60 fps that is **430 G ops/s**, against a 150-350 G ops/s part. **20-48 ms for the scene
pass alone.** Not viable.

**Feed card.** The globe unit is a 634 dp square (`GlobalPauseCardView.swift:186`), which at
density 2.625 is 1664 px square = 2.77 Mpx, of which the card shows roughly 974 x 525 px.
Orb radius = 0.70 x 200 dp = 367 px, about 45 % of the disc visible.

```
sky   2.58 Mpx x 1830 = 4.72 G
orb   0.19 Mpx x 4580 = 0.87 G
                        5.6 G ops per frame
```

**The card is nearly as expensive as the full-screen session**, because almost all of it is
empty sky running the 64-source orb loop — and it runs inside a scrolling feed. This is the
result that most changes the plan.

### 4.3 Three fixes, in order of leverage

**Fix A — reach cull (biggest win, ~10 lines).** With the shipped styles every light volume
lies within ~1.3 world units of the sphere centre: `.buried` orbs sit on the surface with
`elev = 0` (`:488`) and sigma clamped to 0.055 (`EarthGlowStore.swift:293`), so their 7.5-sigma
reach is at most 1.41; expanding shells only exist under `sparkStyle = .flashShell`, which is
not the default (`EarthGlowStore.swift:116`). The CPU already knows the live maximum. Upload it
(`orbSeat.yzw` are marked reserved in `EarthTuningShared.h:31`) and test it once per fragment.

After the rebasing at `:586-589`, `roL` sits at the ray's closest approach to the centre, so
the test is `dot(roL, roL) > maxReach * maxReach` — one dot, one compare, six ops — and it
skips both volume loops. Exact, no visual change. It converts the sky from 1830 ops to ~40.

**Fix B — cosine-domain reject in `accumulateGlow` (~5 lines).** `:251-254` computes
`acos(dot)` for **every** source and only then rejects on `x > 7.5`. Pack `cos(7.5 * radius)`
per source on the CPU (classic sources have `radiusPacked.w` free — it is a debug tag, `= 0`,
per `EarthRendererTypes.swift:21`) and reject on the cosine first. Only the two or three
sources that actually cover the pixel then pay an `acos`. Cost per call falls from ~1280 ops
to ~500. The same pattern applies to the cone rejection at `:323`, which also calls `acos`
before rejecting. **This is worth doing on iOS too.**

**Fix C — scene render scale.** The cheapest lever and the one with a dial. Deliver it with
`SurfaceTexture.setDefaultBufferSize(w, h)` on the `TextureView`: the GL surface becomes
smaller than the view and HWUI upscales bilinearly at composite time, with no change to any
matrix, viewport ratio or ripple projection. One knob scales every pass including the composite.

### 4.4 Budget after the fixes

| Configuration | Ops/frame | ms at 150-350 G ops/s |
|---|---|---|
| Full-screen, as written | 7.2 G | 20-48 |
| Full-screen, + A | 5.2 G | 15-35 |
| Full-screen, + A + B | 3.8 G | 11-25 |
| **Full-screen, + A + B + 0.6 scale** | **1.37 G** | **4-9** |
| Card, as written | 5.6 G | 16-37 |
| Card, + A + B | 0.92 G | 3-6 |
| **Card, + A + B + 0.6 scale** | **0.33 G** | **1-2** |

Bandwidth at 0.6 scale, full-screen: scene write 7.5 MB, composite read 7.5 MB, composite
write 3.7 MB, bloom chain ~2 MB — about **21 MB/frame, 1.25 GB/s at 60 fps**, roughly 10 % of
a mid-range phone's budget. At native it would be ~52 MB/frame and 3.1 GB/s, 25-30 %. A second
reason for the scale, independent of ALU.

### 4.5 Recommendation

**Full resolution is not viable. Render the scene to a reduced offscreen target and let the
composite upscale — a device-class dial defaulting to 0.6, with Fixes A and B landed first.**

Concretely:

- Scene render scale **0.6** on both the card and the session, exposed as one constant and
  selected at startup from `GL_RENDERER` or a one-frame micro-benchmark. Tier it 0.5 / 0.6 /
  0.8 rather than making it binary.
- **Scale `rimTightness` (`T.glass.y`) by the render scale.** The rim's alpha band is
  `pow(1 - ndv, 28 * rimTightness)` (`:878`), which puts the opaque line inside the outer
  ~0.1 % of the radius — under a pixel at 530 px. Downscaling would turn it into a stepped
  edge. Because that one scalar drives all three coupled exponents proportionally
  (`:718-722`, `EarthRendererTypes.swift:72-74`), one multiply keeps the rim a constant number
  of *device* pixels at any scale. This knob existing is luck, and it is what makes downscaling
  safe.
- Scale the composite dither amplitude by `1 / renderScale` (`EarthBloom.metal:154`), since the
  bilinear upscale smooths it.
- **Keep the 600 px bloom reference height unchanged.** It is already scale-invariant by
  design, which means the halo does not change when the render scale tier does.
- **Frame rate: 30 fps in the feed card and while idle, 60 fps while a finger is down.** The
  idle drift is 0.05 rad/s (`EarthInteraction.swift:35`) — imperceptibly different at 30 — and
  this halves everything above. Only the drag needs 60.
- Keep the iOS geometry (centred orb, symmetric frustum, oversized unit clipped by the card).
  An **off-axis frustum** would render only the card's visible rect and save another ~5x
  there, but it moves the orb off the view centre and so forces a re-derivation of the ripple
  overlay's projection (`EarthHaloRipples.swift:91,113-114`) and of
  `orbScreenRadiusFractionOfHeight`. Hold it as an optimisation for after the port lands, not
  a part of it.

The honest caveat: these are static op counts, not measurements. They are reliable about
*ratios* and about which term dominates; they are only indicative about absolute milliseconds.
§7 names the prototype that replaces them with numbers.

## 5. Interaction

`EarthInteraction.swift` is 396 lines of arithmetic with a thin UIKit skin. Most of it ports
one-to-one.

### 5.1 Moves across unchanged

- The whole north-up model: two scalars (`yaw`, `pitch`), a derived quaternion, the pitch
  clamp, the drive gate and its smoothstep ease, `settle(onLatDeg:)` and its
  forward-and-at-least-one-turn target, the Lissajous idle drift, the yaw wrap
  (`:104-119,190-292`).
- **The damping is already frame-rate independent** — `powf(tuning.damping, 60.0)` converted
  to a per-second rate at `:262-264`, and the gate bleed at `:269-271` does the same. This is
  the part that usually breaks on a 90/120 Hz Android display, and it will not.
- The tap raycast (`:348-383`): ray from NDC, sphere intersection, inverse orientation,
  lat/lon. `CountryLookup` and `GeoMath` are pure data and pure math — direct Kotlin ports,
  and good JUnit parity-test material against the iOS values.
- `EarthGlowStore` (755 lines) is pure CPU and has no platform dependency beyond
  `@Observable`. It is the single best candidate in the whole feature for a
  behaviour-identical port with tests: lerp, spark envelopes, region resolution, the
  budget/eviction rule at `:274-281`, and the three-range packing.

### 5.2 Needs rework

**The velocity assumption is a real bug waiting to happen.** `:324`:
`dragVelocity = SIMD2(dYaw, dPitch) * 60.0` — "assuming ~60Hz touch delivery". Android
delivers touch at the digitiser's rate (often 120-240 Hz), batches multiple samples into one
`MotionEvent`, and runs displays at 60/90/120 Hz. Ported literally, a flick on a 120 Hz phone
throws the globe at double speed. Replace it with real velocity from `MotionEvent.getEventTime`
deltas, or a `VelocityTracker`, converted to radians/second. Also iterate
`getHistoricalX/Y` — dropping the batched samples makes drags feel chunky.

**Threading.** On iOS the whole class is `@MainActor` and `MTKViewDelegate` draws on the main
thread, so touch, simulation and render share one thread. On Android touch arrives on the UI
thread and rendering runs on the GL thread. Keep `EarthInteraction` state owned by the **GL
thread** and post touch events to it (the `queueEvent` pattern). Then publish the composed
matrix that `currentOrientationMatrix` (`:183-186`) exposes as a volatile snapshot written
once per frame, because the ripple overlay reads it from the UI thread. The comment at
`:179-182` — "calling `orientationMatrix` from a second call site would feed `advance` a
second clock and corrupt dt" — is exactly the invariant that a two-thread split can break.

**The tap slop.** `total < 6` points (`:334`) should become
`ViewConfiguration.get(context).scaledTouchSlop`, not a ported literal.

**System gesture conflict.** A full-screen globe that consumes horizontal drags fights
Android's predictive-back edge gesture. Call `setSystemGestureExclusionRects` on the globe
view (API 29+) for the left and right edge strips, or accept that a drag starting within
~24 dp of an edge navigates back instead of spinning the world. iOS has no equivalent conflict,
so this will not be found by following the iOS code.

**Clock.** `CACurrentMediaTime()` becomes `System.nanoTime() / 1e9` — also monotonic, so the
deliberate two-clock split (renderer-relative time for the shader, absolute time for ripple
ages, `EarthHaloRipples.swift:15-18,65-71`) survives intact. Keep both clocks distinct.

### 5.3 The overlays

`EarthHaloRipplesOverlay` (`EarthHaloRipples.swift:76-142`) is a SwiftUI `Canvas` doing an
orthographic projection of ripple points, driven by `TimelineView(.animation)`. In Compose:
a `Canvas` inside a `withFrameNanos` loop. Straightforward, except one minSdk-26 trap:
`.blur(radius: 0.6)` at `:138` — Compose's `Modifier.blur` is **API 31+** and silently does
nothing below it. At 0.6 px it is cosmetically negligible; drop it and widen the stroke
slightly rather than branching on API level. The same applies to the country-reveal capsule's
`.ultraThinMaterial` (`Earth3DView.swift:109`): below API 31 there is no live blur, so use a
translucent fill.

## 6. A staged plan for week 7

Each stage ends at something demonstrable, and every stage after the first is independently
droppable. The order is chosen so the riskiest platform questions are answered on day one and
the prettiest work is last.

| Stage | Lands | Demonstrable end state |
|---|---|---|
| **0** — week 2, 2 h | The prototype in §7 | A number, not a feature |
| **1** — day 1 | `TextureView` + EGL + render thread + fullscreen triangle + three UBOs + R8 continent texture + the surface shader **without** glow, volumes or bloom | A rotating iridescent glass world with a rim. Recognisably Deep. Proves precision, texture orientation, UBO layout, the projection and the format probe. |
| **2** — day 2 | The bloom chain: threshold, blur H, blur V, composite; the `RGBA16F` FBOs; `glInvalidateFramebuffer` | The orb at rest, matching iOS side by side |
| **3** — day 3 | `EarthGlowStore` in Kotlin with JUnit parity tests, UBO upload, `accumulateGlow` **with Fix B**, `volumetricShell` | The world lights where people are |
| **4** — day 3-4 | `accumulateLightVolumes`: orb/dome/buried plus expanding shells, **with Fix A** | Parity with the shipped `.buried` default; sparks |
| **5** — day 4 | `EarthInteraction`, touch, momentum, tap reveal, ripples | You can spin the world and tap a country |
| **6** — day 5 | The card lift | Feature parity |

Stage 3 is the one to start early if anything can run in parallel: it is pure Kotlin, needs no
GPU, and is the largest single body of logic (755 lines).

### The fallback ladder

Every rung is a **runtime dial**, not a code change, until the last two. Descend only as far as
the hardware forces.

1. **Render scale** 0.6 to 0.5. Linear, and invisible once `rimTightness` tracks it.
2. **30 fps** everywhere instead of on idle only.
3. **`volBackGhost = 0`** (`EarthTuning.swift:136`). Deletes the second 64-source
   `accumulateGlow` at `:772-779` — roughly a third of orb-pixel cost. What is lost: the faint
   ghost of far-side lights through the glass body. Almost nobody will name what changed.
4. **`glowPointStyle = .classic`, `sparkStyle = .classic`.** This is the escape hatch the
   codebase already built: with both ranges empty, the guard at `:585` is false, the entire
   light-volume machinery is skipped, and the comment at `:571-574` promises the output is
   *bit-identical to the pre-3D look*. Costs the 3D glow balls and the expanding join shells;
   keeps the surface gaussians, the volumetric columns and the ripple rings. **This is a
   look the team already shipped and signed off**, which makes it the safest large cut
   available.
5. **Bloom off.** `EarthRenderer.swift:244-249` already has the "post pipelines missing, render
   direct to drawable" path. On GLES that means one pass to the default framebuffer with a
   tonemap. Big saving, and the biggest visible loss — the halo is much of the design.
6. **The degraded globe.** If the raymarch itself will not fit: draw an actual sphere mesh
   (~1000 triangles), sample the same continent texture, apply the same latitude palette walk
   and a fresnel rim in the fragment shader, and draw glow as additive camera-facing billboards
   at each source. Cost is roughly a twentieth. It keeps what the screen is *for* — a rotating
   world, lit where people are, in Deep's palette, spinnable, tappable — and loses the glass
   body, the refracted back-bleed and the volumetric columns. A day's work, and a credible
   globe rather than a placeholder.
7. **The week-6 2D placeholder.** Already exists. The floor, not the plan.

## 7. Go / no-go

**Go. High confidence on feasibility, medium confidence on full-fidelity 60 fps on the weakest
mid-range part.**

- **High confidence** that the shader translates. Every construct maps; the three items needing
  redesign (§1.1) are each under an hour; the byte layouts of all three uniform blocks are
  already std140-compatible; and the projection already uses GL's depth convention. There is no
  feature the platform lacks.
- **High confidence** that a good-looking globe ships in week 7, because the fallback ladder has
  six rungs before the placeholder and rung 4 is a look the team has already approved.
- **Medium confidence** on *unreduced, 60 fps, on a Mali-G57-class part*. The arithmetic says it
  needs Fixes A and B and a 0.6 render scale to land in budget, and the arithmetic is an
  estimate, not a measurement.
- **The thermal question is separate from the frame question** and is not answered here: Global
  Pause holds this screen for ten-plus minutes. A pipeline that hits 16 ms cold may hit 24 ms
  at minute eight. That is why the target above is 6-8 ms, not 16.

### The single biggest unknown, and the two hours that retire it

**How much does one orb pixel actually cost on mid-range Android silicon?** Everything else in
this document is either certain or has a cheap fallback. This one determines the render scale,
whether Fixes A and B are optimisations or prerequisites, and whether stages 4-6 of week 7 are
realistic.

The week-2 prototype, about two hours:

1. Mechanically port **only** `earthSurfaceFragment` — no bloom, no interaction, no glow store.
2. Fill the glow UBO with 64 synthetic sources at the `.buried` defaults (a ring of points at
   the real radii), so the loops run at production width.
3. Render to a plain `GLSurfaceView` at 1080x2400, then at 0.6 scale, on one real mid-range
   phone. Not an emulator — `ANDROID_ROADMAP.md` already flags emulator timings as misleading,
   and for this question they are worthless.
4. Report: ms/frame at each scale; the same with Fix A and Fix B applied; sustained fps after
   five minutes; and the `GL_EXTENSIONS` string plus a `glCheckFramebufferStatus` on an
   `RGBA16F` attachment.

Item 4's last clause is the free second answer: it retires the `EXT_color_buffer_half_float`
question in the same session for no extra work.

If that prototype reports under 10 ms at 0.6 scale with A and B, week 7 proceeds as planned
with the full shader. If it reports 10-16 ms, week 7 proceeds and lands on rungs 1-3 of the
ladder. If it reports over 20 ms, the decision to make in **week 2** — not week 7 — is rung 6,
the mesh globe, and there is time to design it properly.
