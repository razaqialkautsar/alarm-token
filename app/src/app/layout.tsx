import type { Metadata } from "next";
import { Poppins } from "next/font/google";
import "./globals.css";

/** One family for the whole site: regular to bold, display headings at 700. */
const poppins = Poppins({ variable: "--font-poppins", weight: ["400", "500", "600", "700"], subsets: ["latin"] });

export const metadata: Metadata = {
  title: "nothief",
  description:
    "When a bridge gets hijacked, your tokens exit to USDC. Automatically. Protection for LayerZero OFT holders, on testnet.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${poppins.variable} antialiased`}>
      <body>{children}</body>
    </html>
  );
}
