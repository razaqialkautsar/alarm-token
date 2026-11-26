"use client";

import { useRef, type ReactNode } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useGSAP } from "@gsap/react";
import { STAGE_MEDIA, stageHold } from "./PinnedStage";

gsap.registerPlugin(ScrollTrigger, useGSAP);

/** How long the fade-in takes, in the stage's scroll units (screen heights). */
const REVEAL_SPAN = 0.05;

type Props = { stage: string; at: number; children: ReactNode };

/**
 * Hidden while the PinnedStage `stage` holds, until `at` screen heights into its hold, then fades in on scroll.
 * Only inside a pinned stage (wide screens, motion allowed); elsewhere it is always visible.
 */
export function RevealInStage({ stage, at, children }: Props) {
  const root = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const stageEl = document.getElementById(stage);
      if (!stageEl) return;
      const mm = gsap.matchMedia();
      mm.add(STAGE_MEDIA, () => {
        const span = Number(stageEl.dataset.viewports ?? 1);
        const tl = gsap.timeline({
          scrollTrigger: {
            trigger: stageEl,
            start: () => stageHold(stageEl),
            end: () => `+=${window.innerHeight * span}`,
            scrub: 0.6,
            invalidateOnRefresh: true,
          },
        });
        tl.fromTo(root.current, { autoAlpha: 0 }, { autoAlpha: 1, duration: REVEAL_SPAN }, at);
        // keep the timeline as long as the hold, so the fade lines up with the stage's scroll
        tl.set({}, {}, span);
      });
    },
    { scope: root },
  );

  return <div ref={root}>{children}</div>;
}
