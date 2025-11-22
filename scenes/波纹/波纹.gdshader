shader_type canvas_item;

uniform vec2 center = vec2(0.5, 0.5);
uniform float speed = 0.6;
const int MAX_COLORS = 8;
uniform vec4 colors[MAX_COLORS];
uniform int color_count = 2;
uniform float thicknesses[MAX_COLORS];
uniform vec2 tex_size = vec2(256.0, 256.0);

float max_r(vec2 c) {
    vec2 d = max(c, 1.0 - c) * tex_size;
    return length(d);
}

void fragment() {
    vec2 uv = UV;
    vec2 sz = tex_size;
    float mr = max_r(center);
    float r = length((uv - center) * sz);
    int cc = int(clamp(float(color_count), 1.0, float(MAX_COLORS)));
    float period = 0.0;
    for (int i = 0; i < MAX_COLORS; i++) {
        if (i >= cc) { break; }
        float w = thicknesses[i];
        if (w <= 0.0) { w = 0.03; }
        period += w * mr;
    }
    if (period <= 0.0) { period = mr * 0.24; }
    float p = r - TIME * speed * period;
    float x = fract(p / period) * period;
    float acc = 0.0;
    int chosen = 0;
    for (int i = 0; i < MAX_COLORS; i++) {
        if (i >= cc) { break; }
        float w = thicknesses[i];
        if (w <= 0.0) { w = 0.03; }
        float ws = w * mr;
        if (x < acc + ws) { chosen = i; break; }
        acc += ws;
    }
    vec3 rgb = colors[chosen].rgb;
    COLOR = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
