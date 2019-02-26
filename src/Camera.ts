var CameraControls = require('3d-view-controls');
import {vec3, mat4} from 'gl-matrix';
// import { cross, subtract, normalize } from 'gl-vec3';

class Camera {
  controls: any;
  projectionMatrix: mat4 = mat4.create();
  viewMatrix: mat4 = mat4.create();
  fovy: number = 45;
  aspectRatio: number = 1;
  near: number = 0.1;
  far: number = 1000;
  position: vec3 = vec3.create();
  direction: vec3 = vec3.create();
  target: vec3 = vec3.create();
  up: vec3 = vec3.create();
  H: vec3 = vec3.create();
  V: vec3 = vec3.create();
  camFront: vec3 = vec3.create();
  camUp: vec3 = vec3.create();
  camRight: vec3 = vec3.create();
  


  constructor(position: vec3, target: vec3) {
    this.controls = CameraControls(document.getElementById('canvas'), {
      eye: position,
      center: target,
    });
    vec3.add(this.target, this.position, this.direction);
    mat4.lookAt(this.viewMatrix, this.controls.eye, this.controls.center, this.controls.up);
  }

  setAspectRatio(aspectRatio: number) {
    this.aspectRatio = aspectRatio;
  }

  updateProjectionMatrix() {
    mat4.perspective(this.projectionMatrix, this.fovy, this.aspectRatio, this.near, this.far);
  }

  update() {
    this.controls.tick();
    vec3.add(this.target, this.position, this.direction);
    mat4.lookAt(this.viewMatrix, this.controls.eye, this.controls.center, this.controls.up);

    // vec3 Front = normalize(u_Ref - u_Eye);
    // vec3 Right = cross(Front, u_Up);
    // vec3 Up = cross(Right, Front);
    // float aspect = u_Dimensions.x / u_Dimensions.y;
    // float tan_half_fov = tan(radians(fov_deg/2.0));
    // float len = length(u_Ref - u_Eye);
    // vec3 V = Up * len * tan_half_fov;
    // vec3 H = Right * len * aspect * tan_half_fov;

    // let Front: vec3 = vec3.create();
    // vec3.subtract(Front, this.controls.center, this.controls.eyes);
    // vec3.normalize(Front, Front);

    // let Right: vec3;
    // vec3.cross(Right, Front, this.controls.up);
    // vec3.normalize(Right, Right);

    // let Up: vec3;
    // vec3.cross(Up, Right, Front);
    // vec3.normalize(Up, Up);
    
    // let Len: number = vec3.distance(this.controls.center, this.controls.eyes);
    // let Tan_half_fov: number = Math.tan(this.fovy * Math.PI/180);

    // vec3.scale(this.V, Up, Len * Tan_half_fov);
    // vec3.scale(this.H, Right, Len * Tan_half_fov * this.aspectRatio);
  }
};

export default Camera;
