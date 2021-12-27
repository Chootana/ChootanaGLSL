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
#define repeat(p, s) mod(p, s) - 0.5 * s
#define MAX_DIST 100
#define time fGlobalTime

layout(location = 0) out vec4 out_color; // out_color must be written in order to see anything

vec4 plas( vec2 v, float time )
{
	float c = 0.5 + sin( v.x * 10.0 ) + cos( sin( time + v.y ) * 20.0 );
	return vec4( sin(c * 0.2 + cos(time)), c * 0.15, cos( c * 0.1 + time / .4 ) * .25, 1.0 );
}

float sdSphere(vec3 p, float radius)
{
  return length(p) - radius;
}

float sdPlane(vec3 p) 
{
  return p.y;
}

float sdBox(vec3 p, vec3 s)
{
  vec3 q = abs(p) - s;
  return length(max(q, 0.0)) + min(max(max(q.x, q.y), q.z), 0.0);
}

float map(in vec3 p)
{
  // p = repeat(p, 4);
  vec3 q = p;
  q.x = repeat(q.x, 2);
  float d = sdSphere(q - vec3(0, 0.5, 0), 0.5);
  float dBox = sdBox(p - vec3(0, 0.25, 0), vec3(0.2, 0.5, 0.2));
  float dPlane = sdPlane(p);
  
  return min(d, dPlane);
}

float getSoftShadow(vec3 ro, vec3 rd, float k)
{
  float res = 1.0;
  float ph = 1e10;
  
  for (float t=0.01; t<MAX_DIST;)
  {
    float h = map(ro + t * rd);
    res = min(res, 10.0 * h / t);
    if (h < 0.001 || t > MAX_DIST) return 0.0;
    t += h;
  }
  
  res = clamp(res, 0.0, 1.0);
  return res * res * (3.0 - 2.0 * res);
}


vec3 getNormal(vec3 p)
{
  vec2 e = vec2(0.1, 0.0);
  
  return normalize(vec3(
    map(p + e.xyy) - map(p),
    map(p + e.yxy) - map(p),
    map(p + e.yyx) - map(p)
  ));
  
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
  vec3 col = vec3(0.0);
  
  vec3 co = vec3(-1, 2, 5);
  vec3 cr = vec3(0.5, -0.2, -1);
  float focus = 1.0;
  
  vec3 ray = getRay(uv, co, cr, focus);
  
  float d;
  float t = 0.0;
  vec3 p = co;
  
  vec3 lightDir = normalize(vec3(1, 1, 1));
  
  for (int i=0; i<100; i++)
  {
    p = co + t * ray;
    d = map(p);
    
    if (d < EPS || t > MAX_DIST) break;
    
    t += d;
  }
  
  t = (t > MAX_DIST) ? -1.0 : t;
  
  if (t > 0.0)
  {
    p = co + t * ray;
    vec3 n = getNormal(p);
    
    float diff = max(dot(n, lightDir), 0.0);
    diff = clamp(diff, 0.2, 1.0);

    float shdw = getSoftShadow(p + 0.1 * n, lightDir, 1);
    col = vec3(0.3) * diff * vec3(1.0, 0.7, 0.5) * shdw;
    
    // fog
    col *= exp( - 0.001 * t * t * t);
  }
  
  // gamma
  col = pow(col, vec3(0.4545));
  
	out_color = vec4(col, 1.0);
}