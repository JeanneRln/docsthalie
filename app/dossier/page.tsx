"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { useSearchParams } from "next/navigation";
import { useAppState } from "@/components/Providers";
import { FicheQuestions, submitFiche } from "@/components/FicheForm";

export default function DossierPage() {
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
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [filesLocked, setFilesLocked] = useState(false);
  const [filesError, setFilesError] = useState("");
  const choices = useRef({ secu: false, vaccin: false, mutuelle: false, ordonnance: false, pai: false });

  function validateFiles() {
    const required = lea
      ? (["secu", "vaccin", "mutuelle", "ordonnance", "pai"] as const)
      : (["vaccin", "ordonnance", "pai"] as const);
    if (required.some((key) => !choices.current[key])) {
      setFilesError("Indiquez un choix pour chaque document avant de valider.");
      return;
    }
    setFilesError("");
    setFilesLocked(true);
  }

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
      <ol className="steps">
        <li>
          <strong>Documents à envoyer.</strong> Un choix pour chaque ligne, puis « Enregistrer et valider ». Ensuite, ces
          choix ne peuvent plus être modifiés.
        </li>
        <li>
          <strong>Fiche sanitaire.</strong> Remplissez-la, cochez la case qui vaut signature, puis envoyez-la.
        </li>
      </ol>
      <div className="note">
        <p>
          Votre enfant est inscrit sur l’un de nos séjours. Merci de fournir les documents demandés ci-dessous et remplir
          le questionnaire qui permettra d’éditer la Fiche Sanitaire de votre enfant.
        </p>
        <p>
          Les régimes alimentaires et les allergies qui n’ont pas été indiqués au préalable ne pourront pas être pris en
          compte par les équipes de cuisine. Si le départ a lieu dans moins de 4 jours, les spécificités ne sont plus
          modifiées.
        </p>
      </div>
      <aside className="card dossier-files">
        <h2 className="side-title">Documents à envoyer</h2>
        <fieldset className={filesLocked ? "locked" : undefined} disabled={filesLocked}>
          {filesLocked ? <legend>Validé, plus modifiable</legend> : null}
        <div className="files">
          {lea ? (
            <>
              <CoverageFile title="Attestation sécu" onReady={(ready) => { choices.current.secu = ready; }} />
              <VaccineFile onReady={(ready) => { choices.current.vaccin = ready; }} />
              <CoverageFile title="Mutuelle" onReady={(ready) => { choices.current.mutuelle = ready; }} />
              <OrdonnanceFile onReady={(ready) => { choices.current.ordonnance = ready; }} />
              <PaiFile onReady={(ready) => { choices.current.pai = ready; }} />
              <div className="file">
                <div>
                  <strong>Pass nautique</strong>
                  <span>Séjours nautiques seulement</span>
                </div>
                <span className="pill opt">Non demandé</span>
              </div>
            </>
          ) : (
            <>
              <div className="file">
                <div>
                  <strong>Attestation sécu</strong>
                  <span>Validée le 12 septembre, plus modifiable</span>
                </div>
                <span className="pill ok">Validée</span>
              </div>
              <VaccineFile
                initial={[{ name: "photo-carnet.jpg", note: "Photo illisible" }]}
                onReady={(ready) => { choices.current.vaccin = ready; }}
              />
              <div className="file">
                <div>
                  <strong>Mutuelle</strong>
                  <span>Facultatif</span>
                </div>
                <span className="pill opt">Facultatif</span>
              </div>
              <OrdonnanceFile onReady={(ready) => { choices.current.ordonnance = ready; }} />
              <PaiFile onReady={(ready) => { choices.current.pai = ready; }} />
              <div className="file">
                <div>
                  <strong>Pass nautique</strong>
                  <span>Séjours nautiques seulement</span>
                </div>
                <span className="pill opt">Non demandé</span>
              </div>
            </>
          )}
        </div>
        </fieldset>
        {filesLocked ? null : (
          <p className="hint">
            {lea
              ? "Choisissez une option pour chaque document, puis enregistrez."
              : "La relance du 11 octobre concerne le carnet de vaccination. Choisissez ensuite une option pour chaque document, puis enregistrez."}
          </p>
        )}
        {filesError ? <p className="hint login-error">{filesError}</p> : null}
        {filesLocked ? null : (
          <button className="btn files-save" type="button" onClick={validateFiles}>
            Enregistrer et valider
          </button>
        )}
      </aside>
      <form className="card dossier-form" onSubmit={onSubmit}>
        <h2 className="side-title">Remplir la fiche sanitaire numériquement</h2>
        {ficheSent ? <p className="hint">PDF généré, en attente de validation par le bureau.</p> : null}
        <FicheQuestions />
        {error ? <p className="hint login-error">{error}</p> : null}
        <button className="btn" type="submit" disabled={busy}>
          {busy ? "Génération…" : "Envoyer la fiche"}
        </button>
      </form>
      <aside className="card dossier-consent">
        <h2 className="side-title">Droit à l’image et données personnelles</h2>
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
      </aside>
    </section>
  );
}

