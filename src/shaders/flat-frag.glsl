#version 300 es
#define MIN_DIS 0.00001
#define MAX_DIS 100.0
#define EPSILON 0.0001
#define MAX_ITER 400
precision highp float;

// begin util =================================================
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

// finish util =================================================

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform vec3 u_H;
uniform vec3 u_V;

in vec2 fs_Pos;
out vec4 out_Col;

float fov_deg = 60.0;

struct UnitSphere {
  mat4 inverse_mat;
};

UnitSphere spheres[10];

struct UnitBox {
  mat4 inverse_mat;
} box, pillar;

struct UnitCone {
  mat4 inverse_mat;
} cone;

float rayMarchScene(vec3 p) {
  float dis = MAX_DIS;
  float d_pillar = sdBox(p, pillar.inverse_mat);
  float d_box = sdBox(p, box.inverse_mat);
  dis = smin(d_pillar, d_box, 0.6);

  float d_sphere0 = sdSphere(p, spheres[0].inverse_mat);
  dis = subtractSDF(dis, d_sphere0);
  
  float d_sphere1 = sdSphere(p, spheres[1].inverse_mat);
  dis = subtractSDF(dis, d_sphere1);



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
  box.inverse_mat = constructInverseTransformationMat(
    vec3(0.0, 0.0, 0.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(4.0, 4.0, 4.0)); // s

  pillar.inverse_mat = constructInverseTransformationMat(
    vec3(0.0, -4.0, 0.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.0, 6.0, 1.0)); // s

  // top 
  spheres[0].inverse_mat = constructInverseTransformationMat(
    vec3(0.8, 2.0, 0.8),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(2.0, 2.0, 2.0)); // s

  spheres[1].inverse_mat = constructInverseTransformationMat(
    vec3(-0.2, 0.5, -0.2),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(0.35, 0.35, 0.35)); // s

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

  for (int i = 0; i < MAX_ITER; ++i) {
    float march_step;
    march_step = rayMarchScene(origin);
    origin = origin + dir * march_step;
    if (march_step <= MIN_DIS) {
      color = vec3(0.8);
      normal = getSceneNormal(origin);
      color = (normal + 1.0) / 2.0;
      break;
    }
    if (march_step >= MAX_DIS) {
      break;
    }
  }
  
  
  out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
  out_Col = vec4(color, 1.0);


}
