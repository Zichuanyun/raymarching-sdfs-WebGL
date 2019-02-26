#version 300 es
#define MIN_DIS 0.001
#define EPSILON 0.001
#define MAX_ITER 4
precision highp float;

// begin util =================================================
mat4 constructTranslationMat(vec3 t) {
  mat4 mat;
  mat[0][0] = 1.0;
  mat[0][1] = 0.0;
  mat[0][2] = 0.0;
  mat[0][3] = 0.0;

  mat[1][0] = 0.0;
  mat[1][1] = 1.0;
  mat[1][2] = 0.0;
  mat[1][3] = 0.0;

  mat[2][0] = 0.0;
  mat[2][1] = 0.0;
  mat[2][2] = 1.0;
  mat[2][3] = 0.0;

  mat[3][0] = t.x;
  mat[3][1] = t.y;
  mat[3][2] = t.z;
  mat[3][3] = 1.0;
  return mat;
}

mat4 constructScaleMat(vec3 s) {
  mat4 mat;
  mat[0][0] = s.x;
  mat[0][1] = 0.0;
  mat[0][2] = 0.0;
  mat[0][3] = 0.0;

  mat[1][0] = 0.0;
  mat[1][1] = s.y;
  mat[1][2] = 0.0;
  mat[1][3] = 0.0;

  mat[2][0] = 0.0;
  mat[2][1] = 0.0;
  mat[2][2] = s.z;
  mat[2][3] = 0.0;

  mat[3][0] = 0.0;
  mat[3][1] = 0.0;
  mat[3][2] = 0.0;
  mat[3][3] = 1.0;
  return mat;
}

mat4 constructRotationMat(vec3 r) {
  // init
  vec3 R = radians(r);
  mat4 mat_z, mat_y, mat_x;

  // z axis
  mat_z[0][0] = cos(R.z);
  mat_z[0][1] = -sin(R.z);
  mat_z[0][2] = 0.0;
  mat_z[0][3] = 0.0;

  mat_z[1][0] = sin(R.z);
  mat_z[1][1] = cos(R.z);
  mat_z[1][2] = 0.0;
  mat_z[1][3] = 0.0;

  mat_z[2][0] = 0.0;
  mat_z[2][1] = 0.0;
  mat_z[2][2] = 1.0;
  mat_z[2][3] = 0.0;

  mat_z[3][0] = 0.0;
  mat_z[3][1] = 0.0;
  mat_z[3][2] = 0.0;
  mat_z[3][3] = 1.0;

  // y axis
  mat_y[0][0] = cos(R.y);
  mat_y[0][1] = 0.0;
  mat_y[0][2] = sin(R.y);
  mat_y[0][3] = 0.0;

  mat_y[1][0] = 0.0;
  mat_y[1][1] = 1.0;
  mat_y[1][2] = 0.0;
  mat_y[1][3] = 0.0;

  mat_y[2][0] = -sin(R.y);
  mat_y[2][1] = 0.0;
  mat_y[2][2] = cos(R.y);
  mat_y[2][3] = 0.0;

  mat_y[3][0] = 0.0;
  mat_y[3][1] = 0.0;
  mat_y[3][2] = 0.0;
  mat_y[3][3] = 1.0;

  // x axis
  mat_x[0][0] = 1.0;
  mat_x[0][1] = 0.0;
  mat_x[0][2] = 0.0;
  mat_x[0][3] = 0.0;

  mat_x[1][0] = 0.0;
  mat_x[1][1] = cos(R.x);
  mat_x[1][2] = -sin(R.x);
  mat_x[1][3] = 0.0;

  mat_x[2][0] = 0.0;
  mat_x[2][1] = sin(R.x);
  mat_x[2][2] = cos(R.x);
  mat_x[2][3] = 0.0;

  mat_x[3][0] = 0.0;
  mat_x[3][1] = 0.0;
  mat_x[3][2] = 0.0;
  mat_x[3][3] = 1.0;

  return mat_x * mat_y * mat_z;
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
  mat4 inverse_mat = inverse(mat);
  vec3 p_model = vec3(vec4(p, 1.0) * inverse_mat);
  return sdSphereOri(p_model / scale) * scale;
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

in vec2 fs_Pos;
out vec4 out_Col;

float fov_deg = 90.0;

struct Transform {
  vec3 translation;
  float scale;
  mat4 mat;
  // mat4 inverse_mat;
  vec3 rotation;
};

struct SampleSphere {
  Transform transform;
} sample_sphere;

void main() {
  sample_sphere.transform.mat = constructTransformationMat(vec3(0.0, 3.0, 0.0),
                                                 vec3(2.0, 1.0, 1.0), 
                                                 vec3(0.0, 0.0, 0.0));
  sample_sphere.transform.scale = 3.0;

  vec3 Front = normalize(u_Ref - u_Eye);
  vec3 Right = cross(Front, u_Up);
  vec3 Up = cross(Right, Front);
  float aspect = u_Dimensions.x / u_Dimensions.y;
  float tan_half_fov = tan(radians(fov_deg/2.0));
  float len = length(u_Ref - u_Eye);
  vec3 V = Up * len * tan_half_fov;
  vec3 H = Right * len * aspect * tan_half_fov;
  vec2 ndc = (vec2(gl_FragCoord) / u_Dimensions - 0.5) * 2.0; // just fs_Pos
  vec3 p_on_screen = u_Ref + fs_Pos.x * H + fs_Pos.y * V;

  // final output
  vec3 color = vec3(0.7, 0.4, 0.7);

  // 2 crucial things for ray marching
  vec3 dir = normalize(p_on_screen - u_Eye);
  vec3 origin = u_Eye;

  color = (dir + vec3(1.0)) * 0.5;
  
  vec3 normal = vec3(0.5);

  for (int i = 0; i < MAX_ITER; ++i) {
    float march_step = sdSphere(origin,
                                sample_sphere.transform.mat,
                                sample_sphere.transform.scale);
    if (march_step <= MIN_DIS) {
      color = vec3(0.8);
      normal = sdSphereNormal(origin);
      color = (normal + vec3(1.0)) * 0.5;
      break;
    }
    origin = origin + dir * march_step;
  }
  
  
  out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
  out_Col = vec4(color, 1.0);


}
