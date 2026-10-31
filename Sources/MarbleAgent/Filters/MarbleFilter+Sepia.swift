extension MarbleFilter {
    /// Sepia: each pixel's color through the classic sepia matrix, mixed with the original by the intensity.
    /// The colors are premultiplied, so a channel is clamped to the pixel's alpha, not to 1.
    static let sepiaKernel = MarbleKernel(name: "marble_sepia", source: """
        #include <metal_stdlib>
        using namespace metal;

        kernel void marble_sepia(texture2d<float, access::read> source [[texture(0)]],
                                 texture2d<float, access::write> target [[texture(1)]],
                                 constant float &intensity [[buffer(0)]],
                                 uint2 gid [[thread_position_in_grid]]) {
            if (gid.x >= target.get_width() || gid.y >= target.get_height()) { return; }
            float4 color = source.read(gid);
            float3 toned = float3(dot(color.rgb, float3(0.393, 0.769, 0.189)),
                                  dot(color.rgb, float3(0.349, 0.686, 0.168)),
                                  dot(color.rgb, float3(0.272, 0.534, 0.131)));
            target.write(float4(mix(color.rgb, min(toned, float3(color.a)), intensity), color.a), gid);
        }
        """)
}
