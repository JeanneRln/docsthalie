"use client";

import type { ReactNode } from "react";
import { generateFichePdf, openPdf, type FicheAnswers } from "@/lib/generateFiche";

function YesNo({ name, defaultValue }: { name: string; defaultValue?: "oui" | "non" }) {
  return (
    <div className="yn">
      <label className="yn">
        <input type="radio" name={name} value="oui" defaultChecked={defaultValue === "oui"} /> Oui
      </label>
      <label className="yn">
        <input type="radio" name={name} value="non" defaultChecked={defaultValue === "non"} /> Non
      </label>
    </div>
  );
}

function text(data: FormData, name: string) {
  return String(data.get(name) ?? "").trim();
}

export async function submitFiche(
  form: HTMLFormElement,
  identity: { nom: string; prenom: string; naissance: string; sexe: string; sejour: string },
): Promise<string | null> {
  const data = new FormData(form);
  if (data.get("fs-signe") !== "on") {
    return "Cochez la case de signature pour générer la fiche.";
  }
  const answers: FicheAnswers = {
    nom: identity.nom,
    prenom: identity.prenom,
    sejour: identity.sejour,
    naissance: identity.naissance,
    sexe: identity.sexe,
    diph: text(data, "v-diph"),
    diphDate: text(data, "vd-diph"),
    tet: text(data, "v-tet"),
    tetDate: text(data, "vd-tet"),
    pol: text(data, "v-pol"),
    polDate: text(data, "vd-pol"),
    dtp: text(data, "v-dtp"),
    dtpDate: text(data, "vd-dtp"),
    tetra: text(data, "v-tetra"),
    tetraDate: text(data, "vd-tetra"),
    hep: text(data, "vd-hep"),
    bcg: text(data, "vd-bcg"),
    ror: text(data, "vd-ror"),
    coq: text(data, "vd-coq"),
    trait: text(data, "fs-trait"),
    traitDetail: text(data, "fs-trait-detail"),
    rubeole: text(data, "m-rubeole"),
    varicelle: text(data, "m-varicelle"),
    angine: text(data, "m-angine"),
    rhum: text(data, "m-rhum"),
    scar: text(data, "m-scar"),
    coqueluche: text(data, "m-coq"),
    otite: text(data, "m-otite"),
    rougeole: text(data, "m-roug"),
    oreillons: text(data, "m-ore"),
    rnom: text(data, "fs-rnom"),
    rpre: text(data, "fs-rpre"),
    adr: text(data, "fs-adr"),
    tel: text(data, "fs-tel"),
    port: text(data, "fs-port"),
    urg: text(data, "fs-urg"),
    asthme: text(data, "fs-asthme"),
    asthmeAll: data.get("fs-asthme-all") === "on",
    asthmeEff: data.get("fs-asthme-eff") === "on",
    alim: text(data, "fs-alim"),
    med: text(data, "fs-med"),
    aut: text(data, "fs-aut"),
    cause: text(data, "fs-cause"),
    paiAll: text(data, "fs-pai-all"),
    paiAut: text(data, "fs-pai-aut"),
    patho: text(data, "fs-patho"),
    hosp: text(data, "fs-hosp"),
    hospMotif: text(data, "fs-hosp-motif"),
    ecole: text(data, "fs-ecole"),
    reg: text(data, "fs-reg"),
    regLequel: text(data, "fs-reg-lequel"),
    reco: text(data, "fs-reco"),
    acc: text(data, "fs-acc"),
  };
  const fileName = identity.prenom === "Léa" ? "lea" : identity.prenom.toLowerCase();
  try {
    const bytes = await generateFichePdf(answers);
    openPdf(bytes, `fiche-sanitaire-${fileName}-martin.pdf`);
    return null;
  } catch {
    return "Le PDF n’a pas pu être généré. Réessayez dans un instant.";
  }
}

function Vax({ name, dateName, label }: { name: string; dateName: string; label: string }) {
  return (
    <div className="vax">
      <span>{label}</span>
      <YesNo name={name} />
      <input name={dateName} placeholder="Date" />
    </div>
  );
}

function Question({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="q-line">
      <span>{label}</span>
      {children}
    </div>
  );
}

