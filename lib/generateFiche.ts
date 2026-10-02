import { PDFDocument, StandardFonts, rgb, type PDFPage } from "pdf-lib";

export type FicheAnswers = {
  nom: string;
  prenom: string;
  sejour: string;
  naissance: string;
  sexe: string;
  diph: string;
  diphDate: string;
  tet: string;
  tetDate: string;
  pol: string;
  polDate: string;
  dtp: string;
  dtpDate: string;
  tetra: string;
  tetraDate: string;
  hep: string;
  bcg: string;
  ror: string;
  coq: string;
  trait: string;
  traitDetail: string;
  rubeole: string;
  varicelle: string;
  angine: string;
  rhum: string;
  scar: string;
  coqueluche: string;
  otite: string;
  rougeole: string;
  oreillons: string;
  rnom: string;
  rpre: string;
  adr: string;
  tel: string;
  port: string;
  urg: string;
  asthme: string;
  asthmeAll: boolean;
  asthmeEff: boolean;
  alim: string;
  med: string;
  aut: string;
  cause: string;
  paiAll: string;
  paiAut: string;
  patho: string;
  hosp: string;
  hospMotif: string;
  ecole: string;
  reg: string;
  regLequel: string;
  reco: string;
  acc: string;
};

function clean(value: string) {
  return value.replace(/œ/g, "oe").replace(/Œ/g, "OE");
}

export async function fillFichePdf(template: ArrayBuffer | Uint8Array, answers: FicheAnswers) {
  const pdf = await PDFDocument.load(template);
  const font = await pdf.embedFont(StandardFonts.Helvetica);
  const pages = pdf.getPages();
  const ink = rgb(0.05, 0.15, 0.45);
  const p1 = pages[0];
  const p2 = pages[1];

  function write(page: PDFPage, value: string, x: number, y: number, size = 9) {
    if (!value) return;
    page.drawText(clean(value), { x, y: y + 4, size, font, color: ink });
  }
  function mark(page: PDFPage, x: number, y: number) {
    if (!Number.isFinite(x)) return;
    page.drawText("X", { x: x + 1, y: y + 6, size: 9, font, color: ink });
  }
  function yn(page: PDFPage, value: string, xYes: number, xNo: number, y: number) {
    if (value === "oui") mark(page, xYes, y);
    if (value === "non") mark(page, xNo, y);
  }

  write(p1, answers.nom, 330, 812);
  write(p1, answers.prenom, 330, 798);
  write(p1, answers.naissance, 340, 785);
  if (answers.sexe === "garcon") mark(p1, 352, 766);
  if (answers.sexe === "fille") mark(p1, 440, 766);
  write(p1, answers.sejour, 270, 712);
  (
    [
      [answers.diph, answers.diphDate, 581],
      [answers.tet, answers.tetDate, 564],
      [answers.pol, answers.polDate, 549],
      [answers.dtp, answers.dtpDate, 533],
      [answers.tetra, answers.tetraDate, 517],
    ] as const
  ).forEach(([value, date, y]) => {
    yn(p1, value, 178, 210, y);
    write(p1, date, 248, y);
  });
  write(p1, answers.hep, 500, 581);
  write(p1, answers.bcg, 500, 565);
  write(p1, answers.ror, 500, 549);
  write(p1, answers.coq, 500, 533);
  yn(p1, answers.trait, 365, 425, 436);
  (
    [
      [answers.rubeole, 38, 86, 304],
      [answers.varicelle, 141, 188, 304],
      [answers.angine, 252, 299, 304],
      [answers.rhum, 367, 414, 304],
      [answers.scar, 478, 525, 304],
      [answers.coqueluche, 39, 86, 260],
      [answers.otite, 142, 189, 260],
      [answers.rougeole, 252, 299, 260],
      [answers.oreillons, 367, 414, 260],
    ] as const
  ).forEach(([value, xYes, xNo, y]) => yn(p1, value, xYes, xNo, y));
  write(p1, answers.rnom, 78, 214);
  write(p1, answers.rpre, 365, 214);
  write(p1, answers.adr, 105, 196);
  write(p1, answers.tel, 125, 171);
  write(p1, answers.port, 375, 169);
  write(p1, answers.urg, 400, 152, 8);
  write(p1, "Camille Martin", 145, 122);
  write(p1, "29/09/2026", 78, 57);
  write(p1, "Case cochée valant signature", 365, 57, 8);

  yn(p2, answers.asthme, 205, 136, 765);
  if (answers.asthmeAll) mark(p2, 345, 766);
  if (answers.asthmeEff) mark(p2, 458, 766);
  yn(p2, answers.alim, 207, 138, 724);
  yn(p2, answers.med, 468, 398, 724);
  yn(p2, answers.aut, 207, 138, 703);
  write(p2, answers.cause, 210, 677);
  yn(p2, answers.paiAll, 349, 280, 655);
  yn(p2, answers.paiAut, 494, 425, 611);
  write(p2, answers.patho, 175, 595);
  yn(p2, answers.hosp, 413, 344, 519);
  write(p2, answers.hospMotif, 40, 482);
  write(p2, answers.ecole, 40, 425);
  yn(p2, answers.reg, 367, 298, 373);
  write(p2, answers.regLequel, 110, 355);
  write(p2, answers.reco, 40, 230);
  yn(p2, answers.acc, 413, 344, 166);
  write(p2, answers.traitDetail, 40, 78);

  return pdf.save();
}

export async function generateFichePdf(answers: FicheAnswers) {
  const response = await fetch("/fiche/modele.pdf");
  if (!response.ok) throw new Error("modele");
  return fillFichePdf(await response.arrayBuffer(), answers);
}

export function openPdf(bytes: Uint8Array, filename: string) {
  const copy = new Uint8Array(bytes);
  const blob = new Blob([copy.buffer], { type: "application/pdf" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  window.open(url, "_blank");
}
