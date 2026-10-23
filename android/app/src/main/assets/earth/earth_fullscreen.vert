// The fullscreen triangle every Earth pass draws — iOS `earthFullscreenVertex`.
//
// Attributeless: `glDrawArrays(GL_TRIANGLES, 0, 3)` with an empty VAO bound.
// One oversized triangle covers NDC [-1, 1]^2; `vNdc` carries the clip-space
// position to the fragment stage, where the surface pass rebuilds its rays
// from it and the post passes derive their texture coordinates.
//
// The prelude (`#version 300 es`, precision) is prepended by EarthShaders.kt.

out vec2 vNdc;

void main() {
  vec2 positions[3] = vec2[3](
    vec2(-1.0, -3.0),
    vec2(-1.0,  1.0),
    vec2( 3.0,  1.0)
  );
  vec2 p = positions[gl_VertexID];
  vNdc = p;
  gl_Position = vec4(p, 0.0, 1.0);
}
