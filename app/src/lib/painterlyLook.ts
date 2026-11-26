import type * as T from "three";

type Three = typeof import("three");

/**
 * A painterly, Arcane-inspired look for the 3D Doberman: hard-edged toon shading with ragged band edges and an
 * uneven warm outline. Inspired by, not a copy of, Fortiche's render. Non-destructive: the model's own albedo map
 * is reused, and each layer can be switched off here for a before/after comparison.
 */
export const PAINTERLY = {
  toon: true,
  /** Light steps of the toon ramp (0-255): shade falls in hard-edged blocks, not gradients. */
  bands: [26, 78, 158, 255],
  /** Ragged band edges: how far noise shifts the light threshold (in N·L units), and the noise frequency per model unit. */
  ragged: 0.22,
  raggedScale: 9,
  outline: true,
  /** Outline: width in model units (the dog is about 1.9 tall), how much noise thins it (1 lets it vanish), colour. */
  outlineWidth: 0.012,
  outlineNoise: 0.85,
  outlineNoiseScale: 6,
  outlineColor: 0x2a160b,
};

/** 3D value noise, sampled on the rest-pose surface so the pattern sticks to the dog while it moves. */
const NOISE_GLSL = /* glsl */ `
float paintHash(vec3 p) {
  p = fract(p * 0.3183099 + 0.1);
  p *= 17.0;
  return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float paintNoise(vec3 x) {
  vec3 i = floor(x);
  vec3 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(mix(paintHash(i), paintHash(i + vec3(1, 0, 0)), f.x), mix(paintHash(i + vec3(0, 1, 0)), paintHash(i + vec3(1, 1, 0)), f.x), f.y),
    mix(mix(paintHash(i + vec3(0, 0, 1)), paintHash(i + vec3(1, 0, 1)), f.x), mix(paintHash(i + vec3(0, 1, 1)), paintHash(i + vec3(1, 1, 1)), f.x), f.y),
    f.z
  );
}
`;

/** Toon material on the original albedo map, with noise on the band threshold. */
function toonMaterial(THREE: Three, source: T.MeshStandardMaterial) {
  const ramp = new THREE.DataTexture(new Uint8Array(PAINTERLY.bands), PAINTERLY.bands.length, 1, THREE.RedFormat);
  ramp.minFilter = THREE.NearestFilter;
  ramp.magFilter = THREE.NearestFilter;
  ramp.needsUpdate = true;

  const material = new THREE.MeshToonMaterial({ map: source.map, gradientMap: ramp, side: source.side });
  material.onBeforeCompile = (shader) => {
    shader.uniforms.uRagged = { value: PAINTERLY.ragged };
    shader.uniforms.uRaggedScale = { value: PAINTERLY.raggedScale };
    shader.vertexShader = `varying vec3 vPaintPos;\n${shader.vertexShader}`.replace(
      "#include <begin_vertex>",
      "#include <begin_vertex>\nvPaintPos = position;",
    );
    shader.fragmentShader = `varying vec3 vPaintPos;\nuniform float uRagged;\nuniform float uRaggedScale;\n${NOISE_GLSL}\n${shader.fragmentShader}`.replace(
      "#include <gradientmap_pars_fragment>",
      THREE.ShaderChunk.gradientmap_pars_fragment.replace(
        "vec2 coord = vec2( dotNL * 0.5 + 0.5, 0.0 );",
        "vec2 coord = vec2( dotNL * 0.5 + 0.5 + ( paintNoise( vPaintPos * uRaggedScale ) - 0.5 ) * uRagged, 0.0 );",
      ),
    );
  };
  return { material, ramp };
}

/** Inverted-hull outline: the back faces pushed out along the skinned normal, thinned by noise. */
function outlineMaterial(THREE: Three) {
  const material = new THREE.MeshBasicMaterial({ color: PAINTERLY.outlineColor, side: THREE.BackSide });
  material.onBeforeCompile = (shader) => {
    shader.uniforms.uWidth = { value: PAINTERLY.outlineWidth };
    shader.uniforms.uNoise = { value: PAINTERLY.outlineNoise };
    shader.uniforms.uNoiseScale = { value: PAINTERLY.outlineNoiseScale };
    shader.vertexShader = `uniform float uWidth;\nuniform float uNoise;\nuniform float uNoiseScale;\n${NOISE_GLSL}\n${shader.vertexShader}`.replace(
      "#include <skinning_vertex>",
      `#include <skinning_vertex>
      float paintWeight = clamp(1.0 - uNoise * paintNoise(position * uNoiseScale) * 1.4, 0.0, 1.0);
      transformed += normalize(objectNormal) * uWidth * paintWeight;`,
    );
  };
  return material;
}

/**
 * Applies the look to every skinned mesh under `root`. Returns a function that removes the outline hulls, restores
 * the original materials and frees what it created.
 */
export function applyPainterlyLook(THREE: Three, root: T.Object3D) {
  const meshes: T.SkinnedMesh[] = [];
  root.traverse((o) => {
    if ((o as T.SkinnedMesh).isSkinnedMesh) meshes.push(o as T.SkinnedMesh);
  });

  const undo: (() => void)[] = [];
  for (const mesh of meshes) {
    const original = mesh.material as T.MeshStandardMaterial;
    if (PAINTERLY.toon) {
      const { material, ramp } = toonMaterial(THREE, original);
      mesh.material = material;
      undo.push(() => {
        mesh.material = original;
        material.dispose();
        ramp.dispose();
      });
    }
    if (PAINTERLY.outline && mesh.parent) {
      const material = outlineMaterial(THREE);
      const hull = new THREE.SkinnedMesh(mesh.geometry, material);
      hull.bind(mesh.skeleton, mesh.bindMatrix);
      hull.position.copy(mesh.position);
      hull.quaternion.copy(mesh.quaternion);
      hull.scale.copy(mesh.scale);
      hull.frustumCulled = false;
      mesh.parent.add(hull);
      undo.push(() => {
        hull.removeFromParent();
        material.dispose();
      });
    }
  }
  return () => undo.forEach((fn) => fn());
}
