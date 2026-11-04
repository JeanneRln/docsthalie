-- THALIE. Commandes, inscriptions, contingents, prix et transports.
-- Les compteurs de places ne sont pas tenus par un déclencheur : la prise, la confirmation,
-- la libération et le rapprochement d'un contingent restent une seule transaction applicative.
-- Ce fichier empêche une deuxième inscription active, un blocage CSE saisi à la main,
-- et un second historique ou un second suivi pour la même clé.

CREATE TABLE IF NOT EXISTS segments_clients (
  id CHAR(36) NOT NULL,
  code VARCHAR(64) NOT NULL,
  libelle VARCHAR(200) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_segments_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- places_bloquees n'est pas saisi. Il vaut le plus grand de reel_estime et realise.
-- options_posees ne retire aucune place : la colonne n'entre pas dans ce calcul.

CREATE TABLE IF NOT EXISTS contingents (
  id CHAR(36) NOT NULL,
  session_id CHAR(36) NOT NULL,
  segment_id CHAR(36) NOT NULL,
  options_posees INT NOT NULL,
  reel_estime INT NOT NULL,
  realise INT NOT NULL DEFAULT 0,
  places_bloquees INT AS (GREATEST(reel_estime, realise)) STORED,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_contingents_session_segment (session_id, segment_id),
  UNIQUE KEY uq_contingents_id_session (id, session_id),
  CONSTRAINT fk_contingents_session
    FOREIGN KEY (session_id) REFERENCES sessions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_contingents_segment
    FOREIGN KEY (segment_id) REFERENCES segments_clients (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_contingents_options CHECK (options_posees >= 0),
  CONSTRAINT ck_contingents_reel CHECK (reel_estime >= 0),
  CONSTRAINT ck_contingents_realise CHECK (realise >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS points_transport (
  id CHAR(36) NOT NULL,
  libelle VARCHAR(200) NOT NULL,
  precision_lieu VARCHAR(300) NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS session_transports (
  id CHAR(36) NOT NULL,
  session_id CHAR(36) NOT NULL,
  point_id CHAR(36) NOT NULL,
  sens VARCHAR(16) NOT NULL,
  montant DECIMAL(10, 2) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_session_transports_offre (session_id, point_id, sens),
  UNIQUE KEY uq_session_transports_id_session (id, session_id),
  CONSTRAINT fk_session_transports_session
    FOREIGN KEY (session_id) REFERENCES sessions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_session_transports_point
    FOREIGN KEY (point_id) REFERENCES points_transport (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_session_transports_sens CHECK (sens IN ('aller', 'retour'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tarifs (
  id CHAR(36) NOT NULL,
  sejour_id CHAR(36) NULL,
  session_id CHAR(36) NULL,
  segment_id CHAR(36) NULL,
  montant DECIMAL(10, 2) NOT NULL,
  valide_du DATE NOT NULL,
  valide_au DATE NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_tarifs_session (session_id, segment_id, valide_du),
  KEY idx_tarifs_sejour (sejour_id, segment_id, valide_du),
  CONSTRAINT fk_tarifs_sejour
    FOREIGN KEY (sejour_id) REFERENCES sejours (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_tarifs_session
    FOREIGN KEY (session_id) REFERENCES sessions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_tarifs_session_sejour
    FOREIGN KEY (session_id, sejour_id) REFERENCES sessions (id, sejour_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_tarifs_segment
    FOREIGN KEY (segment_id) REFERENCES segments_clients (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_tarifs_cible CHECK (sejour_id IS NOT NULL OR session_id IS NOT NULL),
  CONSTRAINT ck_tarifs_dates CHECK (valide_au IS NULL OR valide_au >= valide_du)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS commandes (
  id CHAR(36) NOT NULL,
  famille_id CHAR(36) NOT NULL,
  adulte_id CHAR(36) NOT NULL,
  statut VARCHAR(32) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_commandes_id_famille (id, famille_id),
  KEY idx_commandes_adulte_famille (adulte_id, famille_id),
  CONSTRAINT fk_commandes_famille
    FOREIGN KEY (famille_id) REFERENCES familles (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_commandes_adulte_famille
    FOREIGN KEY (adulte_id, famille_id) REFERENCES adultes (id, famille_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_commandes_statut CHECK (statut IN ('brouillon', 'enregistree', 'annulee'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Pas d'unicité permanente (enfant_id, session_id).
-- active_enfant_session est vide hors place_bloquee et confirmee.
-- L'unicité accepte plusieurs vides et refuse deux inscriptions actives du même enfant sur la même session.
-- Le sens aller ou retour du transport choisi n'est pas une clé étrangère.

CREATE TABLE IF NOT EXISTS inscriptions (
  id CHAR(36) NOT NULL,
  commande_id CHAR(36) NOT NULL,
  famille_id CHAR(36) NOT NULL,
  enfant_id CHAR(36) NOT NULL,
  sejour_id CHAR(36) NOT NULL,
  session_id CHAR(36) NOT NULL,
  inscription_origine_id CHAR(36) NULL,
  statut_administratif VARCHAR(32) NOT NULL,
  statut_financier VARCHAR(32) NOT NULL,
  statut_documentaire VARCHAR(32) NOT NULL,
  transport_aller_id CHAR(36) NULL,
  transport_retour_id CHAR(36) NULL,
  contingent_id CHAR(36) NULL,
  motif_refus VARCHAR(500) NULL,
  active_enfant_session VARCHAR(73) AS (
    CASE
      WHEN statut_administratif IN ('place_bloquee', 'confirmee')
      THEN CONCAT(RTRIM(enfant_id), ':', RTRIM(session_id))
      ELSE NULL
    END
  ) STORED,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_inscriptions_actif (active_enfant_session),
  KEY idx_inscriptions_commande (commande_id),
  KEY idx_inscriptions_enfant (enfant_id),
  KEY idx_inscriptions_session_statut (session_id, statut_administratif),
  KEY idx_inscriptions_statut (statut_administratif),
  KEY idx_inscriptions_contingent (contingent_id),
  CONSTRAINT fk_inscriptions_commande_famille
    FOREIGN KEY (commande_id, famille_id) REFERENCES commandes (id, famille_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_inscriptions_enfant_famille
    FOREIGN KEY (enfant_id, famille_id) REFERENCES enfants (id, famille_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_inscriptions_session_sejour
    FOREIGN KEY (session_id, sejour_id) REFERENCES sessions (id, sejour_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_inscriptions_origine
    FOREIGN KEY (inscription_origine_id) REFERENCES inscriptions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_inscriptions_transport_aller
    FOREIGN KEY (transport_aller_id, session_id) REFERENCES session_transports (id, session_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_inscriptions_transport_retour
    FOREIGN KEY (transport_retour_id, session_id) REFERENCES session_transports (id, session_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_inscriptions_contingent_session
    FOREIGN KEY (contingent_id, session_id) REFERENCES contingents (id, session_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_inscriptions_administratif CHECK (statut_administratif IN ('place_bloquee', 'confirmee', 'refusee', 'annulee', 'transferee')),
  CONSTRAINT ck_inscriptions_financier CHECK (statut_financier IN ('aucun', 'acompte', 'solde', 'trop_percu', 'remboursement_partiel', 'rembourse')),
  CONSTRAINT ck_inscriptions_documentaire CHECK (statut_documentaire IN ('manquant', 'depose', 'copie_en_echec', 'en_validation', 'a_corriger', 'valide'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS inscription_evenements (
  id CHAR(36) NOT NULL,
  inscription_id CHAR(36) NOT NULL,
  type VARCHAR(32) NOT NULL,
  source VARCHAR(32) NOT NULL,
  resume VARCHAR(500) NOT NULL,
  details_json JSON NULL,
  cle_idempotence VARCHAR(128) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_inscription_evenements_cle (cle_idempotence),
  KEY idx_inscription_evenements_inscription (inscription_id),
  CONSTRAINT fk_inscription_evenements_inscription
    FOREIGN KEY (inscription_id) REFERENCES inscriptions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_inscription_evenements_source CHECK (source IN ('site', 'filemaker', 'admin'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS historique_contingents (
  id CHAR(36) NOT NULL,
  contingent_id CHAR(36) NOT NULL,
  champ VARCHAR(32) NOT NULL,
  valeur_avant INT NOT NULL,
  valeur_apres INT NOT NULL,
  places_bloquees_apres INT NOT NULL,
  source VARCHAR(32) NOT NULL,
  cle_idempotence VARCHAR(128) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_historique_contingents_cle (cle_idempotence),
  KEY idx_historique_contingents_suivi (contingent_id, cree_le),
  CONSTRAINT fk_historique_contingents_contingent
    FOREIGN KEY (contingent_id) REFERENCES contingents (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_historique_contingents_champ CHECK (champ IN ('options_posees', 'reel_estime', 'realise')),
  CONSTRAINT ck_historique_contingents_source CHECK (source IN ('site', 'filemaker', 'admin')),
  CONSTRAINT ck_historique_contingents_places CHECK (places_bloquees_apres >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Une ligne par effet hors contingent. La même cle_idempotence ne peut pas être insérée deux fois.
-- Une autre clé pour le même effet n'est pas refusée par le schéma : la transaction doit réutiliser une clé stable.
-- Si contingent_id est renseigné, ce contingent appartient à la session de la ligne.
-- Une inscription déjà comptée dans contingents.realise ne doit pas garder de place hors contingent.

CREATE TABLE IF NOT EXISTS suivi_places (
  id CHAR(36) NOT NULL,
  session_id CHAR(36) NOT NULL,
  contingent_id CHAR(36) NULL,
  inscription_id CHAR(36) NOT NULL,
  effet VARCHAR(16) NOT NULL,
  cle_idempotence VARCHAR(128) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_suivi_places_cle (cle_idempotence),
  KEY idx_suivi_places_session_effet (session_id, effet),
  KEY idx_suivi_places_contingent_session (contingent_id, session_id),
  KEY idx_suivi_places_inscription (inscription_id),
  CONSTRAINT fk_suivi_places_session
    FOREIGN KEY (session_id) REFERENCES sessions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_suivi_places_contingent_session
    FOREIGN KEY (contingent_id, session_id) REFERENCES contingents (id, session_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_suivi_places_inscription
    FOREIGN KEY (inscription_id) REFERENCES inscriptions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_suivi_places_effet CHECK (effet IN ('blocage', 'confirmation', 'liberation'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Vente figée. Un changement de tarif ou de transport ne réécrit pas ces lignes.

CREATE TABLE IF NOT EXISTS inscription_prix_lignes (
  id CHAR(36) NOT NULL,
  inscription_id CHAR(36) NOT NULL,
  code VARCHAR(32) NOT NULL,
  libelle VARCHAR(200) NOT NULL,
  montant DECIMAL(10, 2) NOT NULL,
  tarif_id CHAR(36) NULL,
  ordre INT NOT NULL,
  fige_le DATETIME(3) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_inscription_prix_lignes_ligne (inscription_id, code, ordre),
  KEY idx_inscription_prix_lignes_tarif (tarif_id),
  CONSTRAINT fk_inscription_prix_lignes_inscription
    FOREIGN KEY (inscription_id) REFERENCES inscriptions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_inscription_prix_lignes_tarif
    FOREIGN KEY (tarif_id) REFERENCES tarifs (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_inscription_prix_lignes_code CHECK (code IN ('sejour', 'transport_aller', 'transport_retour', 'autre'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP TRIGGER IF EXISTS trg_prix_lignes_no_update;
CREATE TRIGGER trg_prix_lignes_no_update
BEFORE UPDATE ON inscription_prix_lignes
FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'inscription_prix_lignes est immuable';

DROP TRIGGER IF EXISTS trg_prix_lignes_no_delete;
CREATE TRIGGER trg_prix_lignes_no_delete
BEFORE DELETE ON inscription_prix_lignes
FOR EACH ROW
SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'inscription_prix_lignes est immuable';
