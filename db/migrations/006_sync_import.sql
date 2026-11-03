-- THALIE. Identifiants externes, journal, conflits et tables d'import.
-- Les tables d'import n'ont aucune clé étrangère vers les tables vivantes.
-- Aucune rubrique FileMaker n'est promue en colonne.

CREATE TABLE IF NOT EXISTS identifiants_externes (
  id CHAR(36) NOT NULL,
  systeme VARCHAR(32) NOT NULL,
  entite VARCHAR(32) NOT NULL,
  id_local CHAR(36) NOT NULL,
  id_externe VARCHAR(64) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_identifiants_externe (systeme, entite, id_externe),
  UNIQUE KEY uq_identifiants_local (systeme, entite, id_local),
  CONSTRAINT ck_identifiants_systeme CHECK (systeme IN ('filemaker', 'polymnie', 'oxatis', 'prestashop')),
  CONSTRAINT ck_identifiants_entite CHECK (entite IN (
    'centre', 'sejour', 'session', 'famille', 'enfant', 'inscription',
    'mouvement', 'ventilation', 'piece', 'document_publie', 'facture'
  ))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS journal_sync (
  id CHAR(36) NOT NULL,
  cle_idempotence VARCHAR(128) NOT NULL,
  direction VARCHAR(32) NOT NULL,
  entite VARCHAR(32) NOT NULL,
  id_local CHAR(36) NULL,
  statut VARCHAR(32) NOT NULL,
  tentative INT NOT NULL DEFAULT 0,
  derniere_erreur VARCHAR(500) NULL,
  acquitte_le DATETIME(3) NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_journal_sync_cle (cle_idempotence),
  KEY idx_journal_sync_reprise (statut, cree_le),
  CONSTRAINT ck_journal_sync_direction CHECK (direction IN ('vers_filemaker', 'vers_site', 'vers_onedrive')),
  CONSTRAINT ck_journal_sync_statut CHECK (statut IN ('en_attente', 'envoye', 'acquitte', 'erreur', 'a_rejouer')),
  CONSTRAINT ck_journal_sync_tentative CHECK (tentative >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS conflits (
  id CHAR(36) NOT NULL,
  entite VARCHAR(32) NOT NULL,
  id_local CHAR(36) NOT NULL,
  champ VARCHAR(64) NOT NULL,
  valeur_site TEXT NULL,
  valeur_filemaker TEXT NULL,
  resolu_le DATETIME(3) NULL,
  resolu_par CHAR(36) NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_conflits_entite (entite, id_local, resolu_le),
  KEY idx_conflits_resolu (resolu_le),
  CONSTRAINT fk_conflits_compte
    FOREIGN KEY (resolu_par) REFERENCES comptes (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS import_filemaker_familles (
  id CHAR(36) NOT NULL,
  id_externe VARCHAR(64) NULL,
  payload_json JSON NOT NULL,
  statut_rapprochement VARCHAR(32) NOT NULL,
  id_cible CHAR(36) NULL,
  motif VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_import_filemaker_familles_statut (statut_rapprochement),
  CONSTRAINT ck_import_filemaker_familles CHECK (statut_rapprochement IN ('importe', 'en_attente', 'rapproche', 'ambigu', 'rejete'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS import_filemaker_enfants (
  id CHAR(36) NOT NULL,
  id_externe VARCHAR(64) NULL,
  payload_json JSON NOT NULL,
  statut_rapprochement VARCHAR(32) NOT NULL,
  id_cible CHAR(36) NULL,
  motif VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_import_filemaker_enfants_statut (statut_rapprochement),
  CONSTRAINT ck_import_filemaker_enfants CHECK (statut_rapprochement IN ('importe', 'en_attente', 'rapproche', 'ambigu', 'rejete'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS import_filemaker_inscriptions (
  id CHAR(36) NOT NULL,
  id_externe VARCHAR(64) NULL,
  payload_json JSON NOT NULL,
  statut_rapprochement VARCHAR(32) NOT NULL,
  id_cible CHAR(36) NULL,
  motif VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_import_filemaker_inscriptions_statut (statut_rapprochement),
  CONSTRAINT ck_import_filemaker_inscriptions CHECK (statut_rapprochement IN ('importe', 'en_attente', 'rapproche', 'ambigu', 'rejete'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS import_filemaker_reglements (
  id CHAR(36) NOT NULL,
  id_externe VARCHAR(64) NULL,
  payload_json JSON NOT NULL,
  statut_rapprochement VARCHAR(32) NOT NULL,
  id_cible CHAR(36) NULL,
  motif VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_import_filemaker_reglements_statut (statut_rapprochement),
  CONSTRAINT ck_import_filemaker_reglements CHECK (statut_rapprochement IN ('importe', 'en_attente', 'rapproche', 'ambigu', 'rejete'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS import_filemaker_documents (
  id CHAR(36) NOT NULL,
  id_externe VARCHAR(64) NULL,
  payload_json JSON NOT NULL,
  statut_rapprochement VARCHAR(32) NOT NULL,
  id_cible CHAR(36) NULL,
  motif VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_import_filemaker_documents_statut (statut_rapprochement),
  CONSTRAINT ck_import_filemaker_documents CHECK (statut_rapprochement IN ('importe', 'en_attente', 'rapproche', 'ambigu', 'rejete'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS import_oxatis_produits (
  id CHAR(36) NOT NULL,
  id_externe VARCHAR(64) NULL,
  payload_json JSON NOT NULL,
  statut_rapprochement VARCHAR(32) NOT NULL,
  id_cible CHAR(36) NULL,
  motif VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_import_oxatis_produits_statut (statut_rapprochement),
  CONSTRAINT ck_import_oxatis_produits CHECK (statut_rapprochement IN ('importe', 'en_attente', 'rapproche', 'ambigu', 'rejete'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS import_oxatis_commandes (
  id CHAR(36) NOT NULL,
  id_externe VARCHAR(64) NULL,
  payload_json JSON NOT NULL,
  statut_rapprochement VARCHAR(32) NOT NULL,
  id_cible CHAR(36) NULL,
  motif VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_import_oxatis_commandes_statut (statut_rapprochement),
  CONSTRAINT ck_import_oxatis_commandes CHECK (statut_rapprochement IN ('importe', 'en_attente', 'rapproche', 'ambigu', 'rejete'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS import_oxatis_lignes (
  id CHAR(36) NOT NULL,
  id_externe VARCHAR(64) NULL,
  payload_json JSON NOT NULL,
  statut_rapprochement VARCHAR(32) NOT NULL,
  id_cible CHAR(36) NULL,
  motif VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_import_oxatis_lignes_statut (statut_rapprochement),
  CONSTRAINT ck_import_oxatis_lignes CHECK (statut_rapprochement IN ('importe', 'en_attente', 'rapproche', 'ambigu', 'rejete'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS import_oxatis_urls (
  id CHAR(36) NOT NULL,
  id_externe VARCHAR(64) NULL,
  payload_json JSON NOT NULL,
  statut_rapprochement VARCHAR(32) NOT NULL,
  id_cible CHAR(36) NULL,
  motif VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_import_oxatis_urls_statut (statut_rapprochement),
  CONSTRAINT ck_import_oxatis_urls CHECK (statut_rapprochement IN ('importe', 'en_attente', 'rapproche', 'ambigu', 'rejete'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS import_prestashop_clients (
  id CHAR(36) NOT NULL,
  id_externe VARCHAR(64) NULL,
  payload_json JSON NOT NULL,
  statut_rapprochement VARCHAR(32) NOT NULL,
  id_cible CHAR(36) NULL,
  motif VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_import_prestashop_clients_statut (statut_rapprochement),
  CONSTRAINT ck_import_prestashop_clients CHECK (statut_rapprochement IN ('importe', 'en_attente', 'rapproche', 'ambigu', 'rejete'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS import_prestashop_documents (
  id CHAR(36) NOT NULL,
  id_externe VARCHAR(64) NULL,
  payload_json JSON NOT NULL,
  statut_rapprochement VARCHAR(32) NOT NULL,
  id_cible CHAR(36) NULL,
  motif VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_import_prestashop_documents_statut (statut_rapprochement),
  CONSTRAINT ck_import_prestashop_documents CHECK (statut_rapprochement IN ('importe', 'en_attente', 'rapproche', 'ambigu', 'rejete'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
