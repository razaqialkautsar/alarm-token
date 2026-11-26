import type { ReactNode } from "react";

type Props = {
  href: string | null;
  tone: "alarm" | "paper" | "ink";
  children: ReactNode;
  className?: string;
};

const TONES = {
  alarm: "bg-alarm text-ink",
  paper: "bg-paper text-ink",
  ink: "bg-ink text-paper",
};

/** A button-styled link. With no target yet it keeps its look but is not a link (aria-disabled, "Not live yet"). */
export function Cta({ href, tone, children, className = "" }: Props) {
  const base = `inline-flex items-center rounded-lg px-6 py-4 text-base font-semibold ${TONES[tone]} ${className}`;
  if (!href) {
    return (
      <span aria-disabled="true" title="Not live yet" className={`${base} cursor-not-allowed`}>
        {children}
      </span>
    );
  }
  const external = href.startsWith("http");
  return (
    <a
      href={href}
      className={`${base} transition-opacity hover:opacity-85`}
      {...(external ? { target: "_blank", rel: "noreferrer" } : {})}
    >
      {children}
    </a>
  );
}
