"use client";

import { useAppState } from "@/components/Providers";
import { childName, stayById } from "@/lib/sejours";

export default function BureauPage() {
  const { attestations, ficheSent, convocationDeposee, deposerConvocation } = useAppState();

  return (
    <section>
      <h1>Bureau</h1>
      <p className="lede">
        Une personne lit les pièces, les valide, puis les télécharge pour les déposer dans FileMaker. Le directeur les
        voit de ce côté-là.
      </p>
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Parent</th>
              <th>Dernière connexion</th>
              <th>Enfant</th>
              <th>Groupe</th>
              <th>Obligatoires</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr className="active">
              <td>
                <span className="person">Camille Martin</span>
                <br />
                <small className="muted">n° 277, CLIENTS 2026 INDIV</small>
              </td>
              <td>
                12 septembre 2026
                <br />
                <small className="muted">18 h 42</small>
              </td>
              <td>
                <span className="person">Léa Martin</span>
              </td>
              <td>
                BOIS AUTOMNE 2026
                <br />
                <small className="muted">groupe 328, 18–24 octobre</small>
              </td>
              <td>
                {ficheSent ? (
                  <span className="pill wait">Fiche envoyée</span>
                ) : (
                  <span className="pill miss">Fiche manquante</span>
                )}{" "}
                <span className="pill wait">Vaccin à corriger</span>
              </td>
              <td>
                <button className="btn small" type="button">
                  Lire
                </button>
              </td>
            </tr>
            <tr>
              <td>
                <span className="person">Camille Martin</span>
              </td>
              <td>
                12 septembre 2026
                <br />
                <small className="muted">18 h 42</small>
              </td>
              <td>
                <span className="person">Tom Martin</span>
              </td>
              <td>
                BOIS AUTOMNE 2026
                <br />
                <small className="muted">
                  même séjour que <span className="person">Léa</span>
                </small>
              </td>
              <td>
                <span className="pill ok">Complet</span>
              </td>
              <td>
                <button className="btn small secondary" type="button">
                  Lire
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div className="card detail">
        <p className="kicker">
          <span className="person">Léa Martin</span>, BOIS AUTOMNE 2026
        </p>
        <div className="files">
          <div className="file">
            <div>
              <strong>Attestation sécu</strong>
              <span>Prête à être glissée dans FileMaker</span>
            </div>
            <div className="actions">
              <span className="pill ok">Validée</span>
              <button className="btn small secondary" type="button">
                Télécharger
              </button>
            </div>
          </div>
          <div className="file">
            <div>
              <strong>Carnet de vaccination</strong>
              <span>Photo trop sombre</span>
            </div>
            <div className="actions">
              <button className="btn small" type="button">
                Demander une autre photo
              </button>
            </div>
          </div>
          <div className="file">
            <div>
              <strong>Convocation Transport</strong>
              <span>{convocationDeposee ? "Chargée, visible par les parents dont le dossier sanitaire est complet" : "PDF à déposer pour les parents"}</span>
            </div>
            {convocationDeposee ? (
              <span className="pill ok">Chargée</span>
            ) : (
              <button className="btn small secondary" type="button" onClick={deposerConvocation}>
                Déposer
              </button>
            )}
          </div>
          <div className="file">
            <div>
              <strong>Fiche Trousseau - Valise</strong>
              <span>Déjà visible par toutes les familles de BOIS AUTOMNE 2026</span>
            </div>
            <span className="pill ok">En ligne</span>
          </div>
          <div className="file">
            <div>
              <strong>Lettre du Séjour</strong>
              <span>PDF à déposer pour les parents, BOIS AUTOMNE 2026</span>
            </div>
            <button className="btn small secondary" type="button">
              Déposer
            </button>
          </div>
        </div>
      </div>
      <div className="card detail">
        <p className="kicker">Demandes d'attestations de présence</p>
        <div className="files">
          {attestations.length > 0 ? (
            attestations.map((id) => {
              const [childId, stayId] = id.split(":");
              const stay = stayById(stayId);
              return (
                <div className="file" key={id}>
                  <div>
                    <strong>Attestation de présence</strong>
                    <span>
                      <span className="person">Camille Martin</span>, <span className="person">{childName(childId)}</span>
                      {stay ? `, ${stay.title}` : ""}, Demandée
                    </span>
                  </div>
                  <div className="actions">
                    <span className="pill wait">Demandée</span>
                    <button className="btn small" type="button">
                      À traiter
                    </button>
                  </div>
                </div>
              );
            })
          ) : (
            <p className="hint" style={{ margin: 0 }}>
              Aucune demande en attente.
            </p>
          )}
        </div>
      </div>
    </section>
  );
}
