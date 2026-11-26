"use client";

import { useEffect, useRef, type RefObject } from "react";
import { applyPainterlyLook } from "@/lib/painterlyLook";

/**
 * The rigged Doberman (Meshy export in .context/.branding, run clip), made web-sized with gltf-transform:
 * `resize --width 1024 --height 1024`, `webp --quality 82`, `meshopt`. 17.2 MB to 0.47 MB.
 */
const MODEL = "/models/doberman-run.glb";

/** Model measurements, in model units: height (ears to toes), body length (nose to tail), toes below the origin. */
const MODEL_HEIGHT = 1.89;
const MODEL_LENGTH = 1.99;
const MODEL_FOOT = 0.94;
/**
 * Ground covered by one run cycle, in body lengths. Measured from the toes in stance: they slide back about
 * 4.5 model units per loop. Driving the clip by this keeps the paws planted while the dog moves.
 */
const STRIDE_BODIES = 4.5 / MODEL_LENGTH;

/** Dog size and place, in units of the sentence's font size. */
const DOG_HEIGHT_EM = 2.5;
const GAP_EM = 0.6;
/** How far the dog turns toward the viewer from a pure side view, in radians. */
const TURN = 0.35;
const RIM_ORANGE = 0xea7600;
const WARM_KEY = 0xffe2c0;
const COOL_FILL = 0x8a9bb0;
const DARK_GROUND = 0x1a120c;

/** The leap after "Automatically.": a perspective scene where z = 0 is the screen plane at 1 px per unit. */
const JUMP_FOV = 35;
/**
 * Dog height on the screen plane, as a share of the viewport height, and the ground, this share below the centre.
 * The ground is high enough that the paws stay on screen when the dog lands close to the lens.
 */
const JUMP_DOG_SHARE = 0.3;
const JUMP_GROUND_SHARE = 0.15;
/**
 * Depths, in camera distances (0 is the word, 1 the lens): the run starts far behind the word, takes off just
 * behind it, lands in front of it, then runs on into the lens.
 */
const JUMP_FAR = -5;
const JUMP_TAKEOFF = -0.3;
const JUMP_LAND = 0.5;
const JUMP_NEAR = 0.85;
/** How the jump progress is shared: run in, leap, run on after landing. */
const JUMP_RUN_END = 0.45;
const JUMP_LAND_AT = 0.75;
/** Apex of the leap above the ground, as a share of the viewport height: enough to clear the word. */
const LEAP_APEX_SHARE = 0.28;
/**
 * The leap replays the run cycle at its own pace: from gathered (legs under the body) to stretched (front legs
 * reaching) on the way up, then on to the end of the cycle, where the front paws reach down to land.
 */
const LEAP_GATHER_S = 0.125;
const LEAP_STRETCH_S = 0.31;
/** Turned slightly off a pure front view; chest up on take-off, nose down on landing (radians). */
const JUMP_TURN = 0.25;
const LEAP_PITCH_UP = -0.35;
const LEAP_PITCH_DOWN = 0.25;

/** Scroll progress of the leap, written by the hero timeline (0 before it starts, 1 at the lens). */
export type JumpProgress = { p: number };

const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const MAX_DPR = 1.5;

/** Width the dog takes ahead of the sentence, in px: the sentence starts this far off screen so the dog enters first. */
export function dogLead(fontPx: number) {
  const lengthEm = (DOG_HEIGHT_EM / MODEL_HEIGHT) * MODEL_LENGTH * Math.cos(TURN);
  return fontPx * (GAP_EM + lengthEm);
}

/**
 * A 3D Doberman that runs ahead of the sliding sentence. Its position and its run cycle are both read from the
 * sentence's position every frame, so scrolling drives the run (scroll back and it runs back). Loads only when
 * motion is allowed, after the page is idle.
 */
