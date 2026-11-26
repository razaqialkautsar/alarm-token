/**
 * Runtime for the isometric figures. The SVGs are built in `.context/figures` with motion hooks as data
 * attributes (see `anim` in lib.mjs); this drives them with one time-based loop per figure.
 *
 *   spin    rotate planar parts in their own plane (data-m: screen vectors of the two plane axes,
 *           data-c: screen centre, data-period; data-swing: oscillate by that many turns instead)
 *   loop    slide along data-v, sawtooth (a seamless pattern shifted by one pitch)
 *   travel  slide along data-v, sawtooth with fades at both ends
 *   press   move along data-v and back: down, hold, up
 *   pulse   opacity: "wave" (breathing) or "mark" (appears while a press holds)
 *   frames  show one prebuilt child at a time: rise, hold, fall
 *   flow    move the dashes of a stroke (data-speed in figure units per second)
 */

const TAU = Math.PI * 2;
const frac = (x: number) => x - Math.floor(x);
const smooth = (a: number, b: number, x: number) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};
/** 0 → 1 → 0 over one cycle: move, hold, return. */
const press = (p: number) => smooth(0.1, 0.25, p) - smooth(0.55, 0.72, p);
const nums = (s: string | undefined) => (s ?? "").split(/\s+/).filter(Boolean).map(Number);

type Mover = (t: number) => void;

function moverOf(el: SVGElement): Mover | null {
  const d = el.dataset;
  const period = Number(d.period ?? 4);
  const phase = Number(d.phase ?? 0);
  const [vx, vy] = nums(d.v);

  switch (d.anim) {
    case "spin": {
      const [ax, ay, bx, by] = nums(d.m);
      const [cx, cy] = nums(d.c);
      const det = ax * by - bx * ay;
      const swing = d.swing ? Number(d.swing) : 0;
      return (t) => {
        const th = swing ? swing * TAU * Math.sin((TAU * t) / period) : (TAU * t) / period;
        const c = Math.cos(th);
        const s = Math.sin(th);
        // T = M · R · M⁻¹, with M = [a b] (columns): the rotation seen through the projection
        const r00 = (ax * c + bx * s) * by - (-ax * s + bx * c) * ay;
        const r01 = -(ax * c + bx * s) * bx + (-ax * s + bx * c) * ax;
        const r10 = (ay * c + by * s) * by - (-ay * s + by * c) * ay;
        const r11 = -(ay * c + by * s) * bx + (-ay * s + by * c) * ax;
        const a = r00 / det;
        const b = r10 / det;
        const cc = r01 / det;
        const dd = r11 / det;
        el.setAttribute("transform", `matrix(${a} ${b} ${cc} ${dd} ${cx - a * cx - cc * cy} ${cy - b * cx - dd * cy})`);
      };
    }
    case "loop":
    case "travel":
      return (t) => {
        const s = frac(t / period + phase);
        const k = s - phase;
        el.setAttribute("transform", `translate(${vx * k} ${vy * k})`);
        if (d.anim === "travel") el.setAttribute("opacity", String(Math.min(1, s / 0.12, (1 - s) / 0.12)));
      };
    case "press":
      return (t) => {
        const e = press(frac(t / period + phase));
        el.setAttribute("transform", `translate(${vx * e} ${vy * e})`);
      };
    case "pulse":
      return (t) => {
        const p = frac(t / period + phase);
        const o = d.shape === "mark" ? smooth(0.2, 0.26, p) - smooth(0.85, 0.98, p) : 0.5 + 0.5 * Math.cos(TAU * p);
        el.setAttribute("opacity", String(d.shape === "mark" ? o : 0.45 + 0.55 * o));
      };
    case "frames": {
      const kids = Array.from(el.children) as SVGElement[];
      const last = kids.length - 1;
      let shown = last;
      return (t) => {
        const i = Math.round(press(frac(t / period)) * last);
        if (i === shown) return;
        kids[shown].setAttribute("display", "none");
        kids[i].removeAttribute("display");
        shown = i;
      };
    }
    case "flow": {
      const speed = Number(d.speed ?? 14);
      return (t) => el.setAttribute("stroke-dashoffset", String(-t * speed));
    }
    default:
      return null;
  }
}

/**
 * Start the figure's loop. It runs only while the figure is near the viewport, and, when `ready` is given, only
 * while it returns true (the clock holds meanwhile, so the parts stay in their rest pose). Returns a stop function.
 */
export function startFigureMotion(root: Element, ready?: () => boolean): () => void {
  const movers = Array.from(root.querySelectorAll<SVGElement>("[data-anim]"))
    .map(moverOf)
    .filter((m): m is Mover => m !== null);
  if (!movers.length) return () => {};

  let frame = 0;
  let clock = 0;
  let last = 0;
  let visible = false;

  const tick = (now: number) => {
    const on = !ready || ready();
    if (on) clock += last ? Math.min((now - last) / 1000, 1 / 30) : 0;
    last = now;
    if (on) for (const m of movers) m(clock);
    frame = visible ? requestAnimationFrame(tick) : 0;
  };
  const io = new IntersectionObserver(
    (entries) => {
      visible = entries[entries.length - 1].isIntersecting;
      if (visible && !frame) {
        last = 0;
        frame = requestAnimationFrame(tick);
      }
    },
    { rootMargin: "120px 0px" },
  );
  io.observe(root);

  return () => {
    io.disconnect();
    cancelAnimationFrame(frame);
  };
}
