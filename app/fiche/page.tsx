"use client";

import Link from "next/link";
import { Suspense, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useAppState } from "@/components/Providers";
import { FicheQuestions, submitFiche } from "@/components/FicheForm";

export default function FichePage() {
  return (
    <Suspense fallback={null}>
      <FicheContent />
    </Suspense>
  );
}

function FicheContent() {
  const { ficheSent, markFicheSent } = useAppState();
  const params = useSearchParams();
  const passion = params.get("sejour") === "passion";
  const lea = params.get("enfant") !== "tom";
  const childName = lea ? "Léa Martin" : "Tom Martin";
  const prenom = childName.split(" ")[0];
  const nom = childName.split(" ").slice(1).join(" ");
  const stayLabel = passion
    ? "Passion Cinéma (Menton) du 14 au 20 février 2027"
    : "Studio Théâtre (Bois) du 18 au 24 octobre 2026";
  const query = params.toString();
  const dossierHref = query ? `/dossier?${query}` : "/dossier";
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    const message = await submitFiche(event.currentTarget, {
      nom,
      prenom,
      naissance: prenom === "Léa" ? "14/03/2016" : "",
      sexe: prenom === "Tom" ? "garcon" : "fille",
      sejour: stayLabel,
    });
    setBusy(false);
    if (message) {
      setError(message);
      return;
    }
    setError("");
    markFicheSent();
  }

  return (
    <section>
      <p className="back">
        <Link className="linkish" href={dossierHref}>
          ← Documents à envoyer
        </Link>
      </p>
      <p className="kicker">{stayLabel}</p>
      <h1 className="person">Fiche Sanitaire</h1>
      <p className="lede tight">
        Questionnaire de <span className="person">{childName}</span>. Cochez la case qui vaut signature, puis envoyez la
        fiche.
      </p>
      <form className="card dossier-form" onSubmit={onSubmit}>
        {ficheSent ? <p className="hint">PDF généré, en attente de validation par le bureau.</p> : null}
        <FicheQuestions />
        {error ? <p className="hint login-error">{error}</p> : null}
        <button className="btn" type="submit" disabled={busy}>
          {busy ? "Génération…" : "Envoyer la fiche"}
        </button>
      </form>
    </section>
  );
}
