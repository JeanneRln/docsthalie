"use client";

import { createContext, useContext, useMemo, useState } from "react";

type Account = { first: boolean };

type AppState = {
  accounts: Record<string, Account>;
  completeFirstLogin: (email: string) => void;
  attestations: string[];
  requestAttestation: (id: string) => void;
  ficheSent: boolean;
  markFicheSent: () => void;
  convocationDeposee: boolean;
  deposerConvocation: () => void;
};

const AppContext = createContext<AppState | null>(null);

export function Providers({ children }: { children: React.ReactNode }) {
  const [accounts, setAccounts] = useState<Record<string, Account>>({
    "camille.martin@email.fr": { first: true },
  });
  const [attestations, setAttestations] = useState<string[]>([]);
  const [ficheSent, setFicheSent] = useState(false);
  const [convocationDeposee, setConvocationDeposee] = useState(false);

  const value = useMemo<AppState>(
    () => ({
      accounts,
      completeFirstLogin: (email) => {
        setAccounts((prev) => ({ ...prev, [email]: { first: false } }));
      },
      attestations,
      requestAttestation: (id) =>
        setAttestations((prev) => (prev.includes(id) ? prev : [...prev, id])),
      ficheSent,
      markFicheSent: () => setFicheSent(true),
      convocationDeposee,
      deposerConvocation: () => setConvocationDeposee(true),
    }),
    [accounts, attestations, ficheSent, convocationDeposee],
  );

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useAppState() {
  const state = useContext(AppContext);
  if (!state) throw new Error("useAppState hors du provider");
  return state;
}
