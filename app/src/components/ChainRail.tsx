"use client";

import { useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useGSAP } from "@gsap/react";

gsap.registerPlugin(ScrollTrigger, useGSAP);

export type Chain = {
  name: string;
  chainId: string;
  note?: string;
  comp: string;
  lines: string[];
  /** The chain's own brand colour: its card glow and component tag. */
  brand: string;
};

/** Labels on the links between the cards, in order. The last link is the callback, drawn in orange. */
const LINKS = ["event", "callback"];

/** One link: a label over a flowing dashed rail with a signal dot (horizontal on wide screens, vertical below). */
function Link({ label, index }: { label: string; index: number }) {
  const lit = index === LINKS.length - 1;
  return (
    <div
      data-rail-part
      aria-hidden="true"
      className={`flex items-center justify-center gap-3 py-2 lg:w-[120px] lg:flex-col lg:gap-2 lg:py-0 ${lit ? "text-alarm" : "text-ink/70"}`}
    >
      <span className="order-2 text-[13px] lg:order-1">{label}</span>
      <span className="rail order-1 lg:order-2" style={{ "--rail-delay": `${index * 1.2}s` } as React.CSSProperties}>
        <span className="rail-dot" />
      </span>
    </div>
  );
}

/**
 * The three chains of the loop as soft cards on a rail: cause on chain X, the check on Lasna, the exit on Base.
 * A signal dot runs along each link in turn. The cards rise in, one after the other, as the rail scrolls into view.
 */
export function ChainRail({ chains }: { chains: Chain[] }) {
  const root = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const mm = gsap.matchMedia();
      mm.add("(prefers-reduced-motion: no-preference)", () => {
        gsap.from("[data-rail-part]", {
          y: 24,
          autoAlpha: 0,
          duration: 0.6,
          ease: "power2.out",
          stagger: 0.12,
          scrollTrigger: { trigger: root.current, start: "top 80%", toggleActions: "play none none reverse" },
        });
      });
    },
    { scope: root },
  );

  return (
    <div ref={root} className="flex flex-col items-stretch lg:flex-row">
      {chains.map((c, i) => (
        <div key={c.name} className="contents">
          {i > 0 && <Link label={LINKS[i - 1]} index={i - 1} />}
          <article
            data-rail-part
            style={{ backgroundColor: c.brand }}
            className="relative flex flex-1 flex-col gap-6 overflow-hidden rounded-3xl p-7 text-paper"
          >
            <div className="relative flex flex-col gap-3">
              <span className="text-[13px] text-paper/60">{String(i + 1).padStart(2, "0")}</span>
              <h3 className="font-display text-[28px] leading-none">{c.name}</h3>
              <div className="flex flex-wrap gap-2">
                <span className="rounded-full bg-paper/15 px-3 py-1 text-[12px]">chain ID {c.chainId}</span>
                {c.note && <span className="rounded-full bg-paper/15 px-3 py-1 text-[12px]">{c.note}</span>}
              </div>
            </div>
            <div className="relative flex flex-col gap-2.5 border-t border-paper/25 pt-5">
              <span className="w-fit rounded-full bg-paper px-3 py-1 text-[13px] font-semibold text-ink">{c.comp}</span>
              {c.lines.map((l) => (
                <p key={l} className="text-[15px] leading-normal text-paper/90">
                  {l}
                </p>
              ))}
            </div>
          </article>
        </div>
      ))}
    </div>
  );
}
