// https://www.shadertoy.com/view/Nls3Rj

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
#define MAX_DIST 200.0
#define repeat(p, s) mod(p, s) - 0.5 * s
#define PI acos(-1)
#define TAU 2*PI

#define SPHERE 1.0
#define PLANE 0.0

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything


float sdSphere(vec3 p, float radius)
{
  return length(p) - radius;
}

vec2 compSDF(vec2 a, vec2 b)
{
  return a.x < b.x ? a : b;
}

vec2 map(in vec3 p)
{  
  vec2 res = vec2(1e10, 0.0);
  
  res = compSDF(res, vec2(p.y, PLANE));
  res = compSDF(res, vec2(sdSphere(p - vec3(0.5, 0.8, 0), 0.8), SPHERE));
  res = compSDF(res, vec2(sdSphere(p - vec3(-0.8, 0.5, -0.2), 0.5), SPHERE));
 

  
  return res;
}


vec3 getNormal(vec3 p)
{
  vec2 e = vec2(0.01, 0.0);
  
  return normalize(vec3(
    map(p + e.xyy).x,
    map(p + e.yxy).x,
    map(p + e.yyx).x
  ) - map(p).x);
}

float getSoftShadow(vec3 ro, vec3 rd, float k)
{
  float res = 1.0; // hard shadow 
  float d0 = 1e10;
  
  for (float t=0.0; t<MAX_DIST;)
  {
    float d = map(ro + t * rd).x;
    if (d < EPS) return 0.0;
    
    float y = d * d / (2.0 * d0);
    float d_ys = sqrt(d * d - y * y);
    float sh = clamp(k * d_ys / max(0.001, t - y), 0.0, 1.0);
    
    res = min(res, sh * sh * (3.0 - 2.0 * sh));
    d0 = d;
    t += d;
  }
  
  return res;
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
  vec3 col = vec3(0.1);
  
  vec3 co = vec3(0, 1, 3);
  vec3 cr = vec3(0, 0, -1);
  float focus = 1.0;
  
  vec3 ray = getRay(uv, co, cr, focus);
  
  float d;
  float tmp=0;
  float id;
  vec3 p = co;
  
  
  for (int i=0; i<400; i++)
  {
    p = co + tmp * ray;
    vec2 res = map(p);
    d = res.x;
    id = res.y;
    
    if (d < EPS || tmp > MAX_DIST) break;
    
    tmp += d;
   
  }

  tmp = (tmp > MAX_DIST) ? -1.0 : tmp;
  
  vec3 lightDir = normalize(vec3(1, 2, 1));
  vec3 difColor = vec3(7.0, 5.8, 3.6);
  vec3 skyColor = vec3(0.4, 0.6, 0.8);
  vec3 bounceColor = vec3(0.6, 0.3, 0.1);
  
  // Sky
  col = vec3(0.4, 0.6, 0.8) - 0.7 * ray.y;
  
  if (tmp > 0)
  {
    p = co + tmp * ray;
    
    // color 
    vec3 mat = vec3(0);
    mat = (id == PLANE) ? vec3(0.017, 0.02, 0.03) : mat;
    mat = (id == SPHERE) ? vec3(0.18) : mat;
    
    // normal
    vec3 n = getNormal(p);
    
    // shadow 
    float shdw = getSoftShadow(p + n * 2 * EPS, lightDir, 16.0);
 
    
    // diffuse 
    float dif = clamp(dot(lightDir, n), 0.0, 1.0);
    float dif_sky = clamp(0.5 + 0.5 * dot(vec3(0, 1, 0), n), 0.0, 1.0);
    float dif_bounce = clamp(0.2 + 0.2 * dot(vec3(0, -1, 0), n), 0.0, 1.0);
    
    vec3 light_in = vec3(0);
    light_in += difColor * dif * shdw;
    light_in += skyColor * dif_sky;
    light_in += bounceColor * dif_bounce;
    light_in = max(vec3(0.2), light_in);
    
    // specular light 
    vec3 h = normalize(lightDir - ray);
    float spec = pow(max(0.0, dot(h, n)), 128.0);
    
    col = mat * light_in;
    col += mat * spec * shdw;
  }
  
  // gamma
  col = pow(col, vec3(0.4545));
  
	out_color = vec4(col, 1.0);
}