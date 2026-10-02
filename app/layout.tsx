import type { Metadata } from "next";
import { Libre_Baskerville, Montserrat } from "next/font/google";
import { Providers } from "@/components/Providers";
import { Shell } from "@/components/Shell";
import "./globals.css";

const montserrat = Montserrat({
  subsets: ["latin"],
  weight: ["300", "400", "500", "600", "700"],
  variable: "--font-montserrat",
});

const baskerville = Libre_Baskerville({
  subsets: ["latin"],
  weight: "400",
  style: ["normal", "italic"],
  variable: "--font-baskerville",
});

export const metadata: Metadata = {
  title: "Espace Privé : Dossier de Séjour — Thalie",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr" className={`${montserrat.variable} ${baskerville.variable}`}>
      <body>
        <Providers>
          <Shell>{children}</Shell>
        </Providers>
      </body>
    </html>
  );
}
