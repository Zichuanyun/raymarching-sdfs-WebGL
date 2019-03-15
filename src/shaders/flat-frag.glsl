#version 300 es
#define MIN_DIS 0.00001
#define MAX_DIS 100.0
#define EPSILON 0.0001
#define MAX_ITER 350
#define SPECULAR_HARDNESS 10.0
// #define SCALE 3.0
precision highp float;

// begin util =================================================
vec3 opTwist( vec3 p, float amount) // https://www.shadertoy.com/view/Xds3zN
{
    float  c = cos(amount*p.y+amount);
    float  s = sin(amount*p.y+amount);
    mat2   m = mat2(c,-s,s,c);
    return vec3(m*p.xz,p.y);
}

float cubucPulse(float c, float w, float x) {
  x = abs(x - c);
  if(x > w) return 0.0;
  x /= w;
  return 1.0 - x * x * (3.0 - 2.0*x);
}

int square_wave(float x, float freq) {
  return abs(int(floor(x * freq)) % 2);

}

mat4 constructTranslationMat(vec3 t) {
  return mat4(
    1.0, 0.0, 0.0, 0.0, // 1st col
    0.0, 1.0, 0.0, 0.0, // 2nd col
    0.0, 0.0, 1.0, 0.0, // 3rd col
    t.x, t.y, t.z, 1.0  // 4th col
  );
}

mat4 constructRotationMat(vec3 r) {
  // init
  vec3 R = radians(r);
  // Z -> Y -> X
  // inverse: X->Y->Z
  return mat4(
    cos(r.z), -sin(r.z), 0.0, 0.0, // 1st col
    sin(r.z), cos(r.z), 0.0, 0.0,  // 2nd col
    0.0, 0.0, 1.0, 0.0,            // 3rd col
    0.0, 0.0, 0.0, 1.0             // 4th col
  ) * mat4(
    cos(r.y), 0.0, sin(r.y), 0.0,  // 1st col
    0.0, 1.0, 0.0, 0.0,            // 2nd col
    -sin(r.y), 0.0, cos(r.y), 0.0, // 3rd col
    0.0, 0.0, 0.0, 1.0             // 4th col
  ) * mat4(
    1.0, 0.0, 0.0, 0.0,            // 1st col
    0.0, cos(r.x), -sin(r.x), 0.0, // 2nd col
    0.0, sin(r.x), cos(r.x), 0.0,  // 3rd col
    0.0, 0.0, 0.0, 1.0             // 4th col
  );
}

mat4 constructScaleMat(vec3 s) {
  return mat4(
    s.x, 0.0, 0.0, 0.0,            // 1st col
    0.0, s.y, 0.0, 0.0,            // 2nd col
    0.0, 0.0, s.z, 0.0,            // 3rd col
    0.0, 0.0, 0.0, 1.0             // 4th col
  );
}

mat4 constructTransformationMat(vec3 t, vec3 r, vec3 s) {
  return constructTranslationMat(t) * constructRotationMat(r)
  * constructScaleMat(s);
}

mat4 constructInverseTransformationMat(vec3 t, vec3 r, vec3 s) {
  return constructScaleMat(1.0/s) * constructRotationMat(-r)
  * constructTranslationMat(-t);
}

// unit sphere -------------------------------------------------
float sdSphere(vec3 p_world, mat4 inverse_mat) {
  vec3 p = vec3(inverse_mat * vec4(p_world, 1.0));
  return length(p) - 0.5;
}

// unit box
float sdBox(vec3 p_world, mat4 inverse_mat) {
  vec3 p = vec3(inverse_mat * vec4(p_world, 1.0));
  vec3 d = abs(p) - vec3(0.5);
  return length(max(d, 0.0)) + min(max(d.x,max(d.y, d.z)), 0.0);
}

// unit cone -------------------------------------------------
float sdCone(vec3 p_world, mat4 inverse_mat) {
  vec3 p = vec3(inverse_mat * vec4(p_world, 1.0));
  vec2 c = vec2(1, 1);
  float q = length(p.xz);
  return dot(normalize(c), vec2(q, p.y));
}

