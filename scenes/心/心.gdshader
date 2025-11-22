shader_type canvas_item;

/*
Godot 4 精确向量心形 Shader
- 使用来自 VectorDrawable pathData 的 6 段三次贝塞尔曲线，像素级绘制心形
- 支持：填充、内描边、外描边、光晕
- 填充：折线采样 + 水平射线交叉计数法
- 描边：点到折线段的最短距离近似曲线距离
- 性能：圆形包围裁剪、按需计算遮罩、合理采样步数

用法：
- 在 `ColorRect/TextureRect` 上使用；建议尺寸 500×500（或按比例缩放）
- `UV[0,1]` 映射到 500×500 的逻辑视口坐标
- 可调参数：颜色、描边宽度、柔和度、光晕大小/强度、脉动与旋转、保持纵横比
- 质量与性能：采样步数常量 `STEPS_PER_SEG` 默认 16；越高越精细但更慢；可根据需求改为 20–24
*/

// 外观颜色（线性空间 0..1）
uniform vec4 fill_color  : source_color = vec4(1.0, 1.0, 1.0, 1.0); // 填充颜色（形状内部）
uniform vec4 inner_color : source_color = vec4(0.937, 0.212, 0.804, 1.0); // 内描边颜色（与填充叠加），示例 #EF36CD
uniform vec4 outer_color : source_color = vec4(0.647, 0.0, 0.631, 1.0);   // 外描边/光晕颜色，示例 #A500A1

// 描边宽度（像素，基于 500×500 视口）
uniform float stroke_outer = 20.0; // 外描边宽度；设为 0 关闭；较大会增大包围半径，略降性能
uniform float stroke_inner = 20.0; // 内描边宽度；设为 0 关闭；较小更贴近曲线

// 边缘柔和度（像素，smoothstep 过渡宽度）；小值边缘更硬，大值更柔和
uniform float softness = 2.0;

// 光晕参数
uniform float glow_size = 40.0;    // 光晕向外扩散的半径（像素）；设为 0 关闭
uniform float glow_strength = 1.2; // 光晕强度（乘性系数）；设为 0 关闭，过大会偏白

// 动画：脉动缩放与轻微旋转（基于 TIME）
uniform float pulse_speed = 1.2;    // 脉动频率（rad/s）；越大心跳越快
uniform float pulse_amount = 0.06;  // 脉动缩放幅度（0..约0.1）；0 不缩放
uniform float rotate_amount = 0.04; // 旋转幅度（弧度）；随时间轻微摆动

// 是否在非正方形视口下保持 500×500 映射的纵横比并居中
uniform bool preserve_aspect = true;

uniform vec2 rect_size = vec2(500.0, 500.0);

// 采样分辨率：每段贝塞尔的离散点数；越高越精细但更慢；建议 12–32，默认 16
const int STEPS_PER_SEG = 12;

// 构成心形的三次贝塞尔段数量（共 6 段）
const int SEGMENTS = 6;

/* 贝塞尔控制点说明（绝对坐标，逻辑视口 500×500）
   每段 i 的三次曲线由 P0[i], P1[i], P2[i], P3[i] 定义。
   数据来源：VectorDrawable 的 pathData（已从相对坐标换算为绝对）。
*/
const vec2 P0[SEGMENTS] = vec2[](
    vec2(250.23,148.82), // seg0 start
    vec2(165.77,100.04), // seg1 start (previous seg0 end)
    vec2(78.14,173.73),  // seg2 start
    vec2(251.29,400.0),  // seg3 start
    vec2(421.27,174.77), // seg4 start
    vec2(335.75,101.08)  // seg5 start
);

const vec2 P1[SEGMENTS] = vec2[](
    vec2(247.38,144.59),
    vec2(119.30,101.55),
    vec2(58.28,239.24),
    vec2(374.63,333.64),
    vec2(412.66,146.18),
    vec2(286.0,98.55)
);

const vec2 P2[SEGMENTS] = vec2[](
    vec2(215.17,98.43),
    vec2(87.04,144.37),
    vec2(125.75,333.15),
    vec2(441.02,240.34),
    vec2(381.81,103.42),
    vec2(252.92,144.93)
);

const vec2 P3[SEGMENTS] = vec2[](
    vec2(165.77,100.04),
    vec2(78.14,173.73),
    vec2(251.29,400.0),
    vec2(421.27,174.77),
    vec2(335.75,101.08),
    vec2(250.23,148.82) // final end equals starting point (closed)
);

// 工具：在 t∈[0,1] 上计算三次贝塞尔曲线点
vec2 cubic_point(vec2 a, vec2 b, vec2 c, vec2 d, float t) {
    float u = 1.0 - t;
    float tt = t * t;
    float uu = u * u;
    float uuu = uu * u;
    float ttt = tt * t;
    return uuu * a + 3.0 * uu * t * b + 3.0 * u * tt * c + ttt * d;
}

// 工具：点 p 到线段 ab 的最短距离
float dist_point_segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    vec2 proj = a + ba * h;
    return length(p - proj);
}

