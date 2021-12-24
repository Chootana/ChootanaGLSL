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

#define time fGlobalTime
#define EPS 0.01
#define repeat(p, s) mod(p, s) - 0.5 * s
#define PI acos(-1)
#define TAU 2 * PI

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

vec2 random2D(vec2 st)
{
  st = vec2(
    dot(st, vec2(127.425, 256.123)),
    dot(st, vec2(143.287, 541.232))
  );
  
  return -1.0 * 2.0 * fract(sin(st) * 342213.123);
}

float perlinNoise(vec2 st)
{
  vec2 f = fract(st);
  vec2 p = floor(st);

  vec2 u = f * f * (3.0 - 2.0 * f);
  
  vec2 v00 = random2D(p + vec2(0, 0));
  vec2 v01 = random2D(p + vec2(0, 1));
  vec2 v10 = random2D(p + vec2(1, 0));
  vec2 v11 = random2D(p + vec2(1, 1));
  
  return mix(
    mix(dot(v00, f - vec2(0, 0)), dot(v10, f - vec2(1, 0)), u.x),
    mix(dot(v01, f - vec2(0, 1)), dot(v11, f - vec2(1, 1)), u.x),
    u.y
  );
}

float fBm(vec2 st)
{
  float f = 0;
  float a = 0.5;
  
  vec2 q = 2.0 * st;
  
  for (int i=0; i<4; i++)
  {
    f += a * perlinNoise(q);
    
    q *= 2.0;
    a /= 2.0;
  }
  
  return f;
}

vec3 cosColor(float t, vec3 a, vec3 b, vec3 c, vec3 d)
{
  return a + b * cos(TAU * (c * t + d));
}

float smin(float a, float b, float k)
{
  float res = exp2( - a * k) + exp2( - b * k);
  return - log2(res) / k;
}

mat2 rot(float a)
{
  float c = cos(a);
  float s = sin(a);
  
  return mat2(c, -s, s, c);
}

float sdSphere(vec3 p, vec3 offset, float radius)
{
  return length(p - offset) - radius;
}

float sdBox(vec3 p, vec3 offset, vec3 size)
{
  vec3 q = abs(p - offset) - size;
  return length(max(q, 0)) + min(max(q.x, max(q.y, q.z)), 0.0) - 0.05;
}

vec2 pmod(vec2 p, float n)
{
  float r = TAU / n;
  float a = atan(p.x, p.y) + 0.5 * r;
  
  a = floor(a / r) * r;
  
  return rot(-a) * p;
}

float map(in vec3 p)
{
  
  p.z = repeat(p.z, 4);
  
  float dBox = sdBox(p, vec3(0), vec3(0.2, 0.2, 0.5));
  

  float anim = sin(time) * exp(sin(time));
  float freq = (anim > 0.5) ? 3.0 * time :  floor(time);
  
  p.xy = rot(PI / 3 * freq) * p.xy; 
  p.xy = pmod(p.xy, 8);
  
  float d = sdSphere(p, vec3(0, 2.0, 0), 1.0);
  float d2 = sdSphere(p, vec3(0, 2 + 2.0 * anim, 0), anim);
  
  
  d = smin(d, d2, 20);
  return min(d, dBox);
}


vec3 getNormal(vec3 p)
{
  vec2 e = vec2(0.01, 0.0);
  
  return normalize(vec3(
    map(p + e.xyy),
    map(p + e.yxy),
    map(p + e.yyx)
  ) - map(p));
}

vec3 getRay(vec2 uv, vec3 co, vec3 forward, float focus)
{
  vec3 right = normalize(cross(forward, vec3(0, 1, 0)));
  vec3 up = normalize(cross(right, forward));
  
  focus = focus * ((1.0 - dot(uv, uv)) * 0.3 + 1.0);
  
  return uv.x * right + uv.y * up + focus * forward;
}

void main(void)
{
	vec2 uv = vec2(gl_FragCoord.x / v2Resolution.x, gl_FragCoord.y / v2Resolution.y);
	uv -= 0.5;
	uv /= vec2(v2Resolution.y / v2Resolution.x, 1);
  vec3 col = vec3(0.1);
  
  float r = fBm(uv);
  
  float camRadius = 0.2;
  vec2 offset = vec2(0, 5 - 5 * time);
  float anim = sin(time) * exp(sin(time));
  vec3 co = vec3(camRadius*sin(time), camRadius*cos(time), offset.y);
  vec3 cr = vec3(0, 0, -1);
  float focus = 0.5 + 0.1 * sin(time) * exp(sin(time) * 1.2);;
  
  vec3 ray = getRay(uv, co, cr, focus);
  
  float d;
  float tmp=0;
  vec3 p = co;
  float ac = 0;
  
  vec3 lightDir = normalize(vec3(1, 1, 1));
  
  for (int i=0; i<99; i++)
  {
    d = map(p);
    p = co + tmp * ray;
    
    d = max(abs(d), 0.02);
    ac += exp(-d * 3.0);
    tmp += 0.5 * d + 0.01 * r;
  }
  

  {
    col = cosColor(0.95, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0, 0.33, 0.67));
    col *= 0.02 * clamp(anim, 0.8, 2.00) * ac;
  }
  
	out_color = vec4(col, 1.0);
}