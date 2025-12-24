shader_type spatial;

uniform vec3 emission_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 50.0) = 0.0;

void fragment() {
    ALBEDO = vec3(1.0);
    EMISSION = emission_color * emission_strength;
}