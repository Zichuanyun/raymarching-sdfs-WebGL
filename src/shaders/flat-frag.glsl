#version 300 es
#define MIN_DIS 0.001
#define EPSILON 0.001
#define MAX_ITER 10
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

mat4 constructTransformationMat(vec3 t, vec3 s, vec3 r) {
  // SDF cannot do free scaling
  return constructTranslationMat(t)
          * constructRotationMat(r);
}

// unit sphere -------------------------------------------------
float sdSphereOri(vec3 p) {
  return length(p) - 1.0;
}

float sdSphere(vec3 p, mat4 mat, float scale) {
  // mat4 inverse_mat = ;
  // vec3 p_model = ;
  return (length(vec3(vec4(p, 1.0) * inverse(mat)) / scale) - 1.0) * scale;
}

vec3 sdSphereNormal(vec3 p) {
  float x = sdSphereOri(vec3(p.x + EPSILON, p.y, p.z))
            - sdSphereOri(vec3(p.x - EPSILON, p.y, p.z));
  float y = sdSphereOri(vec3(p.x, p.y + EPSILON, p.z))
            - sdSphereOri(vec3(p.x, p.y - EPSILON, p.z));
  float z = sdSphereOri(vec3(p.x, p.y, p.z + EPSILON))
            - sdSphereOri(vec3(p.x, p.y, p.z - EPSILON));
  return normalize(vec3(x, y, z));
}

// cone -------------------------------------------------

// finish util =================================================

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;
uniform vec3 u_H;
uniform vec3 u_V;

in vec2 fs_Pos;
out vec4 out_Col;

float fov_deg = 90.0;

struct Transform {
  vec3 translation;
  float scale;
  mat4 mat;
  mat4 inverse_mat;
  vec3 rotation;
};

struct SampleSphere {
  Transform transform;
} sample_sphere;

void main() {
  sample_sphere.transform.mat = constructTransformationMat(vec3(0.0, 3.0, 0.0),
                                                 vec3(2.0, 1.0, 1.0), 
                                                 vec3(0.0, 0.0, 0.0));
  // sample_sphere.transform.inverse_mat = inverse(sample_sphere.transform.mat);                                   
  sample_sphere.transform.scale = 3.0;

  
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
    // march_step = sdSphereOri(origin);
    march_step = sdSphere(origin,
                                sample_sphere.transform.mat,
                                sample_sphere.transform.scale);
    if (march_step <= MIN_DIS) {
      color = vec3(0.8);
      // normal = sdSphereNormal(origin);
      color = (normal + vec3(1.0)) * 0.5;
      break;
    }
    origin = origin + dir * march_step;
  }
  
  
  out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
  out_Col = vec4(color, 1.0);


}
