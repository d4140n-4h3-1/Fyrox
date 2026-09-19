# Vulkan fork

This branch makes Fyrox's wgpu backend (`backend_wgpu`, Vulkan on Linux) render games the same
way the OpenGL backend does. It was driven by running Station Iapetus on both backends and
comparing the frames stage by stage (G-buffer, HDR, final image).

Build a game with `fyrox = { default-features = false, features = ["backend_wgpu"] }`, in a
workspace where nothing enables `backend_opengl`: when both are on, OpenGL wins.

## What changed and why

**Build**
- `fyrox/Cargo.toml`: `fyrox-impl` no longer pulls in its default features, which always
  enabled OpenGL, so `backend_wgpu` could never take effect.

**Coordinate conventions.** The engine's matrices and shaders follow OpenGL. wgpu clips depth
below 0 instead of -1 and stores render targets top row first.
- `fyrox-graphics-wgpu/src/vertex_depth.rs`: every vertex shader's `vs_main` is wrapped to map
  clip-space depth to wgpu's range, so depth values equal OpenGL's window depth again and the
  near half of every frustum is no longer clipped away.
- `shared.wgsl`: `S_UnProject` flips v. Shadow lookups use the new `S_ProjectToTexture`, and
  lookups into cube maps the renderer draws itself go through `S_RenderedCubeDirection`.
- The SSAO kernel and decal screen UVs flip v.
- The light volume pass (`light_volume.rs`) and the bloom bright pass (`bloom/mod.rs`) use
  `make_deferred_viewport_matrix`, so they line up with the G-buffer and the scene frame.
- UI drawn into textures is flipped (`UiRenderContext::flip_y`) to match OpenGL's layout.

**Backend correctness**
- `Queue::write_*` takes effect at the next submit, ahead of the whole batch. Recorded commands
  are now submitted before every buffer, geometry, texture and readback write. Without this,
  stale uniforms hung the GPU until the driver reset it.
- Non-normalized integer vertex attributes (bone indices) are converted to `f32` on upload, as
  OpenGL does.
- Clears are tracked per part (color, depth, stencil); a stencil-only clear used to wipe color.
- The pipeline cache is keyed on the full `DrawParameters`, and the color write mask is honored.
- The bind group and pipeline caches are keyed on wgpu handles, not wrapper addresses, and the
  bind group cache is bounded.
- Scissor rectangles are clipped to the render target. Readback rows are padded to 256 bytes.
- Render passes draw into the requested mip level; the prefiltered specular probe used to
  render every level into mip 0.
- `swap_buffers` presents a cleared frame when nothing was drawn, so a Wayland window is always
  mapped and the event loop never waits for a frame callback that cannot come.

**Also on this branch**
- `renderer/mod.rs`: the uniform memory page size is capped at 1 MB. Some drivers (AMD with Mesa)
  report 2 GB, which made every upload enormous and froze loading screens. This affects OpenGL
  too.
- `scene/animation/mod.rs`: animation tracks accept property paths saved by older engine
  versions (no leading `0.`, `Content` instead of `Value`, paths that step through inheritable
  variables). Station Iapetus's lights and doors use such paths.
- Scene and UI loading no longer log an error for files saved before `UserData` existed.
- Script errors name the failing script type, not just the node.
- `shared.wgsl` / `shared.glsl`: the soft shadow (PCF) filter divided by fewer samples than it
  took, which pushed the penumbra to full shadow early and left a hard edge. Both backends now
  divide by the real sample count.
- `renderer/mod.rs`: when FXAA is switched off, the frame is copied instead, so the number of
  full-screen passes between the scene and the back buffer stays the same. Each such pass flips
  the image on wgpu and the flips only cancel in pairs, so skipping one turned the frame upside
  down.
- `fyrox-graphics-wgpu/src/framebuffer.rs`: a pipeline no longer declares a depth-stencil state
  when the pass it runs in has no depth attachment. wgpu rejected such draws outright ("render
  pipeline targets are incompatible with render pass").
- `renderer/light.rs`: point and spot lighting is drawn with a scissor box around the light's
  screen-space bounds instead of over the whole frame. It changes nothing on screen; it saves work
  in scenes with many small lights, though in a corridor with lamps overhead (where the camera
  sits inside most light volumes) the saving is small.
- `fyrox-graphics-wgpu/src/raytracing.rs`: hardware ray tracing, where the adapter has it. The
  device is created with wgpu's experimental ray query feature, scene triangles can be put into an
  acceleration structure, and a self-contained pass traces one shadow ray per pixel into a mask
  texture. Nothing else in the renderer knows about it; an effect reads the mask as an ordinary
  texture. Off unless a game asks for it.
