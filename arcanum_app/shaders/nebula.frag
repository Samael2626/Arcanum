precision mediump float;

uniform vec2 uSize;
uniform float uTime;

// Procedural Perlin-like noise
float noise(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float fbm(vec2 p) {
  float value = 0.0;
  float amp = 0.5;
  float freq = 1.0;
  for (int i = 0; i < 4; i++) {
    value += amp * noise(p * freq);
    p *= 2.0;
    amp *= 0.5;
    freq *= 2.0;
  }
  return value;
}

void main() {
  vec2 uv = gl_FragCoord.xy / uSize;

  // Desplazamiento por tiempo
  vec2 q = vec2(fbm(uv + 0.00 * uTime), fbm(uv + vec2(1.0)));
  vec2 r = vec2(fbm(uv + 1.0 * q + vec2(1.7, 9.2) + 0.15 * uTime),
                 fbm(uv + 1.0 * q + vec2(8.3, 2.8) + 0.126 * uTime));
  float f = fbm(uv + r);

  // Colores nebulosa (púrpura/dorado/azul)
  vec3 color = mix(
    vec3(0.1, 0.0, 0.2),  // púrpura oscuro
    vec3(1.0, 0.7, 0.2),  // dorado
    f
  );

  // Pulsing glow
  float pulse = 0.5 + 0.5 * sin(uTime * 0.5);
  color += vec3(0.3, 0.1, 0.5) * pulse * f;

  // Estrellas puntuales
  float stars = step(0.98, noise(uv * 50.0));
  color += vec3(1.0) * stars * 0.3;

  gl_FragColor = vec4(color, 1.0);
}