export function DogRunner({ line, jump }: { line: RefObject<HTMLElement | null>; jump: RefObject<JumpProgress> }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    let disposed = false;
    let cleanup = () => {};

    const start = async () => {
      const THREE = await import("three");
      const { GLTFLoader } = await import("three/examples/jsm/loaders/GLTFLoader.js");
      const { MeshoptDecoder } = await import("three/examples/jsm/libs/meshopt_decoder.module.js");
      const gltf = await new GLTFLoader().setMeshoptDecoder(MeshoptDecoder).loadAsync(MODEL);
      if (disposed) return;

      const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
      renderer.outputColorSpace = THREE.SRGBColorSpace;
      const scene = new THREE.Scene();
      const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 1, 4000);
      camera.position.z = 2000;
      const lens = new THREE.PerspectiveCamera(JUMP_FOV, 1, 1, 100000);
      let distance = 1; // lens to the screen plane, in px

      // painterly lighting: dim cool fill, strong warm key from the upper left, orange rim from behind
      scene.add(new THREE.HemisphereLight(COOL_FILL, DARK_GROUND, 0.7));
      const key = new THREE.DirectionalLight(WARM_KEY, 3.2);
      key.position.set(-0.6, 0.8, 0.8);
      scene.add(key);
      // orange rim from behind, so the dark dog reads against the black
      const rim = new THREE.DirectionalLight(RIM_ORANGE, 5);
      rim.position.set(-0.6, 0.4, -1);
      scene.add(rim);

      const removeLook = applyPainterlyLook(THREE, gltf.scene);

      const dog = new THREE.Group();
      gltf.scene.rotation.y = -Math.PI / 2 + TURN; // the model faces +z; this faces it left, turned a little to us
      dog.add(gltf.scene);
      scene.add(dog);

      const clip = gltf.animations[0].optimize();
      const mixer = new THREE.AnimationMixer(gltf.scene);
      mixer.clipAction(clip).play();

      let width = 0;
      let height = 0;
      const resize = () => {
        width = canvas.clientWidth;
        height = canvas.clientHeight;
        renderer.setPixelRatio(Math.min(window.devicePixelRatio, width < 768 ? 1 : MAX_DPR));
        renderer.setSize(width, height, false);
        Object.assign(camera, { left: -width / 2, right: width / 2, top: height / 2, bottom: -height / 2 });
        camera.updateProjectionMatrix();
        distance = height / 2 / Math.tan(THREE.MathUtils.degToRad(JUMP_FOV / 2));
        lens.aspect = width / height;
        lens.position.set(0, 0, distance);
        lens.updateProjectionMatrix();
        last = "";
      };
      const ro = new ResizeObserver(resize);
      ro.observe(canvas);

      let last = "";
      let frame = 0;
      let onScreen = false;
      const tick = () => {
        frame = onScreen ? requestAnimationFrame(tick) : 0;
        const el = line.current;
        if (!el || !width) return;
        const rect = el.getBoundingClientRect();
        const canvasRect = canvas.getBoundingClientRect();
        const fontPx = parseFloat(getComputedStyle(el).fontSize);
        const p = jump.current?.p ?? 0;
        const state = `${rect.left.toFixed(1)}|${rect.bottom.toFixed(1)}|${fontPx}|${width}x${height}|${p.toFixed(4)}`;
        if (state === last) return; // nothing moved: skip the render
        last = state;

        if (p > 0) {
          renderLeap(p);
          return;
        }
        canvas.style.zIndex = "2";
        gltf.scene.rotation.y = -Math.PI / 2 + TURN;
        dog.rotation.x = 0;

        const scale = (fontPx * DOG_HEIGHT_EM) / MODEL_HEIGHT;
        const lengthPx = MODEL_LENGTH * scale * Math.cos(TURN);
        const centerX = rect.left - canvasRect.left - fontPx * GAP_EM - lengthPx / 2;
        dog.visible = centerX > -lengthPx && centerX < width + lengthPx;
        if (dog.visible) {
          const baseline = rect.bottom - canvasRect.top - fontPx * 0.12;
          dog.scale.setScalar(scale);
          dog.position.set(centerX - width / 2, height / 2 - baseline + MODEL_FOOT * scale, 0);
          // the run cycle follows the distance travelled, so the paws do not slide
          const cycles = -rect.left / (STRIDE_BODIES * lengthPx);
          mixer.setTime((((cycles % 1) + 1) % 1) * clip.duration);
        }
        renderer.render(scene, camera);
      };
      /** After "Automatically.": the dog runs at us from behind the word, then leaps into the lens. */
      const renderLeap = (p: number) => {
        const scale = (height * JUMP_DOG_SHARE) / MODEL_HEIGHT;
        const ground = -height * JUMP_GROUND_SHARE + MODEL_FOOT * scale;
        gltf.scene.rotation.y = JUMP_TURN; // the model faces +z: toward the lens
        dog.scale.setScalar(scale);
        dog.visible = true;
        const stride = STRIDE_BODIES * MODEL_LENGTH * scale;
        let z: number;
        let y = ground;
        dog.rotation.x = 0;
        if (p < JUMP_RUN_END) {
          // run in from far behind the word; the run cycle follows the ground covered, so the paws stay planted
          z = lerp(JUMP_FAR, JUMP_TAKEOFF, p / JUMP_RUN_END) * distance;
          mixer.setTime((((z - JUMP_FAR * distance) / stride) % 1) * clip.duration);
        } else if (p < JUMP_LAND_AT) {
          // the leap: a parabola over the word, chest up on the way up, nose down on the way down
          const t = (p - JUMP_RUN_END) / (JUMP_LAND_AT - JUMP_RUN_END);
          z = lerp(JUMP_TAKEOFF, JUMP_LAND, t) * distance;
          y = ground + 4 * t * (1 - t) * height * LEAP_APEX_SHARE;
          dog.rotation.x = lerp(LEAP_PITCH_UP, LEAP_PITCH_DOWN, t) * Math.sin(Math.PI * t);
          const s1 = t < 0.5 ? lerp(LEAP_GATHER_S, LEAP_STRETCH_S, t / 0.5) : lerp(LEAP_STRETCH_S, clip.duration, (t - 0.5) / 0.5);
          mixer.setTime(Math.min(s1, clip.duration - 1e-4));
        } else {
          // landed: run on into the lens, the cycle picking up from the landing pose
          z = lerp(JUMP_LAND, JUMP_NEAR, (p - JUMP_LAND_AT) / (1 - JUMP_LAND_AT)) * distance;
          mixer.setTime((((z - JUMP_LAND * distance) / stride) % 1) * clip.duration);
        }
        dog.position.set(0, y, z);
        // behind the word while it is behind the screen plane, in front once it passes
        canvas.style.zIndex = z < 0 ? "0" : "2";
        renderer.render(scene, lens);
      };

      // run the loop only while the canvas is on screen
      const io = new IntersectionObserver(([entry]) => {
        onScreen = entry.isIntersecting;
        if (onScreen && !frame) tick();
      });
      io.observe(canvas);

      cleanup = () => {
        cancelAnimationFrame(frame);
        io.disconnect();
        ro.disconnect();
        mixer.stopAllAction();
        removeLook();
        gltf.scene.traverse((o) => {
          if (o instanceof THREE.Mesh) {
            o.geometry.dispose();
            for (const m of [o.material].flat()) {
              for (const v of Object.values(m)) if (v instanceof THREE.Texture) v.dispose();
              m.dispose();
            }
          }
        });
        renderer.dispose();
      };
    };

    const idle = window.requestIdleCallback
      ? window.requestIdleCallback(() => void start(), { timeout: 2500 })
      : window.setTimeout(() => void start(), 1200);

    return () => {
      disposed = true;
      if (window.cancelIdleCallback) window.cancelIdleCallback(idle);
      else window.clearTimeout(idle);
      cleanup();
    };
  }, [line, jump]);

  return <canvas ref={canvasRef} aria-hidden="true" className="pointer-events-none absolute inset-0 size-full" />;
}