export function FicheQuestions() {
  return (
    <>
        <h3 className="bloc">Vaccinations</h3>
        <p className="hint">
          Se référer au carnet de santé ou aux certificats de vaccinations de l’enfant et en joindre une copie.
        </p>
        <h3 className="bloc">Vaccins obligatoires</h3>
        <p className="hint">Dates derniers rappels</p>
        <div className="vax-grid">
          <Vax name="v-diph" dateName="vd-diph" label="Diphtérie" />
          <Vax name="v-tet" dateName="vd-tet" label="Tétanos" />
          <Vax name="v-pol" dateName="vd-pol" label="Poliomyélite" />
          <Vax name="v-dtp" dateName="vd-dtp" label="ou DTP" />
          <Vax name="v-tetra" dateName="vd-tetra" label="ou Tétracoq" />
        </div>
        <p className="hint">
          Si l’enfant n’a pas les vaccins obligatoires, joindre un certificat médical de contre-indication.
        </p>
        <p className="hint">Attention, le vaccin anti-tétanique ne présente aucune contre-indication.</p>
        <h3 className="bloc">Vaccins recommandés</h3>
        <div className="date-grid">
          <div>
            <label htmlFor="vd-hep">Hépatite B</label>
            <input id="vd-hep" name="vd-hep" placeholder="Date" />
          </div>
          <div>
            <label htmlFor="vd-bcg">BCG</label>
            <input id="vd-bcg" name="vd-bcg" placeholder="Date" />
          </div>
          <div>
            <label htmlFor="vd-ror">Rubéole Oreillons Rougeole</label>
            <input id="vd-ror" name="vd-ror" placeholder="Date" />
          </div>
          <div>
            <label htmlFor="vd-coq">Coqueluche</label>
            <input id="vd-coq" name="vd-coq" placeholder="Date" />
          </div>
          <div>
            <label htmlFor="vd-autres">Autres</label>
            <input id="vd-autres" name="vd-autres" placeholder="Date" />
          </div>
        </div>

        <h3 className="bloc">Renseignements médicaux concernant l’enfant</h3>
        <Question label="L’enfant suit-il un traitement médical pendant le séjour ?">
          <YesNo name="fs-trait" defaultValue="non" />
        </Question>
        <p className="hint">
          Si oui, joindre impérativement l’ordonnance médicale à l’envoi numérique de cette fiche.
        </p>
        <p className="hint">
          Les médicaments correspondants devront être remis le premier jour à l’équipe dans leur emballage d’origine
          marqué au nom de l’enfant.
        </p>
        <p className="hint">Aucun médicament ne pourra être pris sans ordonnance.</p>

        <h3 className="bloc">L’enfant a-t-il déjà eu les maladies suivantes ?</h3>
        <div className="ill-grid">
          <Question label="Rubéole"><YesNo name="m-rubeole" /></Question>
          <Question label="Varicelle"><YesNo name="m-varicelle" /></Question>
          <Question label="Angine"><YesNo name="m-angine" /></Question>
          <Question label="Rhumatismes"><YesNo name="m-rhum" /></Question>
          <Question label="Scarlatine"><YesNo name="m-scar" /></Question>
          <Question label="Coqueluche"><YesNo name="m-coq" /></Question>
          <Question label="Otite"><YesNo name="m-otite" /></Question>
          <Question label="Rougeole"><YesNo name="m-roug" /></Question>
          <Question label="Oreillons"><YesNo name="m-ore" /></Question>
        </div>

        <h3 className="bloc">Responsable de l’enfant</h3>
        <div className="pair">
          <div>
            <label htmlFor="fs-rnom">Nom</label>
            <input id="fs-rnom" name="fs-rnom" defaultValue="Martin" />
          </div>
          <div>
            <label htmlFor="fs-rpre">Prénom</label>
            <input id="fs-rpre" name="fs-rpre" defaultValue="Camille" />
          </div>
          <div>
            <label htmlFor="fs-tel">Tel domicile</label>
            <input id="fs-tel" name="fs-tel" defaultValue="01 42 00 00 00" />
          </div>
          <div>
            <label htmlFor="fs-port">Portable</label>
            <input id="fs-port" name="fs-port" defaultValue="06 12 34 56 78" />
          </div>
        </div>
        <label htmlFor="fs-adr">Adresse</label>
        <input className="compact" id="fs-adr" name="fs-adr" defaultValue="12 rue des Arts, 75011 Paris" />
        <label htmlFor="fs-urg">Autre personne à contacter en cas d’urgence (nom et tel)</label>
        <input className="compact" id="fs-urg" name="fs-urg" defaultValue="Alex Martin 06 98 76 54 32" />

        <h3 className="bloc">Indiquez ici les difficultés de santé</h3>
        <p className="hint">Ces rubriques sont importantes pour accueillir au mieux votre enfant.</p>
        <Question label="Asthme">
          <YesNo name="fs-asthme" defaultValue="non" />
        </Question>
        <div className="yn follow">
          <span>si oui :</span>
          <label className="yn">
            <input type="checkbox" name="fs-asthme-all" /> allergique
          </label>
          <label className="yn">
            <input type="checkbox" name="fs-asthme-eff" /> à l’effort
          </label>
        </div>
        <h3 className="bloc">Allergies</h3>
        <Question label="Alimentaires">
          <YesNo name="fs-alim" defaultValue="oui" />
        </Question>
        <Question label="Médicamenteuses">
          <YesNo name="fs-med" defaultValue="non" />
        </Question>
        <Question label="Autres">
          <YesNo name="fs-aut" defaultValue="non" />
        </Question>
        <label htmlFor="fs-cause">Précisez la cause de l’allergie</label>
        <input className="compact" id="fs-cause" name="fs-cause" defaultValue="Fruits à coque" />
        <Question label="Votre enfant a-t-il un PAI pour son allergie ?">
          <YesNo name="fs-pai-all" defaultValue="non" />
        </Question>
        <p className="hint">Si oui, merci de le joindre impérativement avec l’ordonnance si besoin.</p>
        <Question label="Votre enfant a-t-il un PAI ou un traitement ou est-il suivi pour un autre motif ?">
          <YesNo name="fs-pai-aut" defaultValue="non" />
        </Question>
        <label htmlFor="fs-patho">Si oui, pour quelle pathologie</label>
        <input className="compact" id="fs-patho" name="fs-patho" />
        <p className="hint">
          (épilepsie stabilisée, TDAH, suivi psychologique, maladie chronique, TSA, syndromes, anxiété, fin de traitement
          maladie...)
        </p>
        <h3 className="bloc">Antécédents</h3>
        <Question label="Votre enfant a-t-il été hospitalisé dans les 2 dernières années ?">
          <YesNo name="fs-hosp" defaultValue="non" />
        </Question>
        <label htmlFor="fs-hosp-motif">
          Si oui, pour quel motif (opération, affection de longue durée, convulsions, suivi psychologique...)
        </label>
        <input className="compact" id="fs-hosp-motif" name="fs-hosp-motif" />
        <label htmlFor="fs-ecole">Comment s’est déroulée l’année scolaire en cours de votre enfant ?</label>
        <textarea id="fs-ecole" name="fs-ecole" rows={2} />
        <p className="hint">(RAS, harcèlement, isolement, crises d’angoisses, HPI, etc...)</p>
        <h3 className="bloc">Autres informations</h3>
        <Question label="Votre enfant suit-il un régime alimentaire spécifique ?">
          <YesNo name="fs-reg" defaultValue="oui" />
        </Question>
        <label htmlFor="fs-reg-lequel">Si oui, lequel</label>
        <select className="compact" id="fs-reg-lequel" name="fs-reg-lequel" defaultValue="Sans porc">
          <option>Sans régime</option>
          <option>Sans porc</option>
          <option>Sans viande</option>
          <option>Végétarien</option>
        </select>
        <p className="hint">
          Nous pouvons fournir des menus spécifiques sans porc, mais pour les inscrits qui indiquent ne pas manger de
          viande, nous compenserons avec des laitages et des légumes.
        </p>
        <h3 className="bloc">Recommandations utiles des parents</h3>
        <p className="hint">
          Votre enfant porte-t-il des lentilles, des lunettes, des prothèses auditives, des prothèses dentaires ? A-t-il
          peur du noir ? Est-il somnambule ? A-t-il un suivi psychologique ? Mouille-t-il son lit ? Est-il ultra-sensible
          ? ...
        </p>
        <textarea id="fs-reco" name="fs-reco" rows={2} />
        <Question label="Votre enfant a-t-il besoin d’un accompagnement spécifique ?">
          <YesNo name="fs-acc" defaultValue="non" />
        </Question>
        <p className="hint">(handicap, maladie)</p>
        <h3 className="bloc">Si traitement suivi par votre enfant, merci de nous l’indiquer précisément</h3>
        <p className="hint">(noms des médicaments et posologie)</p>
        <textarea id="fs-trait-detail" name="fs-trait-detail" rows={2} />
        <p className="hint">Attention, ne pas fournir de pilulier, mais bien les médicaments dans leur boîte d’origine.</p>

        <h3 className="bloc">Signature</h3>
        <p className="legal">
          Je, soussigné(e) <span className="person">Camille Martin</span>, responsable légal de l’enfant, déclare exacts
          les renseignements portés sur cette fiche, m’engage à les réactualiser si nécessaire et autorise le responsable
          du séjour à prendre, le cas échéant, toutes mesures (traitement médical, hospitalisation, intervention
          médicale) rendues nécessaires par l’état de l’enfant.
        </p>
        <label className="choice">
          <input type="checkbox" name="fs-signe" /> Cette case vaut signature, le 29 septembre 2026.
        </label>
    </>
  );
}
