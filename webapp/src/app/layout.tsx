import type { Metadata, Viewport } from "next";
import "./globals.css";
import {
  Caveat,
  Inter,
  Instrument_Serif,
  JetBrains_Mono,
  Manrope,
  Outfit,
} from "next/font/google";
import { ThemeProvider } from "next-themes";
import { Toaster } from "@/components/ui/toaster";

/**
 * Fonts are downloaded at build time and served from this origin, so visitors
 * never contact Google Fonts. The CSS variables are consumed in globals.css.
 */
const inter = Inter({
  subsets: ["latin"],
  display: "swap",
  variable: "--ff-inter",
});
const outfit = Outfit({
  subsets: ["latin"],
  display: "swap",
  variable: "--ff-outfit",
});
const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  display: "swap",
  variable: "--ff-jetbrains-mono",
});
const manrope = Manrope({
  subsets: ["latin"],
  display: "swap",
  variable: "--ff-manrope",
});
const instrumentSerif = Instrument_Serif({
  subsets: ["latin"],
  weight: "400",
  style: ["normal", "italic"],
  display: "swap",
  variable: "--ff-instrument-serif",
});
const caveat = Caveat({
  subsets: ["latin"],
  display: "swap",
  variable: "--ff-caveat",
});

const fontVariables = [
  inter,
  outfit,
  jetbrainsMono,
  manrope,
  instrumentSerif,
  caveat,
]
  .map((font) => font.variable)
  .join(" ");

/**
 * Root layout for PocketLLM Lite Web.
 *
 * - Self-hosts the app type stack (Inter/Outfit/JetBrains Mono) and the
 *   marketing stack (Caveat, Instrument Serif, Manrope) via next/font.
 * - Wraps the app in `next-themes` for light/dark/system support.
 * - Renders the shadcn Toaster for global notifications.
 */
const SITE_URL = "https://pocketllm-lite.vercel.app";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  alternates: { canonical: "/" },
  title: "PocketLLM Lite — Your AI, on your terms",
  description:
    "PocketLLM Lite is a local-first, open-source AI workspace for Android with local models, Ollama, private memory, document RAG, tools, and explicit network controls.",
  keywords: [
    "PocketLLM",
    "local LLM",
    "offline AI",
    "Android AI",
    "Ollama",
    "GGUF",
    "RAG",
    "private AI",
  ],
  authors: [{ name: "PocketLLM" }],
  manifest: "/manifest.json",
  icons: {
    icon: "/logo.png",
    apple: "/logo.png",
  },
  openGraph: {
    title: "PocketLLM Lite — Your AI, on your terms",
    description:
      "Local-first AI with visible boundaries. Run compatible models on-device or connect an endpoint you control.",
    type: "website",
    url: SITE_URL,
    siteName: "PocketLLM Lite",
    images: ["/pocketllm-website/assets/hero-local-ai.webp"],
  },
  twitter: {
    card: "summary_large_image",
    title: "PocketLLM Lite — Your AI, on your terms",
    description:
      "Local-first AI with visible boundaries. Run compatible models on-device or connect an endpoint you control.",
    images: ["/pocketllm-website/assets/hero-local-ai.webp"],
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#FFFDF5" },
    { media: "(prefers-color-scheme: dark)", color: "#131A22" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning className={fontVariables}>
      <body className="antialiased bg-background text-foreground min-h-screen">
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          {children}
          <Toaster />
        </ThemeProvider>
      </body>
    </html>
  );
}
