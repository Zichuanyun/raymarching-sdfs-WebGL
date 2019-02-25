#version 300 es
precision highp float;

uniform vec3 u_Eye, u_Ref, u_Up;
uniform vec2 u_Dimensions;
uniform float u_Time;

in vec2 fs_Pos;
out vec4 out_Col;

float fov_deg = 90.0;

void main() {
  // float tan_half_fov = tan(radians(fov_deg)/2.0);
  // float half_x = u_Dimensions.x / 2.0;
  // float half_y = u_Dimensions.y / 2.0;
  // float eye_2_center = half_y / tan_half_fov;
  // vec2 screen_plane_coord = (vec2(gl_FragCoord) - 0.5) * 2.0 * u_Dimensions / 2.0;
  // vec3 dir = normalize(vec3(screen_plane_coord, eye_2_center));

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
  vec3 dir = normalize(p_on_screen - u_Eye);

  



  vec3 color = 0.5 * (dir + vec3(1.0));
  out_Col = vec4(0.5 * (fs_Pos + vec2(1.0)), 0.5 * (sin(u_Time * 3.14159 * 0.01) + 1.0), 1.0);
  out_Col = vec4(color, 1.0);


}
