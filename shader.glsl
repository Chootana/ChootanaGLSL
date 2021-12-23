#version 410 core

uniform float fGlobalTime; // in seconds
uniform vec2 v2Resolution; // viewport resolution (in pixels)
uniform float fFrameTime; // duration of the last frame, in seconds

uniform sampler1D texFFT; // towards 0.0 is bass / lower freq, towards 1.0 is higher / treble freq
uniform sampler1D texFFTSmoothed; // this one has longer falloff and less harsh transients
uniform sampler1D texFFTIntegrated; // this is continually increasing
uniform sampler2D texPreviousFrame; // screenshot of the previous frame
uniform sampler2D texChecker;
uniform sampler2D texNoise;
uniform sampler2D texTex1;
uniform sampler2D texTex2;
uniform sampler2D texTex3;
uniform sampler2D texTex4;

#define EPS 0.01

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

vec4 plas( vec2 v, float time )
{
	float c = 0.5 + sin( v.x * 10.0 ) + cos( sin( time + v.y ) * 20.0 );
	return vec4( sin(c * 0.2 + cos(time)), c * 0.15, cos( c * 0.1 + time / .4 ) * .25, 1.0 );
}

vec3 getRay(vec2 uv, vec3 co, vec3 forward, float focus)
{
  vec3 right = normalize(cross(forward, vec3(0, 1, 0)));
  vec3 up = normalize(cross(right, forward));
  
  return uv.x * right + uv.y * up + focus * forward;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	uv -= 0.5;
	uv /= vec2(v2Resolution.y / v2Resolution.x, 1);
  vec3 col = vec3(0.0, 1.0, 0.0);
  
  vec3 co = vec3(0, 0, 3);
  vec3 cr = vec3(0, 0, -1);
  float focus = 1.0;
  
  vec3 ray = getRay(uv, co, cr, focus);
  
  float d;
  float tmp=0;
  vec3 p = co;
  
  for (int i=0; i<99; i++)
  {
    d = length(p) - 0.5;
    tmp += d;
    p = co + tmp * ray;
    if (d < EPS) break;
  }
  
  if (d < EPS)
  {
    col = vec3(1.0);
  }
  
	out_color = vec4(col, 1.0);
}