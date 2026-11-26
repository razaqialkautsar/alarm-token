import { ArrowRightLeft, Eye, Minus, Plus, Siren } from "lucide-react";
import type { ReactNode } from "react";
import { ChainRail, type Chain } from "@/components/ChainRail";
import { Cta } from "@/components/Cta";
import { HeroScroll } from "@/components/HeroScroll";
import { LiveFigure as Figure } from "@/components/LiveFigure";
import { PinnedStage } from "@/components/PinnedStage";
import { RevealInStage } from "@/components/RevealInStage";
import { SiteNav } from "@/components/SiteNav";
import { LINKS } from "@/lib/links";

/** Each figure's own width and height (the SVG size), so its space is reserved before it loads. */
const PANEL = [600, 400] as const;
const STEP_PANEL = [480, 340] as const;
const FLOW_PANEL = [1344, 640] as const;

/** The two patterns hold on screen while their figures stack, one after the other, then a short rest. */
const THREAT_HOLD_VIEWPORTS = 1.3;
/** The three steps stack one after the other while held; so do the three stations of the flow, left to right. */
const STEPS_HOLD_VIEWPORTS = 1.5;
const FLOW_HOLD_VIEWPORTS = 1.2;

const PATTERNS = [
  {
    num: "1",
    suffix: "st",
    name: "Peer change",
    fig: "/img/fig-peer.svg",
    assembly: { stage: "threat-patterns", from: 0, to: 0.55 },
    alt: "A patch panel: the original cable lies unplugged while a new, orange cable sits in a socket that was never the baseline.",
    head: "Someone rewires the bridge.",
    desc: "An attacker takes over the token's owner key and calls setPeer to trust a fake contract on another chain. New tokens get minted out of nothing. Seen in the GriffinAI incident.",
  },
  {
    num: "2",
    suffix: "nd",
    name: "Delegate change",
    fig: "/img/fig-delegate.svg",
    assembly: { stage: "threat-patterns", from: 0.6, to: 1.15 },
    alt: "An approval stamp: the original lies knocked over beside its empty rack, and an orange stand-in stamp has just approved a message.",
    head: "Someone swaps the delegate.",
    desc: "The endpoint delegate controls the bridge's security settings. Change it, and the attacker decides which messages are valid. Seen in The Sandbox incident.",
  },
];

const STEPS = [
  {
    num: "01",
    Icon: Eye,
    iconClass: "step-icon-watch",
    fig: "/img/fig-watch.svg",
    assembly: { stage: "how-steps", from: 0, to: 0.4 },
    alt: "A ticker-tape reader: the event log runs from reel to reel under a reading head that is always on.",
    head: "Watch",
    desc: "A reactive contract on Reactive Network listens for PeerSet and DelegateSet events on the token's chains, around the clock.",
  },
  {
    num: "02",
    Icon: Siren,
    iconClass: "step-icon-detect",
    fig: "/img/fig-detect.svg",
    assembly: { stage: "how-steps", from: 0.45, to: 0.85 },
    alt: "A pin-tumbler comparator: four pins sit flush with the baseline gauge and one stands proud with an orange flag.",
    head: "Detect",
    desc: "It compares every event with the baseline read on-chain. A real change to a peer or delegate raises the alarm.",
  },
  {
    num: "03",
    Icon: ArrowRightLeft,
    iconClass: "step-icon-exit",
    fig: "/img/fig-exit.svg",
    assembly: { stage: "how-steps", from: 0.9, to: 1.3 },
    alt: "A coin changer: token coins slide into an exchange drum and USDC coins come out into the holder's tray.",
    head: "Exit",
    desc: "A callback on Base Sepolia swaps registered holders' tokens to USDC and sends it straight to their own wallets.",
  },
];

const CHAINS: Chain[] = [
  {
    name: "Ethereum Sepolia",
    chainId: "11155111",
    note: "chain X",
    // Ethereum blue #627EEA: third-party palette (colorfyi.com/brands/ethereum); ethereum.org/en/brand is the official page
    brand: "#627EEA",
    comp: "DemoOFT + EndpointV2",
    lines: ["A peer or delegate changes.", "PeerSet / DelegateSet is emitted."],
  },
  {
    name: "Reactive Lasna",
    chainId: "5318007",
    // Ultramarine #2756FC: Reactive press kit (reactive.network/press)
    brand: "#2756FC",
    comp: "AlarmReactive",
    lines: ["Compares the event with the on-chain baseline.", "A real change raises the alarm."],
  },
  {
    name: "Base Sepolia",
    chainId: "84532",
    // Base blue #0000FF: Coinbase developer docs (docs.cdp.coinbase.com, Base logo); brand kit at github.com/base/brand-kit
    brand: "#0000FF",
    comp: "AlarmExecutor",
    lines: ["Swaps registered holders' tokens to USDC.", "USDC lands in each holder's own wallet."],
  },
];

