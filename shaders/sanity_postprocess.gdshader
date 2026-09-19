shader_type canvas_item;

// Полноэкранный пост-процессинг шейдер Безумия для "Эхо Чащи" (Godot 4.6-dev)
// Реализует: VHS-помехи, бегущие сканлайны, радиальную хроматическую аберрацию,
// динамическую дисторсию линзы в такт сердцебиению и виньетирование психоза.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;

group_uniforms SanityDynamics;
uniform float sanity_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float heartbeat_pulse : hint_range(0.5, 4.0) = 1.0;
uniform vec4 insanity_tint : source_color = vec4(0.85, 0.15, 0.1, 1.0);

group_uniforms ChromaticAberration;
uniform float aberration_max_spread : hint_range(0.0, 0.05) = 0.018;

group_uniforms VHS_Glitch;
uniform float scanline_density : hint_range(50.0, 800.0) = 380.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float noise_strength : hint_range(0.0, 0.5) = 0.08;
uniform float vhs_jitter_speed : hint_range(0.1, 20.0) = 8.0;

group_uniforms LensDistortion;
uniform float max_lens_distortion : hint_range(0.0, 0.4) = 0.22;
uniform float vignette_falloff : hint_range(0.1, 4.0) = 1.8;


// Высокочастотный псевдослучайный генератор шума
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Процедурная пульсация сердцебиения с резким систолическим пиком и затуханием
float compute_heartbeat(float t, float speed) {
    float cycle = fract(t * speed * 0.8);
    // Двойной импульс сокращения сердечной мышцы (Lub-Dub)
    float beat1 = exp(-28.0 * cycle) * sin(cycle * 35.0);
    float beat2 = exp(-32.0 * max(0.0, cycle - 0.25)) * sin(max(0.0, cycle - 0.25) * 35.0);
    return clamp(beat1 + beat2 * 0.7, 0.0, 1.0);
}

// Искажение координат (Barrel Distortion)
vec2 apply_lens_distortion(vec2 uv, float distortion_amount) {
    vec2 centered = uv - 0.5;
    float r2 = dot(centered, centered);
    vec2 distorted = centered * (1.0 + distortion_amount * r2);
    return distorted + 0.5;
}

void fragment() {
    vec2 uv = SCREEN_UV;
    float time = TIME;

    // 1. Расчет динамики пульса и интенсивности безумия
    float pulse = compute_heartbeat(time, heartbeat_pulse) * sanity_intensity;
    float total_distortion = sanity_intensity * max_lens_distortion + (pulse * 0.08);

    // 2. VHS горизонтальное дрожание строк (Jitter)
    float jitter_noise = hash21(vec2(floor(uv.y * scanline_density), floor(time * vhs_jitter_speed)));
    float glitch_trigger = step(0.97, jitter_noise) * sanity_intensity;
    float horizontal_offset = (jitter_noise - 0.5) * 0.02 * glitch_trigger;
    uv.x += horizontal_offset;

    // 3. Дисторсия линзы
    vec2 distorted_uv = apply_lens_distortion(uv, total_distortion);

    // 4. Радиальная хроматическая аберрация (расхождение цветовых каналов R, G, B)
    vec2 center_offset = distorted_uv - 0.5;
    float dist_from_center = length(center_offset);
    float aberration_amount = dist_from_center * aberration_max_spread * sanity_intensity;

    vec2 uv_r = distorted_uv + (center_offset * aberration_amount * 1.5);
    vec2 uv_g = distorted_uv;
    vec2 uv_b = distorted_uv - (center_offset * aberration_amount * 1.5);

    // Чтение цветовых каналов из текстуры экрана
    float col_r = texture(screen_texture, uv_r).r;
    float col_g = texture(screen_texture, uv_g).g;
    float col_b = texture(screen_texture, uv_b).b;
    vec3 scene_color = vec3(col_r, col_g, col_b);

    // 5. VHS сканлайны (Scanlines)
    float scanline = sin(distorted_uv.y * scanline_density + (time * 4.0)) * 0.5 + 0.5;
    float scanline_factor = 1.0 - (scanline * scanline_intensity * sanity_intensity);
    scene_color *= scanline_factor;

    // 6. Пленочное зерно / статический шум
    float grain = (hash21(distorted_uv * 1000.0 + vec2(time * 12.0, -time * 15.0)) - 0.5) * noise_strength * sanity_intensity;
    scene_color += vec3(grain);

    // 7. Виньетка с эффектом затягивающей тьмы и крови при психозе
    float vignette = smoothstep(0.85, 0.25, dist_from_center * vignette_falloff);
    vec3 blood_vignette_tint = mix(vec3(0.0), insanity_tint.rgb, pulse * 0.8);
    scene_color = mix(blood_vignette_tint, scene_color, vignette);

    // 8. Общее усиление контраста и багрового смещения на пике безумия
    if (sanity_intensity > 0.6) {
        float extreme_factor = (sanity_intensity - 0.6) / 0.4;
        vec3 desaturated = vec3(dot(scene_color, vec3(0.299, 0.587, 0.114)));
        scene_color = mix(scene_color, desaturated * insanity_tint.rgb * 1.4, extreme_factor * 0.45);
    }

    COLOR = vec4(scene_color, 1.0);
}
