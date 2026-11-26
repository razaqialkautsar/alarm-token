"use client";

import { useRef, type ReactNode } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useGSAP } from "@gsap/react";

gsap.registerPlugin(ScrollTrigger, useGSAP);

/** Room the floating nav takes at the top of the screen, in px. */
const NAV_ROOM = 90;

/**
 * Where the stage holds: centred (at 52% of the viewport) when it fits the screen, else with its top just under the
 * nav, so its figures stay in view. Figures inside time their assembly from the same point.
 */
export function stageHold(stage: Element) {
  return stage.getBoundingClientRect().height > window.innerHeight - NAV_ROOM ? `top ${NAV_ROOM}px` : "center 52%";
}
/** Pinning applies on wide screens with motion allowed. */
export const STAGE_MEDIA = "(min-width: 768px) and (prefers-reduced-motion: no-preference)";

type Props = { id: string; viewports: number; className?: string; children: ReactNode };

/**
 * Holds its content in place for `viewports` screen heights of scroll, so what happens inside (figures stacking
 * themselves) plays while the page stands still. Only on wide screens with motion allowed; elsewhere it is a plain
 * block. Figures inside read their timing from the same id (see LiveFigure's `assembly`).
 */
export function PinnedStage({ id, viewports, className = "", children }: Props) {
  const root = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const mm = gsap.matchMedia();
      mm.add(STAGE_MEDIA, () => {
        ScrollTrigger.create({
          trigger: root.current,
          start: () => stageHold(root.current!),
          end: () => `+=${window.innerHeight * viewports}`,
          pin: true,
          // GSAP turns spacing off when the parent is a flex container; the page must still move on after the hold
          pinSpacing: true,
          invalidateOnRefresh: true,
        });
      });
    },
    { scope: root },
  );

  return (
    <div ref={root} id={id} data-viewports={viewports} className={className}>
      {children}
    </div>
  );
}