const GUARANTEES = [
  { head: "No bot.", desc: "Nothing off-chain in the protection loop." },
  { head: "No custody.", desc: "Tokens stay in your wallet until the exit." },
  { head: "No permission.", desc: "Works without the token issuer's help." },
  { head: "No mock data.", desc: "Every number links to a real tx or read." },
];

const REGISTER = [
  { head: "Connect", desc: "Connect your wallet on Base Sepolia." },
  {
    head: "Pick your token",
    desc: "Choose the OFT you hold. The dashboard reads its bridge config and warns you if a single verifier (DVN 1-of-1) secures it.",
  },
  {
    head: "Set your rules",
    desc: "Sell portion (default 100%), slippage (default 20%), what to do if the price is too low, a floor price, and a small ETH deposit that pays for the callback.",
  },
  {
    head: "Approve and register",
    desc: "Approve the executor for the token and register. Baselines are read on-chain, never typed in by you.",
  },
];

const BUILT_WITH = [
  {
    head: "Reactive Network",
    desc: "Watches events and fires callbacks. Lasna testnet.",
  },
  { head: "LayerZero V2", desc: "The OFT bridge standard we watch." },
  { head: "Base Sepolia", desc: "Where the exit swap to USDC runs." },
  { head: "Ethereum Sepolia", desc: "The second chain of the drill token." },
];

const FAQ = [
  {
    q: "Do I hand over my tokens?",
    a: "No. They stay in your wallet until an exit runs. You give the executor an allowance, it never takes more than your balance or that allowance, and the USDC goes only to your own address.",
  },
  {
    q: "What if the alarm is wrong?",
    a: "A setPeer that does not change the value is ignored. If an alarm still fires on a legitimate change, you hold USDC and can buy back in one click from the dashboard, signed by you.",
  },
  {
    q: "What if the price is already falling?",
    a: "The exit tries 100% at 20% slippage, then 50%, then the rest at 50%. You choose at registration whether to stop, follow this ladder, or sell at any price.",
  },
  {
    q: "Does the token issuer need to join?",
    a: "No. nothief works from the holder's side, without the issuer's permission.",
  },
  {
    q: "Why testnet only?",
    a: "This is a hackathon build. Every drill runs on Reactive Lasna, Base Sepolia and Ethereum Sepolia, with the issuer, attacker and holder all played by our team.",
  },
];

const FOOTER = [
  {
    head: "Product",
    links: [
      { label: "How it works", href: "#how-it-works" },
      { label: "Run the drill", href: "#drill" },
      { label: "Launch app", href: LINKS.launchApp },
    ],
  },
  {
    head: "Build",
    links: [
      { label: "Docs", href: LINKS.docs },
      { label: "GitHub", href: LINKS.github },
      { label: "Contracts", href: LINKS.contracts },
    ],
  },
  {
    head: "Hackathon",
    links: [
      { label: "Reactive Omni Buildathon", href: LINKS.buildathon },
      { label: "DoraHacks BUIDL", href: LINKS.doraHacks },
    ],
  },
];

function Divider() {
  return (
    <div aria-hidden="true" className="relative h-px bg-paper">
      <span className="absolute left-1/2 top-[-4px] size-2 -translate-x-1/2 bg-paper" />
    </div>
  );
}

