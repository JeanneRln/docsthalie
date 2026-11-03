-- THALIE. Familles, adultes, comptes, enfants.
-- Le responsable administratif est ajouté après les deux tables : MariaDB refuse ce cycle dans un seul CREATE.
-- Ne crée ni base, ni utilisateur.

CREATE TABLE IF NOT EXISTS familles (
  id CHAR(36) NOT NULL,
  responsable_administratif_id CHAR(36) NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS adultes (
  id CHAR(36) NOT NULL,
  famille_id CHAR(36) NOT NULL,
  prenom VARCHAR(120) NOT NULL,
  nom VARCHAR(120) NOT NULL,
  email VARCHAR(254) NULL,
  telephone VARCHAR(40) NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_adultes_id_famille (id, famille_id),
  KEY idx_adultes_famille (famille_id),
  CONSTRAINT fk_adultes_famille
    FOREIGN KEY (famille_id) REFERENCES familles (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Un seul responsable, et il appartient à cette famille. NULL pendant un import incomplet.
-- MATCH SIMPLE, le défaut : un responsable vide ne bloque pas la ligne.

SET @fk_familles_responsable := (
  SELECT COUNT(*)
  FROM information_schema.TABLE_CONSTRAINTS
  WHERE CONSTRAINT_SCHEMA = DATABASE()
    AND TABLE_NAME = 'familles'
    AND CONSTRAINT_NAME = 'fk_familles_responsable'
    AND CONSTRAINT_TYPE = 'FOREIGN KEY'
);
SET @sql_fk_familles_responsable := IF(
  @fk_familles_responsable = 0,
  'ALTER TABLE familles ADD CONSTRAINT fk_familles_responsable FOREIGN KEY (responsable_administratif_id, id) REFERENCES adultes (id, famille_id) ON DELETE RESTRICT ON UPDATE RESTRICT',
  'SELECT 1'
);
PREPARE stmt_fk_familles_responsable FROM @sql_fk_familles_responsable;
EXECUTE stmt_fk_familles_responsable;
DEALLOCATE PREPARE stmt_fk_familles_responsable;

CREATE TABLE IF NOT EXISTS comptes (
  id CHAR(36) NOT NULL,
  adulte_id CHAR(36) NOT NULL,
  email VARCHAR(254) NOT NULL,
  mot_de_passe_hash VARCHAR(255) NULL,
  email_confirme_le DATETIME(3) NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_comptes_adulte (adulte_id),
  UNIQUE KEY uq_comptes_email (email),
  CONSTRAINT fk_comptes_adulte
    FOREIGN KEY (adulte_id) REFERENCES adultes (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS enfants (
  id CHAR(36) NOT NULL,
  famille_id CHAR(36) NOT NULL,
  prenom VARCHAR(120) NOT NULL,
  nom VARCHAR(120) NOT NULL,
  naissance DATE NULL,
  naissance_incomplete TINYINT(1) NOT NULL DEFAULT 0,
  sexe VARCHAR(16) NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_enfants_id_famille (id, famille_id),
  KEY idx_enfants_famille (famille_id),
  CONSTRAINT fk_enfants_famille
    FOREIGN KEY (famille_id) REFERENCES familles (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_enfants_naissance_incomplete CHECK (naissance_incomplete IN (0, 1)),
  CONSTRAINT ck_enfants_naissance CHECK (naissance IS NOT NULL OR naissance_incomplete = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
