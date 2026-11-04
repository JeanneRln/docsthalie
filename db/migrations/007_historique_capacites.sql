-- THALIE. Historique des modifications de capacité d'une session.
-- Ne change pas les tables déjà créées. À appliquer sur thalie_test :
--   mariadb --protocol=socket thalie_test < db/migrations/007_historique_capacites.sql
--
-- Une ligne par modification acceptée. La capacité après couvre les places
-- hors contingent et les blocages de contingents constatés dans la même transaction.

CREATE TABLE IF NOT EXISTS historique_capacites (
  id CHAR(36) NOT NULL,
  session_id CHAR(36) NOT NULL,
  capacite_avant INT NOT NULL,
  capacite_apres INT NOT NULL,
  places_occupees INT NOT NULL,
  source VARCHAR(32) NOT NULL,
  cle_idempotence VARCHAR(128) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_historique_capacites_cle (cle_idempotence),
  KEY idx_historique_capacites_session (session_id, cree_le),
  CONSTRAINT fk_historique_capacites_session
    FOREIGN KEY (session_id) REFERENCES sessions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_historique_capacites_avant CHECK (capacite_avant >= 0),
  CONSTRAINT ck_historique_capacites_apres CHECK (capacite_apres >= 0),
  CONSTRAINT ck_historique_capacites_occupees CHECK (places_occupees >= 0),
  CONSTRAINT ck_historique_capacites_couverture CHECK (capacite_apres >= places_occupees),
  CONSTRAINT ck_historique_capacites_source CHECK (source IN ('site', 'filemaker', 'admin'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
