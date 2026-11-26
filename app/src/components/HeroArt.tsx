"use client";

import { useSyncExternalStore, type CSSProperties } from "react";
import Image from "next/image";
import { ShaderFill, useWebGPUDevice, type Shader } from "@figma/expressive-components";
import * as clouds from "@/lib/custom-effects/CodeComponentId_d56ec91cd4391861fc67e6ba0236e8768d38a728_8340";

/** Design units of the 1920 x 1080 Figma frame ("Desktop - 1"), in container units of the stage. */
export const u = (n: number) => `${n / 19.2}cqw`;

/** Tops of the tagline lines in the design (px), first line first. Figma's "normal" leading puts the glyphs about 0.1 em lower. */
const LINE_TOPS = [709 + 10, 804 + 10];

/** Place a layer at its Figma position and size (design px). */
const at = (left: number, top: number, width: number, height: number): CSSProperties => ({
  left: u(left),
  top: u(top),
  width: u(width),
  height: u(height),
});

/** Figma's "Phase" of the clouds (evolution, 0-100) and how fast it moves on, per second: a slow change of shape. */
const SKY_PHASE = 49;
const SKY_MORPH_PER_S = 0.02;
/** How fast the clouds pan sideways, in the shader's transform x (%) per second: about 10 px/s on a 1080p screen. */
const SKY_WIND_PER_S = 1.5;
/** The sky is drawn at this share of its size and scaled up: the clouds are soft, so it costs about an eighth of the pixels. */
const SKY_RES = 0.35;
/** Past this much scroll (in viewport heights) the hero has zoomed into the dark: the sky is not drawn any more. */
const SKY_GONE_VIEWPORTS = 2.2;

/** The Figma "Clouds" fill on the sky (node 10:3), with its exact parameters. */
const SKY_PARAMS = {
  warpScale: 28,
  globalTransform: { x: 50, y: 50, radius: 48, angle: 0 },
  coverage: 30,
  warpAmount: 68,
  globalDetail: 43,
  cloudColor: { r: 0.9290000200271606, g: 0.9729999899864197, b: 1, a: 1 },
  stretch: 46,
  shadingVariation: 63,
  density: 26,
  cloudShadowColor: { r: 0.5210232734680176, g: 0.7299797534942627, b: 0.9647435545921326, a: 1 },
  brightness: 25,
  skyColor: {
    stops: [
      { position: 0, color: { r: 0.2084873616695404, g: 0.3541489541530609, b: 0.6346153616905212, a: 1 } },
      { position: 1, color: { r: 0.32899999618530273, g: 0.5879999995231628, b: 0.7960000038146973, a: 1 } },
    ],
  },
  evolution: SKY_PHASE,
};
/** Still, as in Figma (reduced motion). Shader objects stay at module scope so the runtime never sets up again. */
const SKY: Shader = { setup: clouds.setup, render: clouds.render, manifest: clouds.manifest, params: SKY_PARAMS };
/**
 * Drifting: the same shader, marked animated so the runtime repaints every frame. The clouds pan with the wind and
 * slowly change shape. The runtime reads `params` on every render, so getters are enough; the Figma module stays
 * untouched.
 */
const SKY_DRIFT: Shader = {
  setup: clouds.setup,
  render: clouds.render,
  manifest: { ...clouds.manifest, isAnimated: true },
  params: {
    ...SKY_PARAMS,
    get globalTransform() {
      return {
        ...SKY_PARAMS.globalTransform,
        x: SKY_PARAMS.globalTransform.x - (performance.now() / 1000) * SKY_WIND_PER_S,
      };
    },
    get evolution() {
      return SKY_PHASE + (performance.now() / 1000) * SKY_MORPH_PER_S;
    },
  },
};

/**
 * A layer exported from Figma with its shader already applied (dither, chrome metal, stretch). Those shaders need
 * HTML-in-Canvas, which ships only behind a Chrome flag, so they are baked into images. Exports are cut at the frame
 * edge, so each sits where its visible part starts. Not resized by next/image: resampling would smear the dither.
 */
function Baked({ src, box }: { src: string; box: [left: number, top: number, width: number, height: number] }) {
  return (
    <Image
      src={src}
      alt=""
      width={box[2]}
      height={box[3]}
      unoptimized
      loading="eager"
      className="absolute max-w-none"
      style={at(...box)}
    />
  );
}

const noSubscribe = () => () => {};
const REDUCED = "(prefers-reduced-motion: reduce)";
const onMotionChange = (fn: () => void) => {
  const mq = window.matchMedia(REDUCED);
  mq.addEventListener("change", fn);
  return () => mq.removeEventListener("change", fn);
};
const onScroll = (fn: () => void) => {
  window.addEventListener("scroll", fn, { passive: true });
  window.addEventListener("resize", fn);
  return () => {
    window.removeEventListener("scroll", fn);
    window.removeEventListener("resize", fn);
  };
};

