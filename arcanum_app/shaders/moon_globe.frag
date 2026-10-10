precision highp float;

out vec4 fragColor;

uniform vec2 uSize;
uniform float uPhaseCos;
uniform float uWaxing;
uniform float uYaw;
uniform float uPitch;
uniform sampler2D uColorMap;
uniform sampler2D uHeightMap;

vec2 lunarUv(vec3 normal) {
  float longitude = atan(normal.x, normal.z) * 0.159154943 + 0.5;
  float latitude = asin(clamp(normal.y, -1.0, 1.0)) * 0.318309886;
  return vec2(longitude, 0.5 - latitude);
}

void main() {
  vec2 fragment = gl_FragCoord.xy;
  float radius = min(uSize.x, uSize.y) * 0.46;
  vec2 q = (fragment - uSize * 0.5) / radius;
  float rr = dot(q, q);
  if (rr > 1.0) {
    fragColor = vec4(0.0);
    return;
  }

  float z = sqrt(max(0.0, 1.0 - rr));
  vec3 viewNormal = normalize(vec3(q.x, -q.y, z));
  vec3 surfaceNormal = viewNormal;

  float cp = cos(uPitch);
  float sp = sin(uPitch);
  surfaceNormal = vec3(
    surfaceNormal.x,
    surfaceNormal.y * cp - surfaceNormal.z * sp,
    surfaceNormal.y * sp + surfaceNormal.z * cp
  );
  float cy = cos(uYaw);
  float sy = sin(uYaw);
  surfaceNormal = vec3(
    surfaceNormal.x * cy + surfaceNormal.z * sy,
    surfaceNormal.y,
    -surfaceNormal.x * sy + surfaceNormal.z * cy
  );

  vec2 uv = lunarUv(surfaceNormal);
  vec2 heightTexel = vec2(1.0 / 1024.0, 1.0 / 512.0);
  float heightEast = texture(uHeightMap, uv + vec2(heightTexel.x, 0.0)).r
    - texture(uHeightMap, uv - vec2(heightTexel.x, 0.0)).r;
  float heightNorth = texture(uHeightMap, uv - vec2(0.0, heightTexel.y)).r
    - texture(uHeightMap, uv + vec2(0.0, heightTexel.y)).r;

  vec3 east = normalize(vec3(surfaceNormal.z, 0.0, -surfaceNormal.x));
  vec3 north = normalize(cross(surfaceNormal, east));
  vec3 terrainNormal = normalize(
    surfaceNormal - east * heightEast * 18.0 - north * heightNorth * 18.0
  );

  float phaseSin = sqrt(max(0.0, 1.0 - uPhaseCos * uPhaseCos));
  vec3 light = normalize(vec3(phaseSin * uWaxing, 0.12, uPhaseCos));
  float phaseLight = dot(viewNormal, light);
  float terminator = smoothstep(-0.045, 0.045, phaseLight);
  float terrainLight = 0.34 + 0.66 * max(dot(terrainNormal, light), 0.0);

  vec3 sourceColor = texture(uColorMap, uv).rgb;
  float luminance = dot(sourceColor, vec3(0.2126, 0.7152, 0.0722));
  vec3 monochrome = vec3(luminance);
  vec3 lunarStone = mix(monochrome, sourceColor, 0.23);
  lunarStone *= vec3(0.79, 0.81, 0.87);
  vec3 litStone = lunarStone * terrainLight;
  vec3 shadowStone = vec3(0.018, 0.021, 0.031);
  vec3 stone = mix(shadowStone, litStone, terminator);

  float limb = pow(1.0 - viewNormal.z, 3.0);
  stone += limb * 0.10 * vec3(0.30, 0.38, 0.55);
  float alpha = 1.0 - smoothstep(0.965, 1.0, rr);
  fragColor = vec4(stone, alpha);
}