function Title({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <h2 className={`font-display text-[clamp(3rem,6.7vw,6rem)] leading-none ${className}`}>{children}</h2>;
}

function Eyebrow({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <p className={`text-[15px] font-medium ${className}`}>{children}</p>;
}

function TextLink({ href, children }: { href: string | null; children: ReactNode }) {
  if (!href) {
    return (
      <span aria-disabled="true" title="Not live yet" className="cursor-not-allowed">
        {children}
      </span>
    );
  }
  const external = href.startsWith("http");
  return (
    <a href={href} className="hover:underline" {...(external ? { target: "_blank", rel: "noreferrer" } : {})}>
      {children}
    </a>
  );
}

export default function Home() {
  return (
    <main>
      <SiteNav />
      <HeroScroll />
      <div id="hero-end" aria-hidden="true" />
      <Divider />

      <section className="flex flex-col gap-12 bg-paper px-6 pb-24 pt-12 text-ink md:px-12 md:pb-[120px] md:pt-12">
        <p className="text-[30px] font-medium">The threat</p>
        <h2 className="font-display max-w-[1000px] text-[clamp(3rem,6.7vw,6rem)] leading-none">
          <span className="text-alarm">Bridge hijacks</span>
          <span className="block mt-4 text-[clamp(1.17rem,2.62vw,2.34rem)] font-normal leading-tight md:mt-6">
            don&apos;t wait until you wake up.
          </span>
        </h2>
        <PinnedStage
          id="threat-patterns"
          viewports={THREAT_HOLD_VIEWPORTS}
          className="grid gap-16 md:grid-cols-2 md:gap-12"
        >
          {PATTERNS.map((p, i) => (
            // each pattern appears once the previous one has finished assembling
            <RevealInStage key={p.num} stage="threat-patterns" at={i === 0 ? 0 : PATTERNS[i - 1].assembly.to}>
              {/* read order: which pattern (one large line), then the figure with what happens set in its top band */}
              <article className="flex flex-col gap-8">
                <h3 className="font-display text-[clamp(1.75rem,2.8vw,2.5rem)] leading-[1.05]">
                  <span>
                    {p.num}
                    <span className="text-[0.5em]">{p.suffix}</span>
                  </span>{" "}
                  Pattern · {p.name}
                </h3>
                <div className="relative">
                  <Figure src={p.fig} alt={p.alt} size={PANEL} assembly={p.assembly} />
                  {/* set in the band the light panel leaves free above the tile (.context/figures/lib.mjs, PANEL=light) */}
                  <p className="absolute left-[4%] right-[4%] top-[6%] text-[clamp(1.125rem,1.7vw,1.625rem)] font-semibold leading-tight">
                    {p.head}
                  </p>
                </div>
                <p className="text-justify text-[17px] leading-normal">{p.desc}</p>
              </article>
            </RevealInStage>
          ))}
        </PinnedStage>
      </section>

      <Divider />

      <section id="how-it-works" className="flex flex-col gap-14 px-6 py-24 md:px-12 md:py-[120px]">
        <p className="text-[30px] font-medium">Cause on one chain. Action on another.</p>
        <PinnedStage id="how-steps" viewports={STEPS_HOLD_VIEWPORTS}>
          <ol className="grid gap-16 md:grid-cols-3 md:gap-10">
            {STEPS.map(({ num, Icon, iconClass, fig, alt, head, desc, assembly }, i) => (
              // each step appears once the previous one has finished assembling
              <li key={num}>
                <RevealInStage stage="how-steps" at={i === 0 ? 0 : STEPS[i - 1].assembly.to}>
                  <div className="flex flex-col gap-8">
                    <div className="flex items-center justify-between">
                      <h3 className="font-display text-[44px] leading-tight">
                        {num} {head}
                      </h3>
                      <Icon aria-hidden="true" className={`size-7 ${iconClass}`} />
                    </div>
                    <Figure src={fig} alt={alt} size={STEP_PANEL} assembly={assembly} />
                    <p className="text-justify text-base leading-[1.55]">{desc}</p>
                  </div>
                </RevealInStage>
              </li>
            ))}
          </ol>
        </PinnedStage>
      </section>

      <section className="flex flex-col gap-14 bg-paper px-6 py-24 text-ink md:px-12 md:py-[120px]">
        <Title>Three chains. One reflex.</Title>
        {/* the flow is wider than tall: at full width it would not fit one screen while held, so it is capped to the
            screen height under the nav (1344 x 640 figure) */}
        <PinnedStage
          id="flow-stage"
          viewports={FLOW_HOLD_VIEWPORTS}
          className="md:mx-auto md:w-full md:max-w-[calc((100svh-110px)*2.1)]"
        >
          <Figure
            src="/img/fig-flow.svg"
            size={FLOW_PANEL}
            alt="Three benches in a row: chain X, Lasna and Base. A changed peer or delegate on chain X trips a relay on Lasna, which opens a valve on Base that pours tokens into a USDC canister."
            assembly={{ stage: "flow-stage", from: 0, to: 1 }}
          />
        </PinnedStage>
        <ChainRail chains={CHAINS} />
        <p className="text-justify text-[15px] leading-normal">
          The same watch runs on Base Sepolia too: a peer or delegate change on either chain triggers the exit on Base.
        </p>
      </section>

      {/* desktop: four columns on a ruled line, numbered, text left-aligned; mobile keeps the boxes for now */}
      <section
        aria-label="Guarantees"
        className="grid sm:grid-cols-2 lg:grid-cols-4 lg:gap-10 lg:bg-paper lg:px-12 lg:py-[120px] lg:text-ink"
      >
        {GUARANTEES.map((g, i) => (
          <div
            key={g.head}
            className={`flex h-60 flex-col justify-between border-y border-paper p-7 lg:h-auto lg:gap-6 lg:border-x-0 lg:border-y-0 lg:border-t lg:border-ink lg:bg-paper lg:p-0 lg:pt-6 lg:text-ink ${i % 2 ? "bg-paper text-ink" : "bg-ink text-paper"}`}
          >
            <span className="hidden text-[13px] text-ink/60 lg:block">{String(i + 1).padStart(2, "0")}</span>
            <h3 className="font-display text-[44px] leading-tight lg:text-[2.25rem]">{g.head}</h3>
            <p className="text-justify text-[15px] font-medium lg:text-left">{g.desc}</p>
          </div>
        ))}
      </section>

      <section
        id="register"
        className="flex flex-col gap-16 bg-paper px-6 py-24 text-ink md:px-12 md:py-[120px] lg:flex-row lg:gap-20"
      >
        <div className="flex flex-col items-start gap-6 lg:w-[480px] lg:shrink-0">
          <Eyebrow>For holders</Eyebrow>
          <Title>Set it once. Sleep.</Title>
          <p className="text-justify text-[17px] leading-normal">
            Registration takes a few transactions from your own wallet on Base Sepolia. After that, there is nothing to
            do at alarm time.
          </p>
          <Cta href={LINKS.register} tone="alarm">
            Protect my tokens
          </Cta>
        </div>
        <ol className="flex flex-1 flex-col">
          {REGISTER.map((s, i) => (
            <li key={s.head} className="flex gap-8 border-t border-ink py-7">
              <span className="font-display text-[28px]">{String(i + 1).padStart(2, "0")}</span>
              <div className="flex flex-col gap-2">
                <h3 className="font-display text-[36px] leading-tight">{s.head}</h3>
                <p className="text-justify text-base leading-[1.55]">{s.desc}</p>
              </div>
            </li>
          ))}
        </ol>
      </section>

      <section className="flex flex-col gap-8 border-b border-paper px-6 py-16 md:px-12">
        <Eyebrow>Built with</Eyebrow>
        <ul className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {BUILT_WITH.map((b) => (
            <li key={b.head} className="flex flex-col gap-2 border-t border-paper pt-5">
              <h3 className="font-display text-[32px]">{b.head}</h3>
              <p className="text-justify text-[15px] leading-normal">{b.desc}</p>
            </li>
          ))}
        </ul>
      </section>

      <section className="flex flex-col gap-12 px-6 py-24 md:px-12 md:py-[120px] lg:flex-row lg:gap-20">
        <Title className="lg:w-[420px] lg:shrink-0">Fair questions.</Title>
        <div className="flex-1">
          {FAQ.map((f) => (
            <details key={f.q} open className="group border-t border-paper py-7">
              <summary className="flex cursor-pointer list-none items-center justify-between gap-6 text-[22px] font-semibold [&::-webkit-details-marker]:hidden">
                {f.q}
                <Minus aria-hidden="true" className="hidden size-[22px] shrink-0 group-open:block" />
                <Plus aria-hidden="true" className="size-[22px] shrink-0 group-open:hidden" />
              </summary>
              <p className="text-justify mt-3 max-w-[760px] text-base leading-[1.6]">{f.a}</p>
            </details>
          ))}
        </div>
      </section>

      <section
        id="drill"
        className="flex min-h-[640px] flex-col items-center justify-center gap-6 px-6 text-center"
        style={{
          background: "radial-gradient(140% 120% at 50% 100%, #ea760066, #ea760000), #000",
        }}
      >
        <Eyebrow>Testnet drill</Eyebrow>
        <h2 className="font-display text-[clamp(3.5rem,7.6vw,6.875rem)] leading-none">
          Play the thief.
          <br />
          Watch the exit.
        </h2>
        <p className="max-w-[560px] text-[17px] leading-normal">
          Hijack a drill token on testnet yourself, then follow every tx from the alarm to the USDC in your wallet.
        </p>
        <div className="flex flex-wrap justify-center gap-2.5">
          <Cta href={LINKS.drill} tone="alarm">
            Run the drill
          </Cta>
          <Cta href={LINKS.docs} tone="paper">
            Read the docs
          </Cta>
        </div>
      </section>

      <footer className="flex flex-col gap-20 overflow-hidden bg-alarm px-6 pt-16 text-ink md:px-12">
        <div className="relative z-10 flex flex-col justify-between gap-12 lg:flex-row">
          <p className="font-display text-[40px] leading-[1.1]">
            Your tokens leave
            <br />
            before the thief does.
          </p>
          <div className="flex flex-wrap gap-12 md:gap-24">
            {FOOTER.map((col) => (
              <div key={col.head} className="flex flex-col gap-2.5">
                <p className="text-sm font-medium">{col.head}</p>
                {col.links.map((l) => (
                  <span key={l.label} className="text-base font-semibold">
                    <TextLink href={l.href}>{l.label}</TextLink>
                  </span>
                ))}
              </div>
            ))}
          </div>
        </div>
        {/* The giant glyphs rise above their line box; keep them from covering the links above. */}
        <p aria-hidden="true" className="pointer-events-none select-none font-display text-[25vw] leading-[0.78]">
          nothief
        </p>
      </footer>
    </main>
  );
}