function useReport(ready: boolean, onReady?: (ready: boolean) => void) {
  useEffect(() => {
    onReady?.(ready);
  }, [ready, onReady]);
}

function VaccineFile({
  initial = [],
  onReady,
}: {
  initial?: { name: string; note?: string }[];
  onReady?: (ready: boolean) => void;
}) {
  const [files, setFiles] = useState(initial);
  const inputRef = useRef<HTMLInputElement>(null);
  const needsFix = files.some((file) => file.note);
  useReport(files.length > 0, onReady);

  function add(list: FileList | null) {
    if (!list || list.length === 0) return;
    setFiles((current) => [...current, ...[...list].map((file) => ({ name: file.name }))]);
  }

  return (
    <div className="file wide">
      <div>
        <strong>Carnet de vaccination</strong>
        <span>Obligatoire. Ajoutez autant de documents que nécessaire.</span>
        {files.length > 0 ? (
          <ul className="added-files">
            {files.map((file, index) => (
              <li key={`${file.name}-${index}`}>
                <span>{file.name}</span>
                {file.note ? <em>{file.note}</em> : null}
                <button type="button" onClick={() => setFiles((current) => current.filter((_, item) => item !== index))}>
                  Retirer
                </button>
              </li>
            ))}
          </ul>
        ) : null}
        <button className="btn small" type="button" onClick={() => inputRef.current?.click()}>
          Ajouter un document
        </button>
        <input
          ref={inputRef}
          className="file-input"
          type="file"
          multiple
          onChange={(event) => {
            add(event.target.files);
            event.target.value = "";
          }}
        />
      </div>
      <span className={`pill ${files.length === 0 ? "miss" : needsFix ? "wait" : "ok"}`}>
        {files.length === 0 ? "À charger" : needsFix ? "À corriger" : "Chargé"}
      </span>
    </div>
  );
}

function OrdonnanceFile({ onReady }: { onReady?: (ready: boolean) => void }) {
  const [mode, setMode] = useState<"" | "oui" | "non">("");
  const [fileName, setFileName] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const sent = mode === "oui" && Boolean(fileName);
  const declined = mode === "non";
  useReport(sent || declined, onReady);

  return (
    <div className="file wide">
      <div>
        <strong>Ordonnance</strong>
        <span>Ajoutez l’ordonnance, ou indiquez qu’aucun traitement ne sera pris pendant le séjour.</span>
        <div className="add-line">
          <label className="yn">
            <input type="radio" name="ordonnance" checked={mode === "oui"} onChange={() => setMode("oui")} />
            Ajouter un document
          </label>
          {mode === "oui" ? (
            <button className="btn small" type="button" onClick={() => inputRef.current?.click()}>
              Ajouter un document
            </button>
          ) : null}
        </div>
        <input
          ref={inputRef}
          className="file-input"
          type="file"
          onChange={(event) => setFileName(event.target.files?.[0]?.name ?? "")}
        />
        {mode === "oui" && fileName ? <span className="added-name">{fileName}</span> : null}
        <label className="choice">
          <input type="radio" name="ordonnance" checked={mode === "non"} onChange={() => setMode("non")} />
          L’enfant ne prendra pas de traitement pendant le séjour, même des médicaments habituellement achetés sans
          ordonnance (paracétamol, Spasfon, etc.).
        </label>
      </div>
      <span className={`pill ${sent ? "ok" : declined ? "wait" : "miss"}`}>
        {sent ? "Chargée" : declined ? "Sans traitement" : "À charger"}
      </span>
    </div>
  );
}

