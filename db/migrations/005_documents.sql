-- THALIE. Pièces familles, documents publiés et factures.
-- Aucune table sanitaire. La validation des pièces familles n'est pas un droit de l'admin :
-- le schéma garde la décision et le verrou, il ne peut pas prouver que l'auteur est FileMaker.
-- Le pass nautique est un type, pas une exigence globale.

CREATE TABLE IF NOT EXISTS types_pieces (
  type VARCHAR(32) NOT NULL,
  libelle VARCHAR(120) NOT NULL,
  autorise_declaration TINYINT(1) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (type),
  CONSTRAINT ck_types_pieces_declaration CHECK (autorise_declaration IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS exigences_documentaires (
  id CHAR(36) NOT NULL,
  type VARCHAR(32) NOT NULL,
  sejour_id CHAR(36) NULL,
  session_id CHAR(36) NULL,
  obligatoire TINYINT(1) NOT NULL,
  bloque_convocation TINYINT(1) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_exigences_type (type),
  KEY idx_exigences_sejour (sejour_id),
  KEY idx_exigences_session (session_id),
  CONSTRAINT fk_exigences_type
    FOREIGN KEY (type) REFERENCES types_pieces (type)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_exigences_sejour
    FOREIGN KEY (sejour_id) REFERENCES sejours (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_exigences_session
    FOREIGN KEY (session_id) REFERENCES sessions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_exigences_session_sejour
    FOREIGN KEY (session_id, sejour_id) REFERENCES sessions (id, sejour_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_exigences_obligatoire CHECK (obligatoire IN (0, 1)),
  CONSTRAINT ck_exigences_convocation CHECK (bloque_convocation IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS pieces (
  id CHAR(36) NOT NULL,
  inscription_id CHAR(36) NOT NULL,
  type VARCHAR(32) NOT NULL,
  statut VARCHAR(32) NOT NULL,
  verrouille_le DATETIME(3) NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_pieces_inscription_type (inscription_id, type),
  CONSTRAINT fk_pieces_inscription
    FOREIGN KEY (inscription_id) REFERENCES inscriptions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_pieces_type
    FOREIGN KEY (type) REFERENCES types_pieces (type)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_pieces_statut CHECK (statut IN ('manquant', 'depose', 'copie_en_echec', 'en_validation', 'a_corriger', 'valide')),
  CONSTRAINT ck_pieces_verrou CHECK (
    (statut = 'valide' AND verrouille_le IS NOT NULL)
    OR (statut <> 'valide' AND verrouille_le IS NULL)
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fichiers (
  id CHAR(36) NOT NULL,
  piece_id CHAR(36) NOT NULL,
  numero_version INT NOT NULL,
  cle_stockage VARCHAR(500) NOT NULL,
  nom_original VARCHAR(255) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_fichiers_version (piece_id, numero_version),
  CONSTRAINT fk_fichiers_piece
    FOREIGN KEY (piece_id) REFERENCES pieces (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_fichiers_version CHECK (numero_version >= 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Textes fixés, conservés par l'application au moment de l'acceptation, pas dans une table à part :
-- PAI : Mon enfant n'a pas de PAI.
-- Ordonnance : aucun traitement pendant le séjour, y compris sans ordonnance.
-- Sécu et mutuelle : Je reconnais qu'en refusant de téléverser ce document, cela pourra amener Thalie
-- à avancer des frais médicaux sur place, qu'il vous faudra rembourser en échange des feuilles de soins et des factures.
-- Refuser la déclaration si le type n'a pas autorise_declaration reste une transaction.

CREATE TABLE IF NOT EXISTS declarations_pieces (
  id CHAR(36) NOT NULL,
  piece_id CHAR(36) NOT NULL,
  code VARCHAR(32) NOT NULL,
  texte_accepte VARCHAR(1000) NOT NULL,
  accepte_le DATETIME(3) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_declarations_piece (piece_id),
  CONSTRAINT fk_declarations_piece
    FOREIGN KEY (piece_id) REFERENCES pieces (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_declarations_code CHECK (code IN ('pas_de_pai', 'aucun_traitement', 'refus_justificatif'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS decisions_pieces (
  id CHAR(36) NOT NULL,
  piece_id CHAR(36) NOT NULL,
  decision VARCHAR(32) NOT NULL,
  motif VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_decisions_piece (piece_id),
  CONSTRAINT fk_decisions_piece
    FOREIGN KEY (piece_id) REFERENCES pieces (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_decisions_valeur CHECK (decision IN ('valide', 'a_corriger'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Pas d'unicité : une seconde demande après traitement n'est pas tranchée.
-- L'application ignore un second clic tant qu'une ligne demandee existe.

CREATE TABLE IF NOT EXISTS demandes_attestations (
  id CHAR(36) NOT NULL,
  inscription_id CHAR(36) NOT NULL,
  statut VARCHAR(32) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_demandes_attestations_etat (inscription_id, statut),
  CONSTRAINT fk_demandes_attestations_inscription
    FOREIGN KEY (inscription_id) REFERENCES inscriptions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_demandes_attestations_statut CHECK (statut IN ('demandee', 'traitee'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS documents_publies (
  id CHAR(36) NOT NULL,
  type VARCHAR(32) NOT NULL,
  centre_id CHAR(36) NULL,
  sejour_id CHAR(36) NULL,
  session_id CHAR(36) NULL,
  inscription_id CHAR(36) NULL,
  cle_stockage VARCHAR(500) NOT NULL,
  visible TINYINT(1) NOT NULL DEFAULT 0,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_documents_publies_centre (centre_id),
  KEY idx_documents_publies_sejour (sejour_id),
  KEY idx_documents_publies_session (session_id),
  KEY idx_documents_publies_inscription (inscription_id),
  CONSTRAINT fk_documents_publies_centre
    FOREIGN KEY (centre_id) REFERENCES centres (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_documents_publies_sejour
    FOREIGN KEY (sejour_id) REFERENCES sejours (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_documents_publies_session
    FOREIGN KEY (session_id) REFERENCES sessions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_documents_publies_inscription
    FOREIGN KEY (inscription_id) REFERENCES inscriptions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_documents_publies_visible CHECK (visible IN (0, 1)),
  CONSTRAINT ck_documents_publies_rattachement CHECK (
    (centre_id IS NOT NULL) + (sejour_id IS NOT NULL) + (session_id IS NOT NULL) + (inscription_id IS NOT NULL) = 1
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS versions_documents_publies (
  id CHAR(36) NOT NULL,
  document_id CHAR(36) NOT NULL,
  numero_version INT NOT NULL,
  cle_stockage VARCHAR(500) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_versions_documents_publies (document_id, numero_version),
  CONSTRAINT fk_versions_documents_publies_document
    FOREIGN KEY (document_id) REFERENCES documents_publies (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_versions_documents_publies CHECK (numero_version >= 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS factures (
  id CHAR(36) NOT NULL,
  reference_facturation VARCHAR(128) NULL,
  origine VARCHAR(32) NOT NULL,
  commande_id CHAR(36) NULL,
  famille_id CHAR(36) NULL,
  cle_onedrive VARCHAR(200) NULL,
  cle_stockage VARCHAR(500) NULL,
  statut VARCHAR(32) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_factures_onedrive (cle_onedrive),
  KEY idx_factures_statut (statut),
  KEY idx_factures_reference (reference_facturation),
  KEY idx_factures_commande (commande_id),
  KEY idx_factures_famille (famille_id),
  CONSTRAINT fk_factures_commande
    FOREIGN KEY (commande_id) REFERENCES commandes (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_factures_famille
    FOREIGN KEY (famille_id) REFERENCES familles (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_factures_origine CHECK (origine IN ('web', 'historique', 'institutionnelle')),
  CONSTRAINT ck_factures_statut CHECK (statut IN ('en_attente_rapprochement', 'rattachee', 'rejetee'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS facture_inscriptions (
  facture_id CHAR(36) NOT NULL,
  inscription_id CHAR(36) NOT NULL,
  PRIMARY KEY (facture_id, inscription_id),
  CONSTRAINT fk_facture_inscriptions_facture
    FOREIGN KEY (facture_id) REFERENCES factures (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_facture_inscriptions_inscription
    FOREIGN KEY (inscription_id) REFERENCES inscriptions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Jeu initial, repris si les lignes existent déjà. N'écrase pas un libellé modifié ensuite.

INSERT IGNORE INTO types_pieces (type, libelle, autorise_declaration, cree_le, modifie_le) VALUES
  ('fiche_sanitaire', 'Fiche sanitaire', 0, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'),
  ('droit_image', 'Droit à l''image', 0, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'),
  ('regime', 'Régime', 0, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'),
  ('vaccination', 'Carnet de vaccination', 0, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'),
  ('secu', 'Attestation sécu', 1, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'),
  ('mutuelle', 'Mutuelle', 1, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'),
  ('ordonnance', 'Ordonnance', 1, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'),
  ('pai', 'PAI', 1, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'),
  ('pass_nautique', 'Pass nautique', 0, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000');

INSERT INTO exigences_documentaires (id, type, sejour_id, session_id, obligatoire, bloque_convocation, cree_le, modifie_le)
SELECT '00000000-0000-4000-8000-000000000001', 'fiche_sanitaire', NULL, NULL, 1, 1, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'
WHERE NOT EXISTS (
  SELECT 1 FROM exigences_documentaires WHERE type = 'fiche_sanitaire' AND sejour_id IS NULL AND session_id IS NULL
);
INSERT INTO exigences_documentaires (id, type, sejour_id, session_id, obligatoire, bloque_convocation, cree_le, modifie_le)
SELECT '00000000-0000-4000-8000-000000000002', 'droit_image', NULL, NULL, 1, 1, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'
WHERE NOT EXISTS (
  SELECT 1 FROM exigences_documentaires WHERE type = 'droit_image' AND sejour_id IS NULL AND session_id IS NULL
);
INSERT INTO exigences_documentaires (id, type, sejour_id, session_id, obligatoire, bloque_convocation, cree_le, modifie_le)
SELECT '00000000-0000-4000-8000-000000000003', 'regime', NULL, NULL, 1, 1, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'
WHERE NOT EXISTS (
  SELECT 1 FROM exigences_documentaires WHERE type = 'regime' AND sejour_id IS NULL AND session_id IS NULL
);
INSERT INTO exigences_documentaires (id, type, sejour_id, session_id, obligatoire, bloque_convocation, cree_le, modifie_le)
SELECT '00000000-0000-4000-8000-000000000004', 'vaccination', NULL, NULL, 1, 1, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'
WHERE NOT EXISTS (
  SELECT 1 FROM exigences_documentaires WHERE type = 'vaccination' AND sejour_id IS NULL AND session_id IS NULL
);
INSERT INTO exigences_documentaires (id, type, sejour_id, session_id, obligatoire, bloque_convocation, cree_le, modifie_le)
SELECT '00000000-0000-4000-8000-000000000005', 'secu', NULL, NULL, 1, 1, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'
WHERE NOT EXISTS (
  SELECT 1 FROM exigences_documentaires WHERE type = 'secu' AND sejour_id IS NULL AND session_id IS NULL
);
INSERT INTO exigences_documentaires (id, type, sejour_id, session_id, obligatoire, bloque_convocation, cree_le, modifie_le)
SELECT '00000000-0000-4000-8000-000000000006', 'pai', NULL, NULL, 0, 0, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'
WHERE NOT EXISTS (
  SELECT 1 FROM exigences_documentaires WHERE type = 'pai' AND sejour_id IS NULL AND session_id IS NULL
);
INSERT INTO exigences_documentaires (id, type, sejour_id, session_id, obligatoire, bloque_convocation, cree_le, modifie_le)
SELECT '00000000-0000-4000-8000-000000000007', 'ordonnance', NULL, NULL, 0, 0, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'
WHERE NOT EXISTS (
  SELECT 1 FROM exigences_documentaires WHERE type = 'ordonnance' AND sejour_id IS NULL AND session_id IS NULL
);
INSERT INTO exigences_documentaires (id, type, sejour_id, session_id, obligatoire, bloque_convocation, cree_le, modifie_le)
SELECT '00000000-0000-4000-8000-000000000008', 'mutuelle', NULL, NULL, 0, 0, '2026-11-03 00:00:00.000', '2026-11-03 00:00:00.000'
WHERE NOT EXISTS (
  SELECT 1 FROM exigences_documentaires WHERE type = 'mutuelle' AND sejour_id IS NULL AND session_id IS NULL
);
