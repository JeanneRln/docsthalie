// Types alignés sur docs/database-model-v0.3.md. Aucun ORM. Les identifiants sont des UUID produits par l'application.

export const statutsAdministratifs = ["place_bloquee", "confirmee", "refusee", "annulee", "transferee"] as const;
export type StatutAdministratif = (typeof statutsAdministratifs)[number];

export const statutsFinanciers = ["aucun", "acompte", "solde", "trop_percu", "remboursement_partiel", "rembourse"] as const;
export type StatutFinancier = (typeof statutsFinanciers)[number];

export const statutsDocumentaires = ["manquant", "depose", "copie_en_echec", "en_validation", "a_corriger", "valide"] as const;
export type StatutDocumentaire = (typeof statutsDocumentaires)[number];

export const statutsCommande = ["brouillon", "enregistree", "annulee"] as const;
export type StatutCommande = (typeof statutsCommande)[number];

export const statutsCommerciaux = ["brouillon", "ouverte", "fermee", "annulee"] as const;
export type StatutCommercial = (typeof statutsCommerciaux)[number];

export type Centre = {
  id: string;
  nom: string;
  adresse: string | null;
  slug: string;
};

export type Sejour = {
  id: string;
  centreId: string;
  titre: string;
  slug: string;
  ageMin: number | null;
  ageMax: number | null;
  publie: boolean;
};

export type Session = {
  id: string;
  sejourId: string;
  debut: string;
  fin: string;
  capacite: number;
  placesBloquees: number;
  placesConfirmees: number;
  placesLiberees: number;
  statutCommercial: StatutCommercial;
};

export type Famille = {
  id: string;
  responsableAdministratifId: string | null;
};

export type Adulte = {
  id: string;
  familleId: string;
  prenom: string;
  nom: string;
  email: string | null;
  telephone: string | null;
};

export type Enfant = {
  id: string;
  familleId: string;
  prenom: string;
  nom: string;
  naissance: string | null;
  naissanceIncomplete: boolean;
  sexe: string | null;
};

export type Commande = {
  id: string;
  familleId: string;
  adulteId: string;
  statut: StatutCommande;
};

export type Inscription = {
  id: string;
  commandeId: string;
  familleId: string;
  enfantId: string;
  sejourId: string;
  sessionId: string;
  inscriptionOrigineId: string | null;
  statutAdministratif: StatutAdministratif;
  statutFinancier: StatutFinancier;
  statutDocumentaire: StatutDocumentaire;
  transportAllerId: string | null;
  transportRetourId: string | null;
  contingentId: string | null;
  motifRefus: string | null;
};

// Circuit des pièces déposées par les familles.
// Le site reçoit le fichier, le transmet à FileMaker, puis attend le statut en retour.
// FileMaker seul valide ou demande une correction. Une pièce validée est verrouillée.
// Le bouton « Enregistrer et valider » de la maquette, sur l'écran bureau, reste une démonstration locale.
// Cette validation locale n'est pas le fonctionnement cible et ne fera pas foi.
// Les documents publiés par Thalie suivent un autre circuit : ils sont déposés depuis admin.thalie.org.

export const typesPiecesConnus = [
  "fiche_sanitaire",
  "droit_image",
  "regime",
  "vaccination",
  "secu",
  "mutuelle",
  "ordonnance",
  "pai",
  "pass_nautique",
] as const;
export type TypePieceConnu = (typeof typesPiecesConnus)[number];

export const codesDeclaration = ["pas_de_pai", "aucun_traitement", "refus_justificatif"] as const;
export type CodeDeclaration = (typeof codesDeclaration)[number];

export const decisionsPiece = ["valide", "a_corriger"] as const;
export type DecisionPieceValeur = (typeof decisionsPiece)[number];

export type TypePiece = {
  type: string;
  libelle: string;
  autoriseDeclaration: boolean;
};

export type ExigenceDocumentaire = {
  id: string;
  type: string;
  sejourId: string | null;
  sessionId: string | null;
  obligatoire: boolean;
  bloqueConvocation: boolean;
};

export type Piece = {
  id: string;
  inscriptionId: string;
  type: string;
  statut: StatutDocumentaire;
  verrouilleLe: string | null;
};

export type FichierPiece = {
  id: string;
  pieceId: string;
  numeroVersion: number;
  cleStockage: string;
  nomOriginal: string;
};

export type DeclarationPiece = {
  id: string;
  pieceId: string;
  code: CodeDeclaration;
  texteAccepte: string;
  accepteLe: string;
};

export type DecisionPiece = {
  id: string;
  pieceId: string;
  decision: DecisionPieceValeur;
  motif: string | null;
  creeLe: string;
};

export type DocumentPublie = {
  id: string;
  type: string;
  cleStockage: string;
  visible: boolean;
} & (
  | { centreId: string; sejourId: null; sessionId: null; inscriptionId: null }
  | { centreId: null; sejourId: string; sessionId: null; inscriptionId: null }
  | { centreId: null; sejourId: null; sessionId: string; inscriptionId: null }
  | { centreId: null; sejourId: null; sessionId: null; inscriptionId: string }
);

export type VersionDocumentPublie = {
  id: string;
  documentId: string;
  numeroVersion: number;
  cleStockage: string;
};
