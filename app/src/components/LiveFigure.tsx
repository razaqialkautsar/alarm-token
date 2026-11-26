"use client";

import { useEffect, useRef, useState } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { startFigureMotion } from "@/lib/figureMotion";
import { STAGE_MEDIA, stageHold } from "./PinnedStage";

gsap.registerPlugin(ScrollTrigger);

/** Assembly: each layer drops in from this far above (figure units), the next one starting this share of a step later. */
const LAYER_DROP = 46;
const LAYER_OVERLAP = 0.65;

/**
 * Stack this figure while a PinnedStage holds the page: from `from` to `to` screen heights into the stage's hold.
 * Without a matching stage (narrow screens), the figure stacks as it scrolls into view.
 */
export type Assembly = { stage: string; from: number; to: number };

/** `size` is the SVG's own width and height: the space is reserved before it loads, so pinned stages measure right. */
type Props = { src: string; alt: string; size: readonly [number, number]; className?: string; assembly?: Assembly };

/**
 * An isometric figure. It renders as a still <img> first; near the viewport, and only when motion is allowed,
 * it swaps in the inline SVG and starts its motion loop. A figure built with assembly layers (`data-layer`) stacks
 * itself from the bench up as the reader scrolls, and its motion starts once the last layer is in place.
 */
export function LiveFigure({ src, alt, size, className = "", assembly }: Props) {
  const host = useRef<HTMLDivElement>(null);
  const [svg, setSvg] = useState<string | null>(null);

  useEffect(() => {
    const el = host.current;
    if (!el || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    let cancelled = false;
    const io = new IntersectionObserver(
      (entries) => {
        if (!entries[entries.length - 1].isIntersecting) return;
        io.disconnect();
        fetch(src)
          .then((r) => (r.ok ? r.text() : null))
          .then((text) => {
            if (!cancelled && text) setSvg(text);
          })
          .catch(() => {});
      },
      { rootMargin: "400px 0px" },
    );
    io.observe(el);
    return () => {
      cancelled = true;
      io.disconnect();
    };
  }, [src]);

  useEffect(() => {
    const svgEl = host.current?.querySelector("svg");
    if (!svg || !svgEl) return;
    svgEl.setAttribute("role", "img");
    svgEl.setAttribute("aria-label", alt);
    svgEl.removeAttribute("width");
    svgEl.removeAttribute("height");
    svgEl.style.width = "100%";
    svgEl.style.height = "auto";
    svgEl.style.display = "block";

    const levels = new Map<number, Element[]>();
    svgEl.querySelectorAll("[data-layer]").forEach((g) => {
      const n = Number(g.getAttribute("data-layer"));
      levels.set(n, [...(levels.get(n) ?? []), g]);
    });
    if (!levels.size) return startFigureMotion(svgEl);

    const order = [...levels.keys()].sort((a, b) => a - b);
    let tl: gsap.core.Timeline | undefined;
    let doneAt = 0;
    const ctx = gsap.context(() => {
      const stage = assembly && window.matchMedia(STAGE_MEDIA).matches ? document.getElementById(assembly.stage) : null;
      if (stage && assembly) {
        // in a pinned stage: the timeline spans the whole hold (in screen heights), this figure stacks in its slot
        const span = Number(stage.dataset.viewports ?? 1);
        tl = gsap.timeline({
          scrollTrigger: {
            trigger: stage,
            start: () => stageHold(stage),
            end: () => `+=${window.innerHeight * span}`,
            scrub: 0.6,
            invalidateOnRefresh: true,
          },
        });
        const step = (assembly.to - assembly.from) / ((order.length - 1) * LAYER_OVERLAP + 1);
        order.forEach((n, i) => {
          tl!.fromTo(
            levels.get(n)!,
            { y: -LAYER_DROP, autoAlpha: 0 },
            { y: 0, autoAlpha: 1, ease: "power2.out", duration: step },
            assembly.from + i * step * LAYER_OVERLAP,
          );
        });
        tl.set({}, {}, span); // keep the timeline as long as the hold
        doneAt = assembly.to;
        // the SVG can arrive while the stage is already held: measure again with every pin released
        ScrollTrigger.refresh();
      } else {
        tl = gsap.timeline({ scrollTrigger: { trigger: svgEl, start: "top 85%", end: "center 55%", scrub: 0.6 } });
        order.forEach((n, i) => {
          tl!.fromTo(
            levels.get(n)!,
            { y: -LAYER_DROP, autoAlpha: 0 },
            { y: 0, autoAlpha: 1, ease: "power2.out", duration: 1 },
            i * LAYER_OVERLAP,
          );
        });
        doneAt = tl.duration();
      }
    });
    // the motion starts once the last layer is in place
    const stop = startFigureMotion(svgEl, () => !tl || tl.time() >= doneAt - 1e-3);
    return () => {
      stop();
      ctx.revert();
    };
  }, [svg, alt, assembly]);

  if (svg) {
    // The SVG is our own build output from /public, not user content.
    return (
      <div
        ref={host}
        className={className}
        style={{ aspectRatio: `${size[0]} / ${size[1]}` }}
        dangerouslySetInnerHTML={{ __html: svg }}
      />
    );
  }
  return (
    <div ref={host} className={className} style={{ aspectRatio: `${size[0]} / ${size[1]}` }}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={src} alt={alt} width={size[0]} height={size[1]} loading="lazy" className="block h-auto w-full" />
    </div>
  );
}
