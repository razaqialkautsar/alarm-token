import type { ReactNode } from "react";

/** A value linked to its on-chain source (CLAUDE.md §6.4). Renders plain text when the chain has no explorer. */
export function SourceLink({
  href,
  title,
  mono = false,
  children,
}: {
  href: string | null;
  title?: string;
  mono?: boolean;
  children: ReactNode;
}) {
  const className = `${mono ? "font-mono " : ""}underline decoration-paper/30 underline-offset-4 hover:decoration-paper`;
  if (!href) return <span title={title}>{children}</span>;
  return (
    <a href={href} target="_blank" rel="noreferrer" title={title} className={className}>
      {children}
    </a>
  );
}
