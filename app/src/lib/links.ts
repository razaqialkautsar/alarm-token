// Every outbound link on the landing page. `null` means the target does not exist yet; the UI shows it as
// unavailable instead of linking to a page that looks real but is not.
const REPO = "https://github.com/razaqialkautsar/alarm-token";

export const LINKS = {
  github: REPO,
  docs: `${REPO}/tree/main/docs`,
  contracts: `${REPO}/tree/main/deployments`,
  launchApp: null, // dashboard (PRD §9) is not built yet
  register: null, // Register screen (PRD §9) is not built yet
  drill: null, // self-serve drill UI is not built yet
  buildathon: null, // add the verified event URL
  doraHacks: null, // add once the BUIDL page exists
} as const satisfies Record<string, string | null>;

export const NAV = [
  { label: "How it works", href: "#how-it-works" },
  { label: "Drill", href: "#drill" },
  { label: "Docs", href: LINKS.docs },
  { label: "GitHub", href: LINKS.github },
] as const;