/**
 * The live cloud fill with the design's 20% shade, inside the white frame; shown once the GPU device is ready. It
 * drifts unless motion is reduced, and is taken down once the hero has scrolled into the dark, so it never draws
 * frames nobody sees (the baked sky under it is what shows if it is put back late).
 */
function LiveSky() {
  const { device } = useWebGPUDevice();
  const still = useSyncExternalStore(
    onMotionChange,
    () => window.matchMedia(REDUCED).matches,
    () => true,
  );
  const inView = useSyncExternalStore(
    onScroll,
    () => window.scrollY < window.innerHeight * SKY_GONE_VIEWPORTS,
    () => true,
  );
  if (!device || !inView) return null;
  return (
    <div className="absolute inset-0 overflow-hidden border-solid border-white" style={{ borderWidth: u(11.88) }}>
      <ShaderFill
        shader={still ? SKY : SKY_DRIFT}
        className="absolute left-0 top-0 origin-top-left"
        style={{ width: `${SKY_RES * 100}%`, height: `${SKY_RES * 100}%`, scale: 1 / SKY_RES }}
      />
      <div className="absolute inset-0 bg-black/20" />
    </div>
  );
}

/**
 * The hero art from Figma (file "Untitled", frame "Desktop - 1"), layer for layer in the design's order. The sky is
 * the live Figma cloud shader where WebGPU is available; elsewhere (and until the GPU is ready) it is the baked
 * export, which also carries the dither. Text stays real text.
 */
export function HeroArt({ lines }: { lines: string[] }) {
  // asked only where the browser has WebGPU at all, so others do not log a failed device request
  const hasGpu = useSyncExternalStore(
    noSubscribe,
    () => "gpu" in navigator && !!navigator.gpu,
    () => false,
  );

  return (
    <>
      {/* 10:3 sky: baked (cloud fill + dither + 20% shade + white frame) */}
      <Baked src="/img/hero/sky.webp" box={[0, 0, 1920, 1080]} />
      {hasGpu && <LiveSky />}

      {/* 15:2 birds, small and soft, far away */}
      <div className="absolute blur-[2px]" style={at(369, 30, 372.364, 180)}>
        <Image src="/img/hero/birds.webp" alt="" fill sizes="20vw" className="object-contain" />
      </div>
      {/* 10:120 chrome card (with its drop shadow) */}
      <Baked src="/img/hero/card.webp" box={[86, 316, 1776, 730]} />
      {/* 9:2 Doberman, stretched into motion streaks */}
      <Baked src="/img/hero/dog-stretch.webp" box={[197, 0, 1608, 1033]} />

      {/* 14:7 and 14:13: lines right-aligned to x 1100, their tops at 709 and 804 */}
      <p data-part="type" className="absolute inset-0 font-coolvetica text-black" style={{ fontSize: u(79.106) }}>
        {lines.map((line, i) => (
          <span
            key={line}
            className="absolute block whitespace-nowrap text-right leading-none"
            style={{ right: u(1920 - 1100), top: u(LINE_TOPS[i]) }}
          >
            {line}
          </span>
        ))}
      </p>

      {/* 14:11 birds, mirrored, flying in from the top right */}
      <div className="absolute -scale-x-100" style={at(1557, -52, 585, 282.788)}>
        <Image src="/img/hero/birds.webp" alt="" fill sizes="30vw" className="object-contain" />
      </div>
      {/* 10:97 cloud, right */}
      <Baked src="/img/hero/cloud-right.webp" box={[1342, 74, 578, 348]} />
      {/* 10:85 Doberman */}
      <div className="absolute" style={at(1117, -104, 727, 1137.452)}>
        <Image
          src="/img/hero/dog-face.webp"
          alt="A Doberman in orange-tinted aviator sunglasses, on guard"
          fill
          priority
          sizes="(min-width: 768px) 40vw, 80vw"
        />
      </div>
      {/* 10:99 cloud, bottom left */}
      <Baked src="/img/hero/cloud-bottom.webp" box={[0, 757, 692, 323]} />

      {/* 13:3, 13:4, 14:5: the wordmark, its "o" a red no-entry sign */}
      <h1 data-part="type" className="absolute inset-0">
        <span className="sr-only">nothief</span>
        <Image
          src="/img/hero/nothief.svg"
          alt=""
          width={974.692}
          height={221.949}
          unoptimized
          priority
          className="absolute max-w-none"
          style={at(140.45, 381.26, 974.692, 221.949)}
        />
        <span className="absolute flex items-center justify-center" style={at(345.86, 450.86, 137.133, 137.133)}>
          <span className="block -rotate-45 bg-[red]" style={{ width: u(161), height: u(32.935) }} />
        </span>
        <Image
          src="/img/hero/no-entry-ring.svg"
          alt=""
          width={169}
          height={169}
          unoptimized
          className="absolute max-w-none"
          style={at(329, 434, 169, 169)}
        />
      </h1>

      {/* 14:8 cloud, top left, in front of everything */}
      <Baked src="/img/hero/cloud-top.webp" box={[0, 0, 817, 451]} />
    </>
  );
}
