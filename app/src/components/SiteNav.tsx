"use client";

import { useEffect, useRef, useState } from "react";
import { LINKS, NAV } from "@/lib/links";
import { Cta } from "./Cta";

/** In-page sections the nav marks as active while they are on screen. */
const SECTIONS = NAV.filter((item) => item.href.startsWith("#")).map((item) => item.href.slice(1));

/** Links kept in the compact nav after the hero. */
const COMPACT = new Set(["How it works", "Drill", "GitHub"]);

/**
 * The floating nav. Over the hero it is a wide pill; once the hero has passed it condenses to a compact pill in
 * the centre. A thin orange line along its bottom shows page progress, and an orange dot marks the section on
 * screen.
 */
export function SiteNav() {
  const [compact, setCompact] = useState(false);
  const [active, setActive] = useState<string | null>(null);
  const bar = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    let frame = 0;
    const update = () => {
      frame = 0;
      const end = document.getElementById("hero-end");
      setCompact(end ? end.getBoundingClientRect().top < 80 : window.scrollY > window.innerHeight);
      const max = document.documentElement.scrollHeight - window.innerHeight;
      bar.current?.style.setProperty("transform", `scaleX(${max > 0 ? Math.min(1, window.scrollY / max) : 0})`);
    };
    const onScroll = () => {
      if (!frame) frame = requestAnimationFrame(update);
    };
    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
      cancelAnimationFrame(frame);
    };
  }, []);

  useEffect(() => {
    const targets = SECTIONS.map((id) => document.getElementById(id)).filter((el): el is HTMLElement => !!el);
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) setActive(e.target.id);
          else setActive((cur) => (cur === e.target.id ? null : cur));
        }
      },
      { rootMargin: "-45% 0px -50% 0px" },
    );
    targets.forEach((t) => io.observe(t));
    return () => io.disconnect();
  }, []);

  return (
    <nav
      aria-label="Main"
      data-compact={compact || undefined}
      className="fixed left-1/2 top-0 z-50 flex h-[55px] w-[calc(100%-2rem)] -translate-x-1/2 items-center justify-between overflow-hidden rounded-[30px] border-[0.94px] border-paper bg-ink py-[7.5px] pl-[30px] pr-[9px] transition-[width,top] duration-500 ease-[cubic-bezier(0.22,1,0.36,1)] md:w-[calc(100%-113px)] data-[compact]:top-3 data-[compact]:w-[min(560px,calc(100%-2rem))] md:data-[compact]:w-[min(560px,calc(100%-2rem))] motion-reduce:transition-none"
    >
      <a href="#" className="font-display text-[24.4px] text-paper">
        nothief
      </a>
      <div className="flex items-center gap-[26px]">
        {NAV.map((item) => {
          const on = item.href === `#${active}`;
          const hidden = compact && !COMPACT.has(item.label);
          return (
            <a
              key={item.label}
              href={item.href}
              aria-current={on ? "location" : undefined}
              className={`relative items-center whitespace-nowrap text-[14px] font-medium text-paper hover:opacity-80 ${hidden ? "hidden" : "hidden md:flex"}`}
              {...(item.href.startsWith("http") ? { target: "_blank", rel: "noreferrer" } : {})}
            >
              <span
                aria-hidden="true"
                className={`absolute -left-3 top-1/2 size-1.5 -translate-y-1/2 rounded-full bg-alarm transition-opacity duration-300 ${on ? "opacity-100" : "opacity-0"}`}
              />
              {item.label}
            </a>
          );
        })}
        <Cta href={LINKS.launchApp} tone="alarm" className="!rounded-[30px] !px-[15px] !py-[7px] !text-[14px]">
          Launch app
        </Cta>
      </div>
      <span
        ref={bar}
        aria-hidden="true"
        style={{ transform: "scaleX(0)" }}
        className="absolute inset-x-6 bottom-[3px] h-0.5 origin-left rounded-full bg-alarm"
      />
    </nav>
  );
}
