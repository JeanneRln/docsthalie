import Link from "next/link";

export default function EnfantsPage() {
  return (
    <section>
      <h1 className="person">Bonjour Camille</h1>
      <p className="lede">
        Vos enfants et leurs séjours passés et futurs.
      </p>
      <div className="stay-list">
        <p className="account-docs">
          <Link className="btn" href="/documents">
            Consulter mes documents administratifs et financiers
          </Link>
        </p>
        <article className="card stay">
          <h2 className="child-name person">Léa Martin</h2>
          <div className="history">
            <div className="history-group">
              <p className="history-label">Séjours à venir</p>
              <ul className="upcoming">
                <li className="stay-row">
                  <span className="stay-title">Passion Cinéma (Menton)</span>
                  <span className="stay-when">du 14 au 20 février 2027</span>
                  <Link className="pill miss" href="/dossier?sejour=passion">
                    À compléter
                  </Link>
                </li>
                <li className="stay-row">
                  <span className="stay-title">Studio Théâtre (Bois)</span>
                  <span className="stay-when">du 18 au 24 octobre 2026</span>
                  <Link className="pill miss" href="/dossier">
                    À compléter
                  </Link>
                </li>
              </ul>
            </div>
            <div className="history-group">
              <p className="history-label">Séjours passés</p>
              <ul className="past">
                <li>La Vie d'Artiste Danse Classique (Bernay, Été 2025)</li>
                <li>Studio Danse Classique (Bois, Automne 2024)</li>
              </ul>
            </div>
          </div>
        </article>
        <article className="card stay">
          <h2 className="child-name person">Tom Martin</h2>
          <div className="history">
            <div className="history-group">
              <p className="history-label">Séjours à venir</p>
              <ul className="upcoming">
                <li className="stay-row">
                  <span className="stay-title">Passion Cinéma (Menton)</span>
                  <span className="stay-when">du 14 au 20 février 2027</span>
                  <Link className="pill miss" href="/dossier?sejour=passion&enfant=tom">
                    À compléter
                  </Link>
                </li>
                <li className="stay-row">
                  <span className="stay-title">Studio Théâtre (Bois)</span>
                  <span className="stay-when">du 18 au 24 octobre 2026</span>
                  <span className="stay-actions">
                    <Link className="btn secondary" href="/documents?enfant=tom&sejour=studio-theatre-2026">
                      Voir les documents
                    </Link>
                    <span className="pill ok">Complet</span>
                  </span>
                </li>
              </ul>
            </div>
            <div className="history-group">
              <p className="history-label">Séjours passés</p>
              <ul className="past">
                <li>La Vie d'Artiste Danse Classique (Bernay, Été 2025)</li>
              </ul>
            </div>
          </div>
        </article>
      </div>
    </section>
  );
}
