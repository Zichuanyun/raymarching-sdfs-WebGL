#version 300 es
#define MIN_DIS 0.0001
#define MAX_DIS 1000.0
#define EPSILON 0.001
#define MAX_ITER 40
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

  // return mat4(
  //   1.0, 0.0, 0.0, 0.0,            // 1st col
  //   0.0, 1.0, 0.0, 0.0,            // 2nd col
  //   0.0, 0.0, 1.0, 0.0,            // 3rd col
  //   0.0, 0.0, 0.0, 1.0             // 4th col
  // );
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
float sdSphereOri(vec3 p) {
  return length(p) - 0.5;
}

float sdSphere(vec3 p, mat4 inverse_mat) {
  vec3 p_model = vec3(inverse_mat * vec4(p, 1.0));
  return sdSphereOri(p_model);
}

vec3 sdSphereNormal(vec3 p, mat4 inverse_mat) {
  float x = sdSphere(vec3(p.x + EPSILON, p.y, p.z), inverse_mat)
            - sdSphere(vec3(p.x - EPSILON, p.y, p.z), inverse_mat);
  float y = sdSphere(vec3(p.x, p.y + EPSILON, p.z), inverse_mat)
            - sdSphere(vec3(p.x, p.y - EPSILON, p.z), inverse_mat);
  float z = sdSphere(vec3(p.x, p.y, p.z + EPSILON), inverse_mat)
            - sdSphere(vec3(p.x, p.y, p.z - EPSILON), inverse_mat);
  return normalize(vec3(x, y, z));
}

// unit box -------------------------------------------------
float sdBoxOri(vec3 p) {
  vec3 d = abs(p) - vec3(0.5);
  return length(max(d, 0.0)) + min(max(d.x,max(d.y,d.z)),0.0);
}

float sdBox(vec3 p, mat4 inverse_mat) {
  vec3 p_model = vec3(inverse_mat * vec4(p, 1.0));
  return sdBoxOri(p_model);
}

vec3 sdBoxNormal(vec3 p, mat4 inverse_mat) {
  float x = sdBox(vec3(p.x + EPSILON, p.y, p.z), inverse_mat)
            - sdBox(vec3(p.x - EPSILON, p.y, p.z), inverse_mat);
  float y = sdBox(vec3(p.x, p.y + EPSILON, p.z), inverse_mat)
            - sdBox(vec3(p.x, p.y - EPSILON, p.z), inverse_mat);
  float z = sdBox(vec3(p.x, p.y, p.z + EPSILON), inverse_mat)
            - sdBox(vec3(p.x, p.y, p.z - EPSILON), inverse_mat);
  return normalize(vec3(x, y, z));
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
} sample_sphere;

struct UnitBox {
  mat4 inverse_mat;
} sample_box;

void main() {
  sample_sphere.inverse_mat = constructInverseTransformationMat(
    vec3(0.0, 0.0, 0.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(1.0, 1.0, 2.0)); // s

  sample_box.inverse_mat = constructInverseTransformationMat(
    vec3(0.0, 0.0, 0.0),  // t
    vec3(0.0, 0.0, 0.0),  // r
    vec3(3.0, 2.0, 1.0)); // s
  
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
    // march_step = sdBox(origin, sample_box.inverse_mat);
    march_step = sdSphere(origin, sample_sphere.inverse_mat);

    if (march_step <= MIN_DIS) {
      color = vec3(0.8);
      // normal = sdBoxNormal(origin, sample_box.inverse_mat);
      normal = sdSphereNormal(origin, sample_sphere.inverse_mat);

      color = (normal + vec3(1.0)) * 0.5;
      break;
    }
    origin = origin + dir * march_step;
  }
  
  
  out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
  out_Col = vec4(color, 1.0);


}
