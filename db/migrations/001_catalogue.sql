-- THALIE. Migration préparée, non exécutée.
-- MariaDB 10.11, 11.4 et 12.3. InnoDB, utf8mb4.
-- À lancer dans la base déjà créée `thalie`. Ne crée ni base, ni utilisateur.
-- Un second passage ne recrée pas une table déjà présente.

CREATE TABLE IF NOT EXISTS centres (
  id CHAR(36) NOT NULL,
  nom VARCHAR(200) NOT NULL,
  adresse TEXT NULL,
  slug VARCHAR(200) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_centres_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS categories (
  id CHAR(36) NOT NULL,
  libelle VARCHAR(200) NOT NULL,
  slug VARCHAR(200) NOT NULL,
  parent_id CHAR(36) NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_categories_slug (slug),
  CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_id) REFERENCES categories (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS disciplines (
  id CHAR(36) NOT NULL,
  libelle VARCHAR(120) NOT NULL,
  slug VARCHAR(200) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_disciplines_libelle (libelle),
  UNIQUE KEY uq_disciplines_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sejours (
  id CHAR(36) NOT NULL,
  centre_id CHAR(36) NOT NULL,
  titre VARCHAR(200) NOT NULL,
  slug VARCHAR(200) NOT NULL,
  age_min TINYINT NULL,
  age_max TINYINT NULL,
  publie TINYINT(1) NOT NULL DEFAULT 0,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_sejours_slug (slug),
  UNIQUE KEY uq_sejours_id_centre (id, centre_id),
  KEY idx_sejours_centre (centre_id),
  CONSTRAINT fk_sejours_centre
    FOREIGN KEY (centre_id) REFERENCES centres (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_sejours_publie CHECK (publie IN (0, 1)),
  CONSTRAINT ck_sejours_age_min CHECK (age_min IS NULL OR age_min >= 0),
  CONSTRAINT ck_sejours_age_max CHECK (age_max IS NULL OR age_max >= 0),
  CONSTRAINT ck_sejours_ages CHECK (age_min IS NULL OR age_max IS NULL OR age_max >= age_min)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sejour_categories (
  sejour_id CHAR(36) NOT NULL,
  categorie_id CHAR(36) NOT NULL,
  PRIMARY KEY (sejour_id, categorie_id),
  CONSTRAINT fk_sejour_categories_sejour
    FOREIGN KEY (sejour_id) REFERENCES sejours (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_sejour_categories_categorie
    FOREIGN KEY (categorie_id) REFERENCES categories (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sejour_disciplines (
  sejour_id CHAR(36) NOT NULL,
  discipline_id CHAR(36) NOT NULL,
  PRIMARY KEY (sejour_id, discipline_id),
  CONSTRAINT fk_sejour_disciplines_sejour
    FOREIGN KEY (sejour_id) REFERENCES sejours (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_sejour_disciplines_discipline
    FOREIGN KEY (discipline_id) REFERENCES disciplines (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- La cible est un centre ou un séjour. Aucune clé étrangère ne peut viser les deux.
-- L'existence de cible_id et l'unicité (cible_type, cible_id, code, ordre) restent une transaction.

CREATE TABLE IF NOT EXISTS contenus_editoriaux (
  id CHAR(36) NOT NULL,
  cible_type VARCHAR(16) NOT NULL,
  cible_id CHAR(36) NOT NULL,
  code VARCHAR(64) NOT NULL,
  corps TEXT NOT NULL,
  ordre INT NOT NULL,
  publie TINYINT(1) NOT NULL DEFAULT 0,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_contenus_cible (cible_type, cible_id),
  CONSTRAINT ck_contenus_cible CHECK (cible_type IN ('centre', 'sejour')),
  CONSTRAINT ck_contenus_publie CHECK (publie IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS medias (
  id CHAR(36) NOT NULL,
  cible_type VARCHAR(16) NOT NULL,
  cible_id CHAR(36) NOT NULL,
  nature VARCHAR(16) NOT NULL,
  cle_stockage VARCHAR(500) NOT NULL,
  texte_alternatif VARCHAR(300) NULL,
  legende VARCHAR(200) NULL,
  ordre INT NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_medias_cible (cible_type, cible_id),
  CONSTRAINT ck_medias_cible CHECK (cible_type IN ('centre', 'sejour')),
  CONSTRAINT ck_medias_nature CHECK (nature IN ('photo', 'video', 'autre'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS referencement (
  id CHAR(36) NOT NULL,
  cible_type VARCHAR(16) NOT NULL,
  cible_id CHAR(36) NOT NULL,
  titre VARCHAR(200) NULL,
  description VARCHAR(300) NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_referencement_cible (cible_type, cible_id),
  CONSTRAINT ck_referencement_cible CHECK (cible_type IN ('centre', 'sejour', 'categorie'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS redirections (
  id CHAR(36) NOT NULL,
  ancienne_url VARCHAR(500) NOT NULL,
  url_cible VARCHAR(500) NOT NULL,
  source VARCHAR(16) NOT NULL,
  code_http SMALLINT NOT NULL DEFAULT 301,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_redirections_ancienne_url (ancienne_url),
  CONSTRAINT ck_redirections_source CHECK (source IN ('oxatis', 'interne'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- places_bloquees et places_confirmees ne comptent que les inscriptions actives hors contingent.
-- La disponibilité commerciale dépend aussi des contingents : elle ne tient pas dans un CHECK de cette table.

CREATE TABLE IF NOT EXISTS sessions (
  id CHAR(36) NOT NULL,
  sejour_id CHAR(36) NOT NULL,
  debut DATE NOT NULL,
  fin DATE NOT NULL,
  capacite INT NOT NULL,
  places_bloquees INT NOT NULL DEFAULT 0,
  places_confirmees INT NOT NULL DEFAULT 0,
  places_liberees INT NOT NULL DEFAULT 0,
  statut_commercial VARCHAR(32) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_sessions_id_sejour (id, sejour_id),
  KEY idx_sessions_sejour_debut (sejour_id, debut),
  CONSTRAINT fk_sessions_sejour
    FOREIGN KEY (sejour_id) REFERENCES sejours (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_sessions_capacite CHECK (capacite >= 0),
  CONSTRAINT ck_sessions_bloquees CHECK (places_bloquees >= 0),
  CONSTRAINT ck_sessions_confirmees CHECK (places_confirmees >= 0),
  CONSTRAINT ck_sessions_liberees CHECK (places_liberees >= 0),
  CONSTRAINT ck_sessions_dates CHECK (fin >= debut),
  CONSTRAINT ck_sessions_statut CHECK (statut_commercial IN ('brouillon', 'ouverte', 'fermee', 'annulee'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
