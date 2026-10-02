"use client";

import Link from "next/link";
import { useState } from "react";
import { useSearchParams } from "next/navigation";
import { useAppState } from "@/components/Providers";
import { FicheQuestions, submitFiche } from "@/components/FicheForm";

export default function DossierPage() {
  const { ficheSent, markFicheSent } = useAppState();
  const params = useSearchParams();
  const passion = params.get("sejour") === "passion";
  const childName = params.get("enfant") === "tom" ? "Tom Martin" : "Léa Martin";
  const prenom = childName.split(" ")[0];
  const nom = childName.split(" ").slice(1).join(" ");
  const stayLabel = passion
    ? "Passion Cinéma (Menton) du 14 au 20 février 2027"
    : "Studio Théâtre (Bois) du 18 au 24 octobre 2026";
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
        <Link className="linkish" href="/enfants">
          ← Mes enfants
        </Link>
      </p>
      <p className="kicker">{stayLabel}</p>
      <h1 className="person">{childName}</h1>
      <div className="note">
        Votre enfant est inscrit sur l’un de nos séjours. Les régimes alimentaires et les allergies qui n’ont pas été
        indiqués au préalable ne pourront pas être pris en compte par les équipes de cuisine. Si le départ a lieu dans
        moins de 4 jours, les spécificités ne sont plus modifiées.
      </div>
      <aside className="card dossier-files">
        <h2 className="side-title">Fichiers</h2>
        <div className="files">
          <div className="file">
            <div>
              <strong>Attestation sécu</strong>
              <span>Validée le 12 septembre, plus modifiable</span>
            </div>
            <span className="pill ok">Validée</span>
          </div>
          <div className="file">
            <div>
              <strong>Carnet de vaccination, page 1</strong>
              <span>Photo illisible</span>
            </div>
            <div className="actions">
              <span className="pill wait">À corriger</span>
              <button className="btn small secondary" type="button">
                Remplacer
              </button>
            </div>
          </div>
          <div className="file">
            <div>
              <strong>Vaccinations, page 2</strong>
              <span>Facultatif</span>
            </div>
            <span className="pill opt">Facultatif</span>
          </div>
          <div className="file">
            <div>
              <strong>Mutuelle</strong>
              <span>Facultatif</span>
            </div>
            <span className="pill opt">Facultatif</span>
          </div>
          <div className="file">
            <div>
              <strong>Ordonnance</strong>
              <span>Le cas échéant</span>
            </div>
            <span className="pill opt">Facultatif</span>
          </div>
          <div className="file">
            <div>
              <strong>PAI</strong>
              <span>Le cas échéant</span>
            </div>
            <span className="pill opt">Facultatif</span>
          </div>
          <div className="file">
            <div>
              <strong>Pass nautique</strong>
              <span>Séjours nautiques seulement</span>
            </div>
            <span className="pill opt">Non demandé</span>
          </div>
        </div>
        <p className="hint">La relance du 11 octobre concerne le carnet de vaccination.</p>
        <p>
          <Link
            className="linkish"
            href={`/documents?depuis=dossier&enfant=${params.get("enfant") === "tom" ? "tom" : "lea"}&sejour=${passion ? "passion-2027" : "studio-theatre-2026"}`}
          >
            Documents envoyés par Thalie
          </Link>
        </p>
      </aside>
      <form className="card dossier-form" onSubmit={onSubmit}>
        <h2 className="side-title">Remplir la fiche sanitaire numériquement</h2>
        {ficheSent ? <p className="hint">PDF généré, en attente de validation par le bureau.</p> : null}
        <fieldset className="locked" disabled>
          <legend>Validé le 12 septembre, plus modifiable</legend>
          <p className="legal">
            Dans le cadre de la loi sur le droit à l’image, j’autorise la publication de l’image de mon enfant pour le
            blog du séjour, le spectacle diffusé en live, la brochure, le site internet et les réseaux sociaux de
            Thalie. Thalie s’interdit toute utilisation commerciale de ces images.
          </p>
          <label className="choice">
            <input type="radio" name="image" /> Je donne le droit à l’image de mon enfant
          </label>
          <label className="choice">
            <input type="radio" name="image" defaultChecked /> Je ne donne pas le droit à l’image. L’enfant ne sera pas
            filmé au spectacle de fin de séjour, ni sur scène avec les autres, ni dans les courts-métrages.
          </label>
          <label className="choice">
            <input type="checkbox" defaultChecked /> J’accepte que mes informations personnelles soient conservées sur ce
            site jusqu’à la fin du séjour de mon enfant.
          </label>
        </fieldset>
        <FicheQuestions />
        {error ? <p className="hint login-error">{error}</p> : null}
        <button className="btn" type="submit" disabled={busy}>
          {busy ? "Génération…" : "Envoyer"}
        </button>
      </form>
    </section>
  );
}