function PaiFile({ onReady }: { onReady?: (ready: boolean) => void }) {
  const [mode, setMode] = useState<"" | "oui" | "non">("");
  const [fileName, setFileName] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const sent = mode === "oui" && Boolean(fileName);
  const declined = mode === "non";
  useReport(sent || declined, onReady);

  return (
    <div className="file wide">
      <div>
        <strong>PAI</strong>
        <span>Ajoutez le PAI, ou indiquez que votre enfant n’en a pas.</span>
        <div className="add-line">
          <label className="yn">
            <input type="radio" name="pai" checked={mode === "oui"} onChange={() => setMode("oui")} />
            Ajouter un document
          </label>
          {mode === "oui" ? (
            <button className="btn small" type="button" onClick={() => inputRef.current?.click()}>
              Ajouter un document
            </button>
          ) : null}
        </div>
        <input
          ref={inputRef}
          className="file-input"
          type="file"
          onChange={(event) => setFileName(event.target.files?.[0]?.name ?? "")}
        />
        {mode === "oui" && fileName ? <span className="added-name">{fileName}</span> : null}
        <label className="choice">
          <input type="radio" name="pai" checked={mode === "non"} onChange={() => setMode("non")} />
          Mon enfant n’a pas de PAI
        </label>
      </div>
      <span className={`pill ${sent ? "ok" : declined ? "wait" : "miss"}`}>
        {sent ? "Chargé" : declined ? "Pas de PAI" : "À charger"}
      </span>
    </div>
  );
}

function CoverageFile({ title, onReady }: { title: string; onReady?: (ready: boolean) => void }) {
  const [mode, setMode] = useState<"" | "oui" | "non">("");
  const [accepted, setAccepted] = useState(false);
  const [fileName, setFileName] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const name = title.toLowerCase().replace(/\s+/g, "-");
  const sent = mode === "oui" && Boolean(fileName);
  useReport(sent || (mode === "non" && accepted), onReady);

  return (
    <div className="file wide">
      <div>
        <strong>{title}</strong>
        <span>Ajoutez le document, ou indiquez que vous ne le fournissez pas.</span>
        <div className="add-line">
          <label className="yn">
            <input type="radio" name={name} checked={mode === "oui"} onChange={() => setMode("oui")} />
            Ajouter un document
          </label>
          {mode === "oui" ? (
            <button className="btn small" type="button" onClick={() => inputRef.current?.click()}>
              Ajouter un document
            </button>
          ) : null}
        </div>
        <input
          ref={inputRef}
          className="file-input"
          type="file"
          onChange={(event) => setFileName(event.target.files?.[0]?.name ?? "")}
        />
        {mode === "oui" && fileName ? <span className="added-name">{fileName}</span> : null}
        <label className="choice">
          <input type="radio" name={name} checked={mode === "non"} onChange={() => setMode("non")} />
          Je ne le fournis pas
        </label>
        {mode === "non" ? (
          <label className="choice">
            <input type="checkbox" checked={accepted} onChange={(event) => setAccepted(event.target.checked)} />
            Je reconnais qu’en refusant de téléverser ce document, cela pourra amener Thalie à avancer des frais
            médicaux sur place, qu’il vous faudra rembourser en échange des feuilles de soins et des factures.
          </label>
        ) : null}
      </div>
      <span className={`pill ${sent ? "ok" : mode === "non" && accepted ? "wait" : "miss"}`}>
        {sent ? "Chargé" : mode === "non" && accepted ? "Non fourni" : "À charger"}
      </span>
    </div>
  );
}