// 片元主过程
void fragment() {
    // 将 UV[0,1] 映射为 500×500 的逻辑视口坐标
    vec2 uv = UV;
    // 坐标以 (250,250) 为中心，与向量数据方向一致
    vec2 pos = uv * 500.0;

    if (preserve_aspect) {
        float inv_aspect = rect_size.y / max(1.0, rect_size.x);
        pos.x = (UV.x - 0.5) * 500.0 * inv_aspect + 250.0;
    }

    // 动画：围绕中心的脉动缩放与轻微旋转
    float t = TIME;
    float pulse = 1.0 + sin(t * pulse_speed) * pulse_amount;
    vec2 center = vec2(250.0, 250.0);
    vec2 p = pos - center;
    // 旋转
    float rot = sin(t * 0.2) * rotate_amount;
    float cs = cos(rot);
    float sn = sin(rot);
    p = vec2(p.x * cs - p.y * sn, p.x * sn + p.y * cs);
    // 缩放（脉动）
    p /= pulse;
    pos = p + center;
    // 圆形包围裁剪：远离心形的片元直接丢弃，以减少不必要计算
    float half_outer = stroke_outer * 0.5;
    float half_inner = stroke_inner * 0.5;
    bool need_distance = (stroke_outer > 0.0) || (stroke_inner > 0.0) || (glow_strength > 0.0 && glow_size > 0.0);
    float margin = half_outer + glow_size + softness + 10.0; // 描边/光晕/柔和度裕量
    float base_R = 206.0; // 心形的大致半径（经验值）
    float R = base_R + margin;
    if (length(pos - center) > R) {
        discard;
    }

    // 对每段贝塞尔采样为 STEPS_PER_SEG 个点
    // 使用边(prev->curr)同时进行填充判定与距离计算
    float minDist = 1e6;
    int crossings = 0;

    // 前一点跨段传递：从第 0 段 t=0 的起点开始
    vec2 prev = cubic_point(P0[0], P1[0], P2[0], P3[0], 0.0);
    float inv_steps = 1.0 / float(STEPS_PER_SEG);

    // Iterate segments
    for (int s = 0; s < SEGMENTS; s++) {
        // 每段采样 STEPS_PER_SEG 次（t 从 1/STEPS .. 1）
        for (int i = 1; i <= STEPS_PER_SEG; i++) {
            float tstep = float(i) * inv_steps;
            vec2 curr = cubic_point(P0[s], P1[s], P2[s], P3[s], tstep);

            if (need_distance) {
                float d = dist_point_segment(pos, prev, curr);
                minDist = min(minDist, d);
            }

            // 射线交叉法：
            // 计算边(prev->curr)与 y=pos.y 的交点；当交点 x>pos.x 时计数
            bool cond1 = (prev.y > pos.y);
            bool cond2 = (curr.y > pos.y);
            if (cond1 != cond2) {
                // compute x intersection
                float xint = (curr.x - prev.x) * (pos.y - prev.y) / (curr.y - prev.y) + prev.x;
                if (xint > pos.x) {
                    crossings++;
                }
            }

            prev = curr;
        }
        // 每段结束后以当前 curr 作为下一段起点，继续循环
    }

    // 交叉计数为奇数代表片元在形状内部
    bool inside = (crossings % 2) == 1;

    // 根据距离与填充构建遮罩；描边单位为像素；用 softness 做平滑
    float outer_mask = 0.0;
    if (stroke_outer > 0.0) {
        outer_mask = 1.0 - smoothstep(half_outer - softness, half_outer + softness, minDist);
    }
    float inner_mask = 0.0;
    if (stroke_inner > 0.0) {
        inner_mask = 1.0 - smoothstep(half_inner - softness, half_inner + softness, minDist);
    }

    // 内描边与填充的组合：使用 fill_mask（内部）叠加
    float fill_mask = inside ? 1.0 : 0.0;

    // 组合最终输出颜色
    vec3 result = vec3(0.0);
    float alpha = 0.0;

    // 先绘制填充（内部）
    if (fill_mask > 0.0) {
        result = mix(result, fill_color.rgb, fill_mask);
        alpha = max(alpha, fill_color.a * fill_mask);
    }

    // 内描边：仅在形状内部生效
    if (inner_mask > 0.0) {
        float inner_inside = inner_mask * fill_mask;
        result = mix(result, inner_color.rgb, inner_inside);
        alpha = max(alpha, inner_color.a * inner_inside);
    }

    // 外描边：仅在形状外部显示
    float outer_only = outer_mask * (1.0 - fill_mask);
    if (outer_only > 0.0) {
        result = mix(result, outer_color.rgb, outer_only);
        alpha = max(alpha, outer_color.a * outer_only);
    }

    // 光晕：仅在形状外部添加柔和光环
    if (glow_strength > 0.0 && glow_size > 0.0) {
        float glow_mask = 1.0 - smoothstep(half_outer + softness, half_outer + glow_size + softness, minDist);
        float glow_outside = glow_mask * (1.0 - fill_mask);
        result += outer_color.rgb * glow_outside * glow_strength;
        alpha = max(alpha, glow_outside * 0.6);
    }

    // 钳制输出范围
    result = clamp(result, vec3(0.0), vec3(1.0));
    alpha = clamp(alpha, 0.0, 1.0);

    COLOR = vec4(result, alpha);
}