// SDF untility
float unionSDF(float d1, float d2) {
  return min(d1, d2);
}

float intersectionSDF(float d1, float d2) {
  return max(d1, d2);
}

float subtractSDF(float d1, float d2) {
  return max(d1, -d2);
}

float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b-a) / k, 0.0, 1.0);
  return mix(b, a, h) - k*h*(1.0-h);
}

// fbm related
float random (in vec2 st) {
    return fract(sin(dot(st.xy,
                         vec2(12.9898,78.233)))
                 * 43758.5453123);
}

float valueNoise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    
    vec2 u = smoothstep(0.0, 1.0, f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float layerValueNoise(int layer, vec2 uv) {
    float col = 0.0;
    for (int i = 0; i < layer; ++i) {
    	vec2 st = uv * pow(2.0, float(i));
        col += valueNoise(st) * pow(0.5, float(i) + 1.0);
    }
    return col;
}

float fbm(vec2 p) {
	return layerValueNoise(6, p);
}

float multiFBM(vec2 p) {
	vec2 q = vec2(fbm(p), fbm(p + vec2(5.2,1.3)));
  vec2 r = vec2(fbm(q + p + vec2(4.5, 3.9)), fbm(q + p + vec2(5.2,1.3)));
  return fbm(p + r * 4.0 );
}

// finish util =================================================

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform vec3 u_H;
uniform vec3 u_V;
uniform float u_Twist;
uniform float u_Inter;

in vec2 fs_Pos;
out vec4 out_Col;

float fov_deg = 60.0;

struct UnitSphere {
  mat4 inverse_mat;
};

UnitSphere spheres[16];

struct UnitBox {
  mat4 inverse_mat;
} box, pillar;

struct UnitCone {
  mat4 inverse_mat;
} cone;

float rayMarchScene(vec3 p) {
  float dis = MAX_DIS;
  float d_pillar = sdBox(p, pillar.inverse_mat);
  float d_box = sdBox(opTwist(p, u_Twist), box.inverse_mat);
  dis = smin(d_pillar, d_box, u_Inter);

  float d_sphere = sdSphere(p, spheres[0].inverse_mat);
  dis = subtractSDF(dis, d_sphere);
  
  d_sphere = sdSphere(p, spheres[1].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[2].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[3].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[4].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[5].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[6].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[7].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[8].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[9].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[10].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[11].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  // too small
  // d_sphere = sdSphere(p, spheres[12].inverse_mat);
  // dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[13].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[14].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  d_sphere = sdSphere(p, spheres[15].inverse_mat);
  dis = subtractSDF(dis, d_sphere);

  return dis;
}

vec3 getSceneNormal(vec3 p) {
  float x = rayMarchScene(vec3(p.x + EPSILON, p.y, p.z))
            - rayMarchScene(vec3(p.x - EPSILON, p.y, p.z));
  float y = rayMarchScene(vec3(p.x, p.y + EPSILON, p.z))
            - rayMarchScene(vec3(p.x, p.y - EPSILON, p.z));
  float z = rayMarchScene(vec3(p.x, p.y, p.z + EPSILON))
            - rayMarchScene(vec3(p.x, p.y, p.z - EPSILON));
  return normalize(vec3(x, y, z));
}

void main() {
  float time_in_sec = u_Time / 1000.0;

  vec3 light_dir = vec3(0.5, 0.5, -1.0);
  float light_dir_constant = float(square_wave(time_in_sec, 1.35));
  light_dir.x = light_dir.x * light_dir_constant;
  light_dir = normalize(light_dir);

  // c, w, x
  float box_anim_period = 0.5;
  float box_scale = 4.0 * (1.0 + 0.1 * cubucPulse(0.1, 0.05,
  time_in_sec - floor(time_in_sec / box_anim_period) * box_anim_period));
  box.inverse_mat = constructInverseTransformationMat(
    vec3(0.0, 0.0, 0.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(box_scale)); // s

  pillar.inverse_mat = constructInverseTransformationMat(
    vec3(0.0, -4.0, 0.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.0, 6.0, 1.0)); // s

  // top 
  spheres[0].inverse_mat = constructInverseTransformationMat(
    vec3(0.8, 2.0, 0.8),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.0)); // s

  spheres[1].inverse_mat = constructInverseTransformationMat(
    vec3(-0.8, 2.0, -0.8),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.6)); // s

  spheres[2].inverse_mat = constructInverseTransformationMat(
    vec3(1.0, 2.0, -1.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.3)); // s

  spheres[3].inverse_mat = constructInverseTransformationMat(
    vec3(-1.0, 2.0, 1.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.0)); // s

  // side 1
  spheres[4].inverse_mat = constructInverseTransformationMat(
    vec3(2.0, 0.0, 0.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(3.5)); // s

  // side 2
  spheres[5].inverse_mat = constructInverseTransformationMat(
    vec3(-2.0, 0.9, 0.9),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.9)); // s

  spheres[6].inverse_mat = constructInverseTransformationMat(
    vec3(-2.0, -0.75, -0.75),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(2.2)); // s

  // side 3
  spheres[7].inverse_mat = constructInverseTransformationMat(
    vec3(1.3, 1.1, -2.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.0)); // s

  spheres[8].inverse_mat = constructInverseTransformationMat(
    vec3(0.1, 1.1, -2.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.05)); // s
  
  spheres[9].inverse_mat = constructInverseTransformationMat(
    vec3(-1.2, 1.1, -2.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.1)); // s

  spheres[10].inverse_mat = constructInverseTransformationMat(
    vec3(-1.2, -0.1, -2.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(0.95)); // s

  spheres[11].inverse_mat = constructInverseTransformationMat(
    vec3(0.1, -0.1, -2.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(0.85)); // s

  spheres[12].inverse_mat = constructInverseTransformationMat(
    vec3(1.3, -0.1, -2.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(0.55)); // s

  spheres[13].inverse_mat = constructInverseTransformationMat(
    vec3(1.3, -1.2, -2.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.2)); // s

  spheres[14].inverse_mat = constructInverseTransformationMat(
    vec3(0.1, -1.2, -2.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.05)); // s
  
  spheres[15].inverse_mat = constructInverseTransformationMat(
    vec3(-1.2, -1.2, -2.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(0.8)); // s

  // the following part doesn't cost too much
  // profiling tested
  vec3 Front = normalize(u_Ref - u_Eye);
  vec3 Right = cross(Front, u_Up);
  vec3 Up = cross(Right, Front);
  float aspect = u_Dimensions.x / u_Dimensions.y;
  float tan_half_fov = tan(radians(fov_deg/2.0));
  float len = length(u_Ref - u_Eye);
  vec3 V = Up * len * tan_half_fov;
  vec3 H = Right * len * aspect * tan_half_fov;
  vec3 p_on_screen = u_Ref + fs_Pos.x * H + fs_Pos.y * V;

  // final output
  vec3 color = vec3(0.7, 0.4, 0.7);

  // 2 crucial things for ray marching
  vec3 dir = normalize(p_on_screen - u_Eye);
  vec3 origin = u_Eye;

  color = (dir + vec3(1.0)) * 0.5;
  vec3 normal = vec3(0.5);
  float final_dis = 0.0;
  for (int i = 0; i < MAX_ITER; ++i) {
    float march_step;
    march_step = rayMarchScene(origin);
    final_dis += march_step;
    origin = origin + dir * march_step;
    if (march_step <= MIN_DIS) {
      normal = getSceneNormal(origin);
      normal = normalize(vec3(multiFBM(vec2(normal)), multiFBM(vec2(dir)), 0.0) + normal * 0.7);
      float NdotL = dot(normal, light_dir);
      float diffuse = clamp(0.0, 1.0, NdotL);
      vec3 H = normalize(light_dir - dir);
      float NdotH = dot( normal, H );
      float specular = pow( clamp(0.0, 1.0, NdotH), SPECULAR_HARDNESS);
      color = (normal + 1.0) / 2.0;
      color = vec3(diffuse * 0.5 + specular * 0.5);
      break;
    }
    if (march_step >= MAX_DIS) {
      break;
    }
  }
  
  
  out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
  out_Col = vec4(color, 1.0);


}
