"use client";

import Link from "next/link";
import { Fragment, useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useAppState } from "@/components/Providers";
import { attestationKey, childName, children, seasonalYear, stays, stayById, type ChildId } from "@/lib/sejours";

type Block = {
  childId: ChildId;
  child: string;
  stayId: string;
  title: string;
  when: string;
  year: string;
  sanitaireComplet: boolean;
};

export default function DocumentsPage() {
  const { attestations, requestAttestation, convocationDeposee } = useAppState();
  const search = useSearchParams();
  const router = useRouter();
  const anneeRaw = search.get("annee");
  const enfantParam = search.get("enfant") || "tous";
  const sejourParam = search.get("sejour") || "tous";
  const docs = search.get("docs") || "tous";
  const depuisDossier = search.get("depuis") === "dossier";

  const yearOptions = [...new Set(stays.map((stay) => stay.year))];
  const linkedStay = sejourParam === "tous" ? undefined : stayById(sejourParam);
  const season = seasonalYear();
  const annee =
    anneeRaw === "tous"
      ? "tous"
      : anneeRaw && yearOptions.includes(anneeRaw)
        ? anneeRaw
        : !anneeRaw && linkedStay
          ? linkedStay.year
          : yearOptions.includes(season)
            ? season
            : "tous";
  const childOptions = children.filter((child) =>
    stays.some(
      (stay) =>
        (annee === "tous" || stay.year === annee) && stay.children.some((item) => item.id === child.id),
    ),
  );
  const enfant = childOptions.some((child) => child.id === enfantParam) ? enfantParam : "tous";
  const stayOptions = stays.filter((stay) => {
    if (annee !== "tous" && stay.year !== annee) return false;
    if (enfant !== "tous" && !stay.children.some((item) => item.id === enfant)) return false;
    return true;
  });
  const sejour = stayOptions.some((stay) => stay.id === sejourParam) ? sejourParam : "tous";

  const blocks: Block[] = stays.flatMap((stay) => {
    if (annee !== "tous" && stay.year !== annee) return [];
    if (sejour !== "tous" && stay.id !== sejour) return [];
    return stay.children
      .filter((item) => enfant === "tous" || item.id === enfant)
      .map((item) => ({
        childId: item.id,
        child: childName(item.id),
        stayId: stay.id,
        title: stay.title,
        when: stay.when,
        year: stay.year,
        sanitaireComplet: item.sanitaireComplet,
      }));
  });

  const showSejour = docs !== "admin";
  const showAdmin = docs !== "sejour";
  const visibleStays = stays.filter((stay) => blocks.some((block) => block.stayId === stay.id));

  function update(patch: Record<string, string>) {
    const next = new URLSearchParams(search.toString());
    for (const [key, value] of Object.entries(patch)) {
      if (key === "annee") {
        if (value) next.set(key, value);
        else next.delete(key);
        continue;
      }
      if (!value || value === "tous") next.delete(key);
      else next.set(key, value);
    }
    const query = next.toString();
    router.replace(query ? `/documents?${query}` : "/documents", { scroll: false });
  }

  function onYear(value: string) {
    const patch: Record<string, string> = { annee: value };
    const current = stayById(sejour);
    if (current && value !== "tous" && current.year !== value) patch.sejour = "tous";
    if (
      enfant !== "tous" &&
      value !== "tous" &&
      !stays.some((stay) => stay.year === value && stay.children.some((item) => item.id === enfant))
    ) {
      patch.enfant = "tous";
    }
    update(patch);
  }

  useEffect(() => {
    if (anneeRaw === annee && enfantParam === enfant && sejourParam === sejour) return;
    const next = new URLSearchParams(window.location.search);
    next.set("annee", annee);
    if (enfant === "tous") next.delete("enfant");
    else next.set("enfant", enfant);
    if (sejour === "tous") next.delete("sejour");
    else next.set("sejour", sejour);
    const query = next.toString();
    router.replace(query ? `/documents?${query}` : "/documents", { scroll: false });
  }, [annee, anneeRaw, enfant, enfantParam, sejour, sejourParam, router]);

  function onChild(value: string) {
    const patch: Record<string, string> = { enfant: value };
    const current = stayById(sejour);
    if (current && value !== "tous" && !current.children.some((item) => item.id === value)) {
      patch.sejour = "tous";
    }
    update(patch);
  }

  const backHref = depuisDossier
    ? `/dossier${dossierQuery(enfant, sejour)}`
    : "/enfants";

  return (
    <section>
      <p className="back">
        <Link className="linkish" href={backHref}>
          ← {depuisDossier ? "Dossier" : "Mes enfants"}
        </Link>
      </p>
      <div className="doc-filters" role="group" aria-label="Filtrer les documents">
        <label>
          Année
          <select value={yearOptions.includes(annee) ? annee : "tous"} onChange={(event) => onYear(event.target.value)}>
            <option value="tous">Toutes</option>
            {yearOptions.map((year) => (
              <option key={year} value={year}>
                {year}
              </option>
            ))}
          </select>
        </label>
        <label>
          Enfant
          <select value={childOptions.some((child) => child.id === enfant) ? enfant : "tous"} onChange={(event) => onChild(event.target.value)}>
            <option value="tous">Tous</option>
            {childOptions.map((child) => (
              <option key={child.id} value={child.id}>
                {child.name}
              </option>
            ))}
          </select>
        </label>
        <label>
          Séjour
          <select value={stayOptions.some((stay) => stay.id === sejour) ? sejour : "tous"} onChange={(event) => update({ sejour: event.target.value })}>
            <option value="tous">Tous</option>
            {stayOptions.map((stay) => (
              <option key={stay.id} value={stay.id}>
                {stay.center}
              </option>
            ))}
          </select>
        </label>
        <label>
          Documents
          <select value={docs === "sejour" || docs === "admin" ? docs : "tous"} onChange={(event) => update({ docs: event.target.value })}>
            <option value="tous">Tous</option>
            <option value="sejour">Documents de séjours</option>
            <option value="admin">Documents administratifs &amp; financiers</option>
          </select>
        </label>
      </div>
      {blocks.length === 0 ? <p className="hint">Aucun document pour ces filtres.</p> : null}
      {showSejour && visibleStays.length > 0 ? (
        <>
          <h2 className="doc-section">Documents Séjours</h2>
          <div className="doc-grid">
            {visibleStays.map((stay) => {
              const name = stayLabel(stay.title);
              const complete = blocks.some((block) => block.stayId === stay.id && block.sanitaireComplet);
              return (
                <Fragment key={stay.id}>
                  <DocRow
                    title="Fiche Trousseau - Valise"
                    suffix={name}
                    detail="Pour ce séjour, déposée par le bureau"
                    action="download"
                  />
                  <DocRow title="Lettre du Séjour" suffix={name} detail="Pour ce séjour" action="download" />
                  {complete ? <Convocation stayId={stay.id} suffix={name} deposee={convocationDeposee} /> : null}
                </Fragment>
              );
            })}
          </div>
        </>
      ) : null}
      {showAdmin && blocks.length > 0 ? (
        <>
          <h2 className="doc-section">Documents Administratifs &amp; Financiers</h2>
          <div className="doc-grid">
            {blocks.map((block) => (
              <Attestation
                key={`${block.childId}-${block.stayId}`}
                child={block.child}
                stay={stayLabel(block.title)}
                requested={attestations.includes(attestationKey(block.childId, block.stayId))}
                onRequest={() => requestAttestation(attestationKey(block.childId, block.stayId))}
              />
            ))}
            <DocRow title="Facture" detail="Votre famille" action="download" />
          </div>
        </>
      ) : null}
    </section>
  );
}

