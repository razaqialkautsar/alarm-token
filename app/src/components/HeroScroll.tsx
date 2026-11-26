"use client";

import { useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useGSAP } from "@gsap/react";
import { DogRunner, dogLead, type JumpProgress } from "./DogRunner";
import { HeroArt } from "./HeroArt";

gsap.registerPlugin(ScrollTrigger, useGSAP);

/** The Doberman's nose in the Figma hero (about x 1240, y 662 of 1920 x 1080): the zoom target. */
const NOSE_ORIGIN = `${(1240 / 1920) * 100}% ${(662 / 1080) * 100}%`;

/** Scroll length of the pinned hero, in viewport heights. Most of it goes to the running sentence. */
const PIN_VIEWPORTS = 6;

/** The line under the wordmark (the Figma design left two lines of lorem ipsum). "No bot, no server": PRD V6. */
const TAGLINE = ["No bot. No server."];
const SENTENCE = "When a bridge gets hijacked, your tokens exit to USDC.";
const PAYOFF = "Automatically.";

/**
 * Hero and headline. With motion allowed, the pair is pinned and scrubbed: the hero holds, zooms into the nose,
 * fades to black, the first two lines slide in, then "Automatically." lands. With reduced motion (or no JS), the hero and the headline are two plain sections.
 */
export function HeroScroll() {
  const root = useRef<HTMLDivElement>(null);
  const lineRef = useRef<HTMLSpanElement>(null);
  const jumpRef = useRef<JumpProgress>({ p: 0 });

  useGSAP(
    () => {
      const el = root.current;
      if (!el) return;
      const mm = gsap.matchMedia();
      mm.add("(prefers-reduced-motion: no-preference)", () => {
        el.dataset.animated = "true";
        const q = gsap.utils.selector(el);
        const [card, stage, dark, headline, last, blackout] = [
          "card",
          "stage",
          "dark",
          "headline",
          "last",
          "blackout",
        ].map((name) => q(`[data-part="${name}"]`)[0]);
        const line = q('[data-part="line"]')[0];

        gsap.set(stage, { transformOrigin: NOSE_ORIGIN });
        gsap.set(headline, { autoAlpha: 0 });

        const tl = gsap.timeline({
          defaults: { ease: "none" },
          scrollTrigger: {
            trigger: el,
            start: "top top",
            end: () => `+=${window.innerHeight * PIN_VIEWPORTS}`,
            pin: true,
            scrub: 1,
            invalidateOnRefresh: true,
          },
        });

        // 01-02 (0-10%): hold on the hero, so it can be read.
        // 03 (10-37%): zoom into the nose; the wordmark and the lines slide out.
        tl.to(stage, { scale: 3, ease: "power3.in", duration: 0.27 }, 0.1);
        tl.to(q('[data-part="type"]'), { xPercent: -45, ease: "power2.in", duration: 0.27 }, 0.1);
        // 04 (37-44%): into the dark.
        tl.to(stage, { scale: 12, ease: "power2.in", duration: 0.07 }, 0.37);
        tl.to(dark, { opacity: 1, duration: 0.07 }, 0.37);
        tl.set(card, { autoAlpha: 0 }, 0.44);
        // 05 (44-82%): the sentence runs across the screen in one line, entering right and leaving left. It takes
        // the largest share of the scroll, so it moves slowly under the reader's hand. It starts a dog's length
        // further right: the 3D Doberman runs ahead of it and enters first.
        tl.set(headline, { autoAlpha: 1 }, 0.44);
        tl.fromTo(
          line,
          { x: () => window.innerWidth + dogLead(parseFloat(getComputedStyle(line).fontSize)) },
          { x: () => -line.scrollWidth - 48, ease: "none", duration: 0.38 },
          0.44,
        );
        // 06 (83-90%): only once it has gone, "Automatically." lands, centred and large.
        tl.fromTo(
          last,
          { autoAlpha: 0, scale: 0.85 },
          { autoAlpha: 1, scale: 1, ease: "back.out(2)", duration: 0.07 },
          0.83,
        );
        // 07 (90-96%): hold on the word.
        // 08 (96-130%): the 3D Doberman runs at us from behind the word, passes it and leaps into the lens; the
        // screen goes black and the pin releases into "The threat" (also black).
        tl.fromTo(jumpRef.current, { p: 0 }, { p: 1, ease: "none", duration: 0.32 }, 0.96);
        tl.fromTo(blackout, { opacity: 0 }, { opacity: 1, duration: 0.04 }, 1.24);
        tl.to({}, { duration: 0.02 }, 1.28);

        return () => {
          delete el.dataset.animated;
        };
      });
    },
    { scope: root },
  );

  return (
    <div ref={root} className="group relative overflow-hidden bg-ink">
      <section aria-label="nothief" className="relative h-svh overflow-hidden bg-paper">
        <div data-part="card" className="absolute inset-0 bg-paper will-change-transform">
          <div data-part="stage" className="hero-stage will-change-transform">
            <HeroArt lines={TAGLINE} />
          </div>
          <div data-part="dark" className="pointer-events-none absolute inset-0 bg-ink opacity-0" />
        </div>
      </section>

      <section
        data-part="headline"
        aria-label="What nothief does"
        className="relative flex flex-col justify-center bg-ink px-6 py-[200px] md:px-12 group-data-[animated=true]:absolute group-data-[animated=true]:inset-0 group-data-[animated=true]:py-0"
      >
        <h2 className="font-display text-[clamp(2.75rem,6.95vw,6.25rem)] leading-none text-paper">
          <span
            ref={lineRef}
            data-part="line"
            className="block will-change-transform group-data-[animated=true]:w-max group-data-[animated=true]:whitespace-nowrap"
          >
            {SENTENCE}
          </span>
          <span
            data-part="last"
            className="relative z-[1] block text-alarm will-change-transform group-data-[animated=true]:absolute group-data-[animated=true]:inset-0 group-data-[animated=true]:flex group-data-[animated=true]:items-center group-data-[animated=true]:justify-center group-data-[animated=true]:text-[clamp(3.5rem,12vw,15rem)]"
          >
            {PAYOFF}
          </span>
        </h2>
        <DogRunner line={lineRef} jump={jumpRef} />
        <div data-part="blackout" className="pointer-events-none absolute inset-0 z-[3] bg-ink opacity-0" />
      </section>
    </div>
  );
}
