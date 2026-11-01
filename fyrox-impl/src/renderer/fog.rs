// Copyright (c) 2019-present Dmitry Stepanov and Fyrox Engine contributors.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

//! Distance fog (see [`crate::scene::Fog`]): laid over the lit scene, sky and all, before the
//! forward pass - so what is drawn there, glowing things and particles, shows through it.

use crate::{
    core::{math::Rect, sstorage::ImmutableString},
    graphics::{error::FrameworkError, framebuffer::GpuFrameBuffer, gpu_texture::GpuTexture},
    renderer::{
        cache::{
            shader::{binding, property, PropertyGroup, RenderMaterial},
            uniform::UniformBufferCache,
        },
        make_viewport_matrix,
        observer::Observer,
        resources::RendererResources,
        RenderPassStatistics,
    },
    scene::Fog,
};
use fyrox_graphics::server::GraphicsServer;

/// Covers the frame in `frame_buffer` with `fog`, as far as the depth in `depth` says each pixel
/// is from the observer.
pub(crate) fn render_fog(
    server: &dyn GraphicsServer,
    fog: &Fog,
    observer: &Observer,
    viewport: Rect<i32>,
    depth: &GpuTexture,
    frame_buffer: &GpuFrameBuffer,
    uniform_buffer_cache: &mut UniformBufferCache,
    renderer_resources: &RendererResources,
) -> Result<RenderPassStatistics, FrameworkError> {
    let _debug_scope = server.begin_scope("Fog");
    let mut statistics = RenderPassStatistics::default();
    let frame_matrix = make_viewport_matrix(viewport);
    let inv_view_projection = observer
        .position
        .view_projection_matrix
        .try_inverse()
        .unwrap_or_default();
    let color = fog.color.srgb_to_linear_f32();
    let properties = PropertyGroup::from([
        property("worldViewProjection", &frame_matrix),
        property("invViewProj", &inv_view_projection),
        property("cameraPosition", &observer.position.translation),
        property("fogColor", &color),
        property("density", &fog.density),
        property("start", &fog.start),
        property("baseHeight", &fog.base_height),
        property("heightFalloff", &fog.height_falloff),
        property("skyOpacity", &fog.sky_opacity),
    ]);
    let material = RenderMaterial::from([
        binding("depthTexture", (depth, &renderer_resources.nearest_clamp_sampler)),
        binding("properties", &properties),
    ]);
    statistics += renderer_resources.shaders.fog.run_pass(
        1,
        &ImmutableString::new("Primary"),
        frame_buffer,
        &renderer_resources.quad,
        viewport,
        &material,
        uniform_buffer_cache,
        Default::default(),
        None,
    )?;
    Ok(statistics)
}
