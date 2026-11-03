-- THALIE. Échéances, transactions bancaires, mouvements et ventilations.
-- La somme des ventilations égale le montant du mouvement : transaction applicative, pas une clé étrangère.
-- Le modèle ne porte pas commande_id sur ventilations : le schéma ne refuse pas encore une ventilation
-- vers une inscription d'une autre commande. Rejouer une clé de mouvement ou une référence prestataire
-- ne crée pas un second règlement. Un mouvement rattaché à une transaction doit viser la même commande.
-- Aucune échéance J, J+30, J+60 n'est insérée. Le mode cb_3_fois est seulement nommé.

CREATE TABLE IF NOT EXISTS echeances (
  id CHAR(36) NOT NULL,
  commande_id CHAR(36) NULL,
  inscription_id CHAR(36) NULL,
  echeance_le DATE NOT NULL,
  montant DECIMAL(10, 2) NOT NULL,
  mode VARCHAR(32) NOT NULL,
  rang TINYINT NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_echeances_commande (commande_id),
  KEY idx_echeances_inscription (inscription_id),
  CONSTRAINT fk_echeances_commande
    FOREIGN KEY (commande_id) REFERENCES commandes (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_echeances_inscription
    FOREIGN KEY (inscription_id) REFERENCES inscriptions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_echeances_cible CHECK ((commande_id IS NOT NULL) + (inscription_id IS NOT NULL) = 1),
  CONSTRAINT ck_echeances_mode CHECK (mode IN ('cb_comptant', 'cb_3_fois', 'cheque', 'virement', 'ancv_papier', 'ancv_connect'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS transactions_bancaires (
  id CHAR(36) NOT NULL,
  commande_id CHAR(36) NOT NULL,
  prestataire VARCHAR(32) NOT NULL,
  reference_prestataire VARCHAR(128) NOT NULL,
  type VARCHAR(32) NOT NULL,
  montant DECIMAL(10, 2) NOT NULL,
  statut VARCHAR(32) NOT NULL,
  resume VARCHAR(500) NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_transactions_id_commande (id, commande_id),
  UNIQUE KEY uq_transactions_reference (prestataire, reference_prestataire, type),
  KEY idx_transactions_commande (commande_id),
  CONSTRAINT fk_transactions_commande
    FOREIGN KEY (commande_id) REFERENCES commandes (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_transactions_type CHECK (type IN ('autorisation', 'capture', 'refus', 'remboursement'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS mouvements (
  id CHAR(36) NOT NULL,
  commande_id CHAR(36) NOT NULL,
  transaction_bancaire_id CHAR(36) NULL,
  sens VARCHAR(16) NOT NULL,
  mode VARCHAR(32) NOT NULL,
  montant DECIMAL(10, 2) NOT NULL,
  date_valeur DATE NOT NULL,
  reference VARCHAR(128) NULL,
  cle_idempotence VARCHAR(128) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_mouvements_cle (cle_idempotence),
  KEY idx_mouvements_commande (commande_id),
  KEY idx_mouvements_transaction_commande (transaction_bancaire_id, commande_id),
  CONSTRAINT fk_mouvements_commande
    FOREIGN KEY (commande_id) REFERENCES commandes (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_mouvements_transaction_commande
    FOREIGN KEY (transaction_bancaire_id, commande_id) REFERENCES transactions_bancaires (id, commande_id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_mouvements_sens CHECK (sens IN ('encaissement', 'remboursement')),
  CONSTRAINT ck_mouvements_mode CHECK (mode IN ('cb_comptant', 'cb_3_fois', 'cheque', 'virement', 'ancv_papier', 'ancv_connect')),
  CONSTRAINT ck_mouvements_montant CHECK (montant > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ventilations (
  id CHAR(36) NOT NULL,
  mouvement_id CHAR(36) NOT NULL,
  inscription_id CHAR(36) NOT NULL,
  montant DECIMAL(10, 2) NOT NULL,
  cree_le DATETIME(3) NOT NULL,
  modifie_le DATETIME(3) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_ventilations_mouvement (mouvement_id),
  KEY idx_ventilations_inscription (inscription_id),
  CONSTRAINT fk_ventilations_mouvement
    FOREIGN KEY (mouvement_id) REFERENCES mouvements (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_ventilations_inscription
    FOREIGN KEY (inscription_id) REFERENCES inscriptions (id)
    ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT ck_ventilations_montant CHECK (montant > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
