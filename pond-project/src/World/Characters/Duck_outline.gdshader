shader_type canvas_item;
 
uniform bool enable;
uniform float width : hint_range(0.0, 16.0);
uniform vec4 outline_color : hint_color;

vec4 calculate_outline(sampler2D p_TEX, vec2 p_UV, vec4 p_sprite_color, vec4 p_outline_color, float p_width)
{
	vec2 size = vec2(p_width) / vec2(textureSize(p_TEX, 0));
   
    float alpha = p_sprite_color.a;
    alpha += texture(p_TEX, p_UV + vec2(0.0, -size.y)).a;
    alpha += texture(p_TEX, p_UV + vec2(size.x, -size.y)).a;
    alpha += texture(p_TEX, p_UV + vec2(size.x, 0.0)).a;
    alpha += texture(p_TEX, p_UV + vec2(size.x, size.y)).a;
    alpha += texture(p_TEX, p_UV + vec2(0.0, size.y)).a;
    alpha += texture(p_TEX, p_UV + vec2(-size.x, size.y)).a;
    alpha += texture(p_TEX, p_UV + vec2(-size.x, 0.0)).a;
    alpha += texture(p_TEX, p_UV + vec2(-size.x, -size.y)).a;
   
    vec3 final_color = mix(p_outline_color.rgb, p_sprite_color.rgb, p_sprite_color.a);
	return vec4(final_color, clamp(alpha, 0.0, 1.0));
}

void fragment()
{
    vec4 sprite_color = texture(TEXTURE, UV);
    
	if (enable)
	{
		vec4 partial_color = calculate_outline(TEXTURE, UV, sprite_color, vec4(0.3,0.3,0.3,1), 1);
		partial_color = calculate_outline(TEXTURE, UV, partial_color, outline_color, width);
		partial_color = calculate_outline(TEXTURE, UV, partial_color, vec4(0.3,0.3,0.3,1), width+1.);
		COLOR = partial_color;
	}
	else
		COLOR = sprite_color;
}