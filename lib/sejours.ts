export type ChildId = "lea" | "tom";

export const children: { id: ChildId; name: string }[] = [
  { id: "lea", name: "Léa Martin" },
  { id: "tom", name: "Tom Martin" },
];

export type StayChild = { id: ChildId; sanitaireComplet: boolean };

export type Stay = {
  id: string;
  title: string;
  center: string;
  when: string;
  year: string;
  children: StayChild[];
};

export const stays: Stay[] = [
  {
    id: "passion-2027",
    title: "Passion Cinéma (Menton)",
    center: "Menton",
    when: "du 14 au 20 février 2027",
    year: "2027",
    children: [
      { id: "lea", sanitaireComplet: false },
      { id: "tom", sanitaireComplet: false },
    ],
  },
  {
    id: "studio-theatre-2026",
    title: "Studio Théâtre (Bois)",
    center: "Bois",
    when: "du 18 au 24 octobre 2026",
    year: "2026",
    children: [
      { id: "lea", sanitaireComplet: false },
      { id: "tom", sanitaireComplet: true },
    ],
  },
  {
    id: "vie-artiste-2025",
    title: "La Vie d'Artiste Danse Classique (Bernay)",
    center: "Bernay",
    when: "Été 2025",
    year: "2025",
    children: [
      { id: "lea", sanitaireComplet: true },
      { id: "tom", sanitaireComplet: true },
    ],
  },
  {
    id: "studio-danse-2024",
    title: "Studio Danse Classique (Bois)",
    center: "Bois",
    when: "Automne 2024",
    year: "2024",
    children: [{ id: "lea", sanitaireComplet: true }],
  },
];

export function childName(id: string) {
  return children.find((child) => child.id === id)?.name ?? id;
}

export function stayById(id: string) {
  return stays.find((stay) => stay.id === id);
}

export function seasonalYear(date = new Date()) {
  const year = date.getFullYear();
  const month = date.getMonth();
  const day = date.getDate();
  const upcoming = month > 10 || (month === 10 && day >= 15);
  return String(upcoming ? year + 1 : year);
}

export function attestationKey(childId: string, stayId: string) {
  return `${childId}:${stayId}`;
}
