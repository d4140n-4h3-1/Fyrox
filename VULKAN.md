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
