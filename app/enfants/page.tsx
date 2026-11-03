import Link from "next/link";
import { children, stays, type ChildId, type Stay } from "@/lib/sejours";

function dossierHref(childId: ChildId, stayId: string) {
  return childId === "tom" ? `/dossier?sejour=${stayId}&enfant=tom` : `/dossier?sejour=${stayId}`;
}

function pastLabel(stay: Stay) {
  return stay.title.replace(/\)\s*$/, `, ${stay.when})`);
}

export default function EnfantsPage() {
  return (
    <section>
      <h1 className="person">Bonjour Camille</h1>
      <p className="lede">
        Vos enfants et leurs séjours passés et futurs. Pour un séjour à venir, ouvrez « À compléter ». Vous y enverrez
        les documents et la fiche sanitaire.
      </p>
      <div className="stay-list">
        <p className="account-docs">
          <Link className="btn" href="/documents">
            Consulter mes documents administratifs et financiers
          </Link>
        </p>
        {children.map((child) => {
          const enrolled = stays.filter((stay) => stay.children.some((item) => item.id === child.id));
          const upcoming = enrolled.filter((stay) => stay.upcoming);
          const past = enrolled.filter((stay) => !stay.upcoming);
          return (
            <article className="card stay" key={child.id}>
              <h2 className="child-name person">{child.name}</h2>
              <div className="history">
                <div className="history-group">
                  <p className="history-label">Séjours à venir</p>
                  <ul className="upcoming">
                    {upcoming.map((stay) => {
                      const complet = stay.children.find((item) => item.id === child.id)?.sanitaireComplet === true;
                      return (
                        <li className="stay-row" key={stay.id}>
                          <span className="stay-title">{stay.title}</span>
                          <span className="stay-when">{stay.when}</span>
                          {complet ? (
                            <span className="stay-actions">
                              <Link className="btn secondary" href={`/documents?enfant=${child.id}&sejour=${stay.id}`}>
                                Voir les documents
                              </Link>
                              <span className="pill ok">Complet</span>
                            </span>
                          ) : (
                            <Link className="pill miss" href={dossierHref(child.id, stay.id)}>
                              À compléter
                            </Link>
                          )}
                        </li>
                      );
                    })}
                  </ul>
                </div>
                <div className="history-group">
                  <p className="history-label">Séjours passés</p>
                  <ul className="past">
                    {past.map((stay) => (
                      <li key={stay.id}>{pastLabel(stay)}</li>
                    ))}
                  </ul>
                </div>
              </div>
            </article>
          );
        })}
      </div>
    </section>
  );
}
