"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAppState } from "@/components/Providers";

export default function LoginPage() {
  const router = useRouter();
  const { accounts, completeFirstLogin } = useAppState();
  const [step, setStep] = useState<"login" | "password">("login");
  const [email, setEmail] = useState("camille.martin@email.fr");
  const [error, setError] = useState(false);
  const [mismatch, setMismatch] = useState(false);

  function onSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const account = accounts[email.trim().toLowerCase()];
    if (!account) {
      setError(true);
      return;
    }
    setError(false);
    if (account.first) {
      setStep("password");
      return;
    }
    router.push("/enfants");
  }

  function onSavePassword(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    const created = String(data.get("new-password") ?? "");
    const confirmed = String(data.get("confirm-password") ?? "");
    if (!created || created !== confirmed) {
      setMismatch(true);
      return;
    }
    setMismatch(false);
    completeFirstLogin(email.trim().toLowerCase());
    router.push("/enfants");
  }

  return (
    <section className="screen-login">
      <h1>Connexion</h1>
      {step === "login" ? (
        <form className="card login-card" onSubmit={onSubmit}>
          <label htmlFor="email">Email</label>
          <input
            id="email"
            name="email"
            type="email"
            value={email}
            autoComplete="username"
            onChange={(event) => setEmail(event.target.value)}
          />
          <label htmlFor="password">Mot de passe</label>
          <input id="password" name="password" type="password" autoComplete="current-password" />
          <button className="btn" type="submit">
            Se connecter
          </button>
          {error ? (
            <p className="hint login-error">
              Cette adresse ne correspond à aucun compte client. Pour une demande de réservation, contactez{" "}
              <a href="mailto:monsejour@thalie.org">monsejour@thalie.org</a>.
            </p>
          ) : null}
        </form>
      ) : (
        <form className="card login-card" onSubmit={onSavePassword}>
          <p className="hint">Première connexion. Choisissez un mot de passe pour ce compte.</p>
          <label htmlFor="new-password">Nouveau mot de passe</label>
          <input id="new-password" name="new-password" type="password" autoComplete="new-password" />
          <label htmlFor="confirm-password">Confirmez le mot de passe</label>
          <input id="confirm-password" name="confirm-password" type="password" autoComplete="new-password" />
          <button className="btn" type="submit">
            Enregistrer et entrer
          </button>
          {mismatch ? <p className="hint login-error">Les deux mots de passe doivent être identiques.</p> : null}
        </form>
      )}
    </section>
  );
}
