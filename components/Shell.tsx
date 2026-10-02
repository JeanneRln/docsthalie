"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const screens = [
  { href: "/", label: "1. Connexion" },
  { href: "/enfants", label: "2. Enfants" },
  { href: "/dossier", label: "3. Dossier" },
  { href: "/documents", label: "4. Documents Thalie" },
  { href: "/bureau", label: "5. Bureau" },
];

export function Shell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const onLogin = pathname === "/";

  return (
    <>
      <header className="top">
        <Link className="brand" href="/enfants">
          <img className="logo" src="/LOGOTHALIE.png" alt="Thalie, séjours artistiques" />
          <em>Espace Privé : Dossier de Séjour</em>
        </Link>
        {onLogin ? null : (
          <div className="who">
            <span className="person">Camille Martin</span>
            <small>Dernière connexion : 12 septembre 2026, 18 h 42</small>
          </div>
        )}
      </header>
      <main className="wrap">{children}</main>
      <nav className="switcher" aria-label="Écrans de la maquette">
        {screens.map((screen) => (
          <Link
            key={screen.href}
            href={screen.href}
            aria-current={pathname === screen.href ? "page" : undefined}
          >
            {screen.label}
          </Link>
        ))}
      </nav>
    </>
  );
}
