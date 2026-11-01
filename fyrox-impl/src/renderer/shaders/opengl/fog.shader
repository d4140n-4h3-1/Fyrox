(
    name: "Fog",
    resources: [
        (
            name: "depthTexture",
            kind: Texture(kind: Sampler2D, fallback: White),
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
                    layout (location = 0) in vec3 vertexPosition;
                    layout (location = 1) in vec2 vertexTexCoord;

                    out vec2 texCoord;

                    void main()
                    {
                        texCoord = vertexTexCoord;
                        gl_Position = properties.worldViewProjection * vec4(vertexPosition, 1.0);
                    }
                "#,

            fragment_shader:
                r#"
                    // Exponential distance fog, thinning with height above baseHeight: how much
                    // of the fog colour covers the fragment. Nothing drawn there - the sky - is
                    // covered by skyOpacity of it.
                    in vec2 texCoord;
                    out vec4 fragColor;

                    void main()
                    {
                        float depth = texture(depthTexture, texCoord).r;
                        float amount;
                        if (depth >= 0.99999) {
                            amount = properties.skyOpacity;
                        } else {
                            vec3 position = S_UnProject(vec3(texCoord, depth), properties.invViewProj);
                            float distance = max(length(position - properties.cameraPosition) - properties.start, 0.0);
                            float above = max(0.5 * (position.y + properties.cameraPosition.y) - properties.baseHeight, 0.0);
                            float density = properties.density * exp(-properties.heightFalloff * above);
                            amount = 1.0 - exp(-density * distance);
                        }
                        fragColor = vec4(properties.fogColor.rgb, clamp(amount, 0.0, 1.0));
                    }
                "#,
        )
    ]
)