function stayLabel(title: string) {
  return title.replace(/\s*\([^)]*\)\s*$/, "");
}

function dossierQuery(enfant: string, sejour: string) {
  const params = new URLSearchParams();
  if (enfant === "tom") params.set("enfant", "tom");
  if (sejour === "passion-2027") params.set("sejour", "passion");
  const query = params.toString();
  return query ? `?${query}` : "";
}

function DocRow({
  title,
  suffix,
  person,
  detail,
  action,
}: {
  title: string;
  suffix?: string;
  person?: boolean;
  detail: string;
  action: "download" | "none";
}) {
  return (
    <article className="card doc">
      <div>
        <strong>{title}</strong>
        {suffix ? <span className={person ? "doc-suffix person" : "doc-suffix"}> - {suffix}</span> : null}
        <small>{detail}</small>
      </div>
      {action === "download" ? (
        <button className="btn small" type="button">
          Télécharger
        </button>
      ) : null}
    </article>
  );
}

function Attestation({
  child,
  stay,
  requested,
  onRequest,
}: {
  child: string;
  stay: string;
  requested: boolean;
  onRequest: () => void;
}) {
  return (
    <article className="card doc">
      <div>
        <strong>Attestation de présence</strong>
        <span className="doc-suffix person"> - {child}</span>
        <small>{requested ? `Demande envoyée au bureau, ${stay}` : stay}</small>
      </div>
      {requested ? (
        <span className="pill wait">Demandée</span>
      ) : (
        <button className="btn small" type="button" onClick={onRequest}>
          Demander
        </button>
      )}
    </article>
  );
}

function Convocation({ stayId, suffix, deposee }: { stayId: string; suffix: string; deposee: boolean }) {
  const chargee = stayId === "studio-theatre-2026" ? deposee : true;
  return (
    <article className="card doc">
      <div>
        <strong>Convocation Transport</strong>
        <span className="doc-suffix"> - {suffix}</span>
        <small>{chargee ? "Chargée" : "Le document n’a pas encore été chargé"}</small>
      </div>
      {chargee ? (
        <button className="btn small" type="button">
          Télécharger
        </button>
      ) : null}
    </article>
  );
}
