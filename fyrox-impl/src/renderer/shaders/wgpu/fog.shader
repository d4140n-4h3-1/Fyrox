(
    name: "Fog",
    resources: [
        (
            name: "depthTexture",
            kind: Texture(kind: DepthSampler2D, fallback: White),
            binding: 0
        ),
        (
            name: "properties",
            kind: PropertyGroup([
                (name: "worldViewProjection", kind: Matrix4()),
                (name: "invViewProj", kind: Matrix4()),
                (name: "cameraPosition", kind: Vector3()),
                (name: "fogColor", kind: Vector4()),
                (name: "density", kind: Float()),
                (name: "start", kind: Float()),
                (name: "baseHeight", kind: Float()),
                (name: "heightFalloff", kind: Float()),
                (name: "skyOpacity", kind: Float()),
            ]),
            binding: 0
        ),
    ],
    passes: [
        (
            name: "Primary",

            draw_parameters: DrawParameters(
                cull_face: None,
                color_write: ColorMask(
                    red: true,
                    green: true,
                    blue: true,
                    alpha: false,
                ),
                depth_write: false,
                stencil_test: None,
                depth_test: None,
                blend: Some(BlendParameters(
                    func: BlendFunc(
                        sfactor: SrcAlpha,
                        dfactor: OneMinusSrcAlpha,
                        alpha_sfactor: Zero,
                        alpha_dfactor: One,
                    ),
                    equation: BlendEquation(
                        rgb: Add,
                        alpha: Add
                    )
                )),
                stencil_op: StencilOp(
                    fail: Keep,
                    zfail: Keep,
                    zpass: Keep,
                    write_mask: 0xFFFF_FFFF,
                ),
                scissor_box: None
            ),

            vertex_shader:
                r#"
                    struct VertexInput {
                        @location(0) vertex_position: vec3f,
                        @location(1) vertex_tex_coord: vec2f,
                    }

                    struct VertexOutput {
                        @builtin(position) position: vec4f,
                        @location(0) tex_coord: vec2f,
                    }

                    @vertex fn vs_main(input: VertexInput) -> VertexOutput {
                        var output: VertexOutput;
                        output.tex_coord = input.vertex_tex_coord;
                        output.position = properties.worldViewProjection * vec4f(input.vertex_position, 1.0);
                        return output;
                    }
                "#,

            fragment_shader:
                r#"
                    // Exponential distance fog, thinning with height above baseHeight: how much
                    // of the fog colour covers the fragment. Nothing drawn there - the sky - is
                    // covered by skyOpacity of it.
                    @fragment fn fs_main(@location(0) tex_coord: vec2f) -> @location(0) vec4f {
                        let depth = textureSample(depthTexture_tex, depthTexture_samp, tex_coord);
                        var amount: f32;
                        if (depth >= 0.99999) {
                            amount = properties.skyOpacity;
                        } else {
                            let position = S_UnProject(vec3f(tex_coord, depth), properties.invViewProj);
                            let distance = max(length(position - properties.cameraPosition) - properties.start, 0.0);
                            let above = max(0.5 * (position.y + properties.cameraPosition.y) - properties.baseHeight, 0.0);
                            let density = properties.density * exp(-properties.heightFalloff * above);
                            amount = 1.0 - exp(-density * distance);
                        }
                        return vec4f(properties.fogColor.rgb, clamp(amount, 0.0, 1.0));
                    }
                "#,
        )
    ]
)
