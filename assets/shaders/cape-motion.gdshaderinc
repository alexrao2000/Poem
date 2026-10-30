// Local cape coordinates run from a fixed shoulder (y=0) to the hem (y~-1).
// Actor-owned clocks freeze with hit stop. Both fabric and outline use this
// displacement and its inverse-transpose Jacobian for consistent silhouettes.
uniform float cloth_amount = 0.0;
uniform float cloth_clock = 0.0;
uniform float cloth_drive = 0.0;

vec3 cape_position(vec3 point) {
 float d = clamp(-point.y, 0.0, 1.0);
 float phase = cloth_clock * 4.1 + point.x * 5.0 + d * 3.0;
 float side = cloth_clock * 2.2 + d * 2.8;
 float amplitude = 0.012 + 0.025 * cloth_drive;
 return point + cloth_amount * vec3(sin(side) * d * d * 0.012, 0.0,
   sin(phase) * d * d * amplitude + cloth_drive * d * d * 0.04);
}

vec3 cape_normal(vec3 point, vec3 normal) {
 float d = clamp(-point.y, 0.0, 1.0);
 float phase = cloth_clock * 4.1 + point.x * 5.0 + d * 3.0;
 float side = cloth_clock * 2.2 + d * 2.8;
 float amplitude = 0.012 + 0.025 * cloth_drive;
 float slope_gate = (point.y < 0.0 && point.y > -1.0) ? 1.0 : 0.0;
 float dxdy = -cloth_amount * slope_gate * 0.012 * (cos(side) * 2.8 * d * d + sin(side) * 2.0 * d);
 float dzdx = cloth_amount * cos(phase) * 5.0 * d * d * amplitude;
 float dzdy = -cloth_amount * slope_gate * ((cos(phase) * 3.0 * d * d + sin(phase) * 2.0 * d) * amplitude + cloth_drive * 0.08 * d);
 float nx = normal.x - dzdx * normal.z;
 return normalize(vec3(nx, normal.y - dxdy * nx - dzdy * normal.z, normal.z));
}
