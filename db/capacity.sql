-- Moteur de places THALIE. Procédures dans la base courante, sans changer les tables.
-- À appliquer seulement sur thalie_test :
--   mariadb --protocol=socket thalie_test < db/capacity.sql
--
-- Disponibilité = capacité
--   - places hors contingent bloquées
--   - places hors contingent confirmées
--   - somme des places_bloquees des contingents de la session.
-- Un contingent bloque GREATEST(reel_estime, realise). Les options posées ne retirent rien.
-- Les compteurs de session ne comptent pas les inscrits du contingent.
-- Une clé déjà vue pour la même opération ne change rien.
-- Une clé déjà vue pour une autre opération est refusée.
-- Une nouvelle réservation, ou une hausse du blocage d'un contingent, exige une session ouverte.
-- Confirmer, annuler, baisser un contingent ou rapprocher une inscription restent possibles sinon.
-- Une inscription annulée, refusée ou transférée n'est jamais réactivée.
-- Ordre de verrouillage de chaque opération : session, contingents par id, inscription.
-- constater_ecart_places ne prend pas ces verrous et n'écrit rien.
-- modifier_capacite verrouille la session, refuse une capacité sous les places tenues
-- et écrit historique_capacites dans la même transaction. Elle ne change ni les
-- inscriptions ni les estimations de contingent.

DROP PROCEDURE IF EXISTS classer_cle;
DROP PROCEDURE IF EXISTS sortir_cle;
DROP PROCEDURE IF EXISTS constater_ecart_places;
DROP PROCEDURE IF EXISTS verrouiller_contingents;
DROP PROCEDURE IF EXISTS verifier_places;
DROP PROCEDURE IF EXISTS bloquer_place;
DROP PROCEDURE IF EXISTS confirmer_inscription;
DROP PROCEDURE IF EXISTS annuler_inscription;
DROP PROCEDURE IF EXISTS ajuster_contingent;
DROP PROCEDURE IF EXISTS inscrire_contingent;
DROP PROCEDURE IF EXISTS rapprocher_contingent;
DROP PROCEDURE IF EXISTS modifier_capacite;

DELIMITER //

-- Lecture seule. Signale les écarts entre les compteurs et les inscriptions actives.
-- N'écrit aucune table : la correction reste une décision séparée.
CREATE PROCEDURE constater_ecart_places(IN p_session_id CHAR(36))
BEGIN
  DECLARE v_n INT DEFAULT 0;

  SELECT COUNT(*) INTO v_n FROM sessions WHERE id = p_session_id;
  IF v_n = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'session_inconnue';
  END IF;

  SELECT 'session' AS cible, s.id AS cible_id, 'places_bloquees' AS compteur,
         s.places_bloquees AS valeur_enregistree,
         (SELECT COUNT(*) FROM inscriptions i
          WHERE i.session_id = s.id AND i.contingent_id IS NULL
            AND i.statut_administratif = 'place_bloquee') AS valeur_calculee
  FROM sessions s
  WHERE s.id = p_session_id
    AND s.places_bloquees <> (
      SELECT COUNT(*) FROM inscriptions i
      WHERE i.session_id = s.id AND i.contingent_id IS NULL
        AND i.statut_administratif = 'place_bloquee'
    )
  UNION ALL
  SELECT 'session', s.id, 'places_confirmees', s.places_confirmees,
         (SELECT COUNT(*) FROM inscriptions i
          WHERE i.session_id = s.id AND i.contingent_id IS NULL
            AND i.statut_administratif = 'confirmee')
  FROM sessions s
  WHERE s.id = p_session_id
    AND s.places_confirmees <> (
      SELECT COUNT(*) FROM inscriptions i
      WHERE i.session_id = s.id AND i.contingent_id IS NULL
        AND i.statut_administratif = 'confirmee'
    )
  UNION ALL
  SELECT 'session', s.id, 'places_liberees', s.places_liberees,
         (SELECT COUNT(*) FROM suivi_places sp
          WHERE sp.session_id = s.id AND sp.effet = 'liberation')
  FROM sessions s
  WHERE s.id = p_session_id
    AND s.places_liberees <> (
      SELECT COUNT(*) FROM suivi_places sp
      WHERE sp.session_id = s.id AND sp.effet = 'liberation'
    )
  UNION ALL
  SELECT 'session', s.id, 'disponibilite',
         s.capacite - s.places_bloquees - s.places_confirmees
           - COALESCE((SELECT SUM(c.places_bloquees) FROM contingents c WHERE c.session_id = s.id), 0),
         0
  FROM sessions s
  WHERE s.id = p_session_id
    AND s.capacite - s.places_bloquees - s.places_confirmees
        - COALESCE((SELECT SUM(c.places_bloquees) FROM contingents c WHERE c.session_id = s.id), 0) < 0
  UNION ALL
  SELECT 'contingent', c.id, 'realise', c.realise,
         (SELECT COUNT(*) FROM inscriptions i
          WHERE i.contingent_id = c.id
            AND i.statut_administratif IN ('place_bloquee', 'confirmee'))
  FROM contingents c
  WHERE c.session_id = p_session_id
    AND c.realise <> (
      SELECT COUNT(*) FROM inscriptions i
      WHERE i.contingent_id = c.id
        AND i.statut_administratif IN ('place_bloquee', 'confirmee')
    );
END //

CREATE PROCEDURE verrouiller_contingents(IN p_session_id CHAR(36))
BEGIN
  DECLARE v_id CHAR(36);
  DECLARE v_fini INT DEFAULT 0;
  DECLARE cur CURSOR FOR
    SELECT id FROM contingents WHERE session_id = p_session_id ORDER BY id FOR UPDATE;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fini = 1;
  OPEN cur;
  boucle: LOOP
    FETCH cur INTO v_id;
    IF v_fini = 1 THEN LEAVE boucle; END IF;
  END LOOP;
  CLOSE cur;
END //

CREATE PROCEDURE verifier_places(IN p_session_id CHAR(36))
BEGIN
  DECLARE v_mauvais INT DEFAULT 0;

  SELECT COUNT(*) INTO v_mauvais
  FROM sessions s
  WHERE s.id = p_session_id
    AND (
      s.places_bloquees <> (
        SELECT COUNT(*) FROM inscriptions i
        WHERE i.session_id = s.id
          AND i.contingent_id IS NULL
          AND i.statut_administratif = 'place_bloquee'
      )
      OR s.places_confirmees <> (
        SELECT COUNT(*) FROM inscriptions i
        WHERE i.session_id = s.id
          AND i.contingent_id IS NULL
          AND i.statut_administratif = 'confirmee'
      )
      OR s.capacite - s.places_bloquees - s.places_confirmees - COALESCE((
        SELECT SUM(c.places_bloquees) FROM contingents c WHERE c.session_id = s.id
      ), 0) < 0
    );

  IF v_mauvais <> 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'incoherence_compteurs';
  END IF;

  SELECT COUNT(*) INTO v_mauvais
  FROM contingents c
  WHERE c.session_id = p_session_id
    AND c.realise <> (
      SELECT COUNT(*) FROM inscriptions i
      WHERE i.contingent_id = c.id
        AND i.statut_administratif IN ('place_bloquee', 'confirmee')
    );

  IF v_mauvais <> 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'incoherence_realise';
  END IF;
END //

-- absente, deja_applique, ou cle_deja_utilisee. Ne modifie aucune donnée.
CREATE PROCEDURE classer_cle(
  IN p_cle VARCHAR(128),
  IN p_operation VARCHAR(32),
  IN p_inscription_id CHAR(36),
  IN p_contingent_id CHAR(36),
  IN p_champ VARCHAR(32),
  IN p_session_id CHAR(36),
  IN p_capacite_apres INT,
  OUT p_code VARCHAR(32)
)
BEGIN
  DECLARE v_suivi_n INT DEFAULT 0;
  DECLARE v_suivi_ok INT DEFAULT 0;
  DECLARE v_hist_n INT DEFAULT 0;
  DECLARE v_hist_ok INT DEFAULT 0;
  DECLARE v_evt_n INT DEFAULT 0;
  DECLARE v_evt_ok INT DEFAULT 0;
  DECLARE v_cap_n INT DEFAULT 0;
  DECLARE v_cap_ok INT DEFAULT 0;
  DECLARE v_effet VARCHAR(32) DEFAULT NULL;
  DECLARE v_type VARCHAR(32) DEFAULT NULL;

  IF p_operation = 'blocage' THEN
    SET v_effet = 'blocage';
  ELSEIF p_operation = 'confirmation' THEN
    SET v_effet = 'confirmation';
    SET v_type = 'confirmation';
  ELSEIF p_operation = 'liberation' THEN
    SET v_effet = 'liberation';
    SET v_type = 'annulation';
  ELSEIF p_operation = 'inscription_contingent' THEN
    SET v_type = 'creation';
  ELSEIF p_operation = 'rapprochement' THEN
    SET v_type = 'synchro';
  END IF;

  SELECT COUNT(*) INTO v_suivi_n FROM suivi_places WHERE cle_idempotence = p_cle;
  IF v_suivi_n > 0 AND v_effet IS NOT NULL THEN
    SELECT COUNT(*) INTO v_suivi_ok FROM suivi_places
    WHERE cle_idempotence = p_cle AND effet = v_effet AND inscription_id = p_inscription_id;
  END IF;

  SELECT COUNT(*) INTO v_hist_n FROM historique_contingents WHERE cle_idempotence = p_cle;
  IF v_hist_n > 0 AND p_operation IN ('ajustement', 'inscription_contingent', 'rapprochement', 'liberation') THEN
    SELECT COUNT(*) INTO v_hist_ok FROM historique_contingents
    WHERE cle_idempotence = p_cle
      AND (
        (p_operation = 'ajustement' AND champ = p_champ AND contingent_id = p_contingent_id)
        OR (p_operation = 'liberation' AND champ = 'realise'
            AND (p_contingent_id IS NULL OR contingent_id = p_contingent_id))
        OR (p_operation IN ('inscription_contingent', 'rapprochement')
            AND champ = 'realise' AND contingent_id = p_contingent_id)
      );
  END IF;

  SELECT COUNT(*) INTO v_evt_n FROM inscription_evenements WHERE cle_idempotence = p_cle;
  IF v_evt_n > 0 AND v_type IS NOT NULL THEN
    SELECT COUNT(*) INTO v_evt_ok FROM inscription_evenements
    WHERE cle_idempotence = p_cle AND type = v_type AND inscription_id = p_inscription_id;
  END IF;

  SELECT COUNT(*) INTO v_cap_n FROM historique_capacites WHERE cle_idempotence = p_cle;
  IF v_cap_n > 0 AND p_operation = 'capacite' THEN
    SELECT COUNT(*) INTO v_cap_ok FROM historique_capacites
    WHERE cle_idempotence = p_cle
      AND session_id = p_session_id
      AND capacite_apres = p_capacite_apres;
  END IF;

  IF v_suivi_n + v_hist_n + v_evt_n + v_cap_n = 0 THEN
    SET p_code = 'absente';
  ELSEIF p_operation = 'blocage'
     AND v_suivi_ok = 1 AND v_hist_n = 0 AND v_evt_n = 0 AND v_cap_n = 0 THEN
    SET p_code = 'deja_applique';
  ELSEIF p_operation = 'confirmation'
     AND v_hist_n = 0 AND v_cap_n = 0
     AND (
       (v_suivi_ok = 1 AND v_evt_n = 0)
       OR (v_evt_ok = 1 AND v_suivi_n = 0)
     ) THEN
    SET p_code = 'deja_applique';
  ELSEIF p_operation = 'liberation'
     AND v_cap_n = 0
     AND (
       (v_suivi_ok = 1 AND v_hist_n = 0 AND v_evt_n = 0)
       OR (v_evt_ok = 1 AND v_hist_ok = 1 AND v_suivi_n = 0)
     ) THEN
    SET p_code = 'deja_applique';
  ELSEIF p_operation = 'ajustement'
     AND v_hist_ok = 1 AND v_suivi_n = 0 AND v_evt_n = 0 AND v_cap_n = 0 THEN
    SET p_code = 'deja_applique';
  ELSEIF p_operation IN ('inscription_contingent', 'rapprochement')
     AND v_evt_ok = 1 AND v_hist_ok = 1 AND v_suivi_n = 0 AND v_cap_n = 0 THEN
    SET p_code = 'deja_applique';
  ELSEIF p_operation = 'capacite'
     AND v_cap_ok = 1 AND v_suivi_n = 0 AND v_hist_n = 0 AND v_evt_n = 0 THEN
    SET p_code = 'deja_applique';
  ELSE
    SET p_code = 'cle_deja_utilisee';
  END IF;
END //

CREATE PROCEDURE sortir_cle(IN p_code VARCHAR(32))
BEGIN
  IF p_code = 'deja_applique' THEN
    COMMIT;
    SELECT 'deja_applique' AS resultat;
  ELSEIF p_code = 'cle_deja_utilisee' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'cle_deja_utilisee';
  END IF;
END //

CREATE PROCEDURE bloquer_place(
  IN p_inscription_id CHAR(36),
  IN p_commande_id CHAR(36),
  IN p_famille_id CHAR(36),
  IN p_enfant_id CHAR(36),
  IN p_sejour_id CHAR(36),
  IN p_session_id CHAR(36),
  IN p_cle VARCHAR(128)
)
proc: BEGIN
  DECLARE v_cap INT;
  DECLARE v_blo INT;
  DECLARE v_conf INT;
  DECLARE v_sum INT;
  DECLARE v_dispo INT;
  DECLARE v_statut VARCHAR(32);
  DECLARE v_session CHAR(36);
  DECLARE v_contingent CHAR(36);
  DECLARE v_enfant CHAR(36);
  DECLARE v_commercial VARCHAR(32);
  DECLARE v_trouvee INT DEFAULT 0;
  DECLARE v_autre INT DEFAULT 0;
  DECLARE v_code VARCHAR(32);
  DECLARE v_errno INT;
  DECLARE v_msg TEXT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    ROLLBACK;
    IF v_errno = 1062 THEN
      CALL classer_cle(p_cle, 'blocage', p_inscription_id, NULL, NULL, NULL, NULL, v_code);
      IF v_code IN ('deja_applique', 'cle_deja_utilisee') THEN
        CALL sortir_cle(v_code);
      ELSEIF v_msg LIKE '%uq_inscriptions_actif%' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'deja_inscrit';
      ELSE
        RESIGNAL;
      END IF;
    ELSE
      RESIGNAL;
    END IF;
  END;

  IF p_cle IS NULL OR CHAR_LENGTH(p_cle) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'cle_requise';
  END IF;

  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  CALL classer_cle(p_cle, 'blocage', p_inscription_id, NULL, NULL, NULL, NULL, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;

  SELECT COUNT(*) INTO v_trouvee FROM sessions WHERE id = p_session_id;
  IF v_trouvee = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'session_inconnue';
  END IF;

  SELECT capacite, places_bloquees, places_confirmees, statut_commercial
    INTO v_cap, v_blo, v_conf, v_commercial
  FROM sessions WHERE id = p_session_id FOR UPDATE;
  CALL verrouiller_contingents(p_session_id);
  CALL classer_cle(p_cle, 'blocage', p_inscription_id, NULL, NULL, NULL, NULL, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;

  SELECT COUNT(*) INTO v_trouvee FROM inscriptions WHERE id = p_inscription_id;
  IF v_trouvee = 1 THEN
    SELECT statut_administratif, session_id, contingent_id, enfant_id
      INTO v_statut, v_session, v_contingent, v_enfant
    FROM inscriptions WHERE id = p_inscription_id FOR UPDATE;
    IF v_session <> p_session_id OR v_enfant <> p_enfant_id THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'etat_incompatible';
    END IF;
    IF v_statut IN ('place_bloquee', 'confirmee') THEN
      COMMIT;
      SELECT 'deja_actif' AS resultat;
      LEAVE proc;
    END IF;
    IF v_statut IN ('annulee', 'refusee', 'transferee') THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'reactivation_interdite';
    END IF;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'etat_incompatible';
  END IF;

  SELECT COUNT(*) INTO v_autre
  FROM inscriptions
  WHERE enfant_id = p_enfant_id
    AND session_id = p_session_id
    AND statut_administratif IN ('place_bloquee', 'confirmee')
    AND id <> p_inscription_id;
  IF v_autre > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'deja_inscrit';
  END IF;

  IF v_commercial <> 'ouverte' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'session_non_ouverte';
  END IF;

  SELECT COALESCE(SUM(places_bloquees), 0) INTO v_sum
  FROM contingents WHERE session_id = p_session_id;
  SET v_dispo = v_cap - v_blo - v_conf - v_sum;
  IF v_dispo < 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'capacite_insuffisante';
  END IF;

  INSERT INTO inscriptions (
    id, commande_id, famille_id, enfant_id, sejour_id, session_id,
    statut_administratif, statut_financier, statut_documentaire, cree_le, modifie_le
  ) VALUES (
    p_inscription_id, p_commande_id, p_famille_id, p_enfant_id, p_sejour_id, p_session_id,
    'place_bloquee', 'aucun', 'manquant', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)
  );

  UPDATE sessions
  SET places_bloquees = places_bloquees + 1, modifie_le = UTC_TIMESTAMP(3)
  WHERE id = p_session_id;

  INSERT INTO suivi_places (
    id, session_id, contingent_id, inscription_id, effet, cle_idempotence, cree_le
  ) VALUES (
    UUID(), p_session_id, NULL, p_inscription_id, 'blocage', p_cle, UTC_TIMESTAMP(3)
  );

  CALL verifier_places(p_session_id);
  COMMIT;
  SELECT 'ok' AS resultat;
END //

CREATE PROCEDURE confirmer_inscription(
  IN p_inscription_id CHAR(36),
  IN p_cle VARCHAR(128)
)
proc: BEGIN
  DECLARE v_statut VARCHAR(32);
  DECLARE v_session CHAR(36);
  DECLARE v_contingent CHAR(36);
  DECLARE v_blo INT;
  DECLARE v_code VARCHAR(32);
  DECLARE v_errno INT;
  DECLARE v_msg TEXT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    ROLLBACK;
    IF v_errno = 1062 THEN
      CALL classer_cle(p_cle, 'confirmation', p_inscription_id, NULL, NULL, NULL, NULL, v_code);
      IF v_code IN ('deja_applique', 'cle_deja_utilisee') THEN
        CALL sortir_cle(v_code);
      ELSE
        RESIGNAL;
      END IF;
    ELSE
      RESIGNAL;
    END IF;
  END;

  IF p_cle IS NULL OR CHAR_LENGTH(p_cle) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'cle_requise';
  END IF;

  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  CALL classer_cle(p_cle, 'confirmation', p_inscription_id, NULL, NULL, NULL, NULL, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;

  SELECT COUNT(*) INTO v_blo FROM inscriptions WHERE id = p_inscription_id;
  IF v_blo = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'inscription_inconnue';
  END IF;
  SELECT session_id INTO v_session FROM inscriptions WHERE id = p_inscription_id;

  SELECT places_bloquees INTO v_blo FROM sessions WHERE id = v_session FOR UPDATE;
  CALL verrouiller_contingents(v_session);
  CALL classer_cle(p_cle, 'confirmation', p_inscription_id, NULL, NULL, NULL, NULL, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;
  SELECT statut_administratif, contingent_id
    INTO v_statut, v_contingent
  FROM inscriptions WHERE id = p_inscription_id FOR UPDATE;

  IF v_statut = 'confirmee' THEN
    COMMIT;
    SELECT 'deja_confirme' AS resultat;
    LEAVE proc;
  END IF;
  IF v_statut <> 'place_bloquee' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'etat_incompatible';
  END IF;

  UPDATE inscriptions
  SET statut_administratif = 'confirmee', modifie_le = UTC_TIMESTAMP(3)
  WHERE id = p_inscription_id;

  IF v_contingent IS NULL THEN
    IF v_blo < 1 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'incoherence_compteurs';
    END IF;
    UPDATE sessions
    SET places_bloquees = places_bloquees - 1,
        places_confirmees = places_confirmees + 1,
        modifie_le = UTC_TIMESTAMP(3)
    WHERE id = v_session;
    INSERT INTO suivi_places (
      id, session_id, contingent_id, inscription_id, effet, cle_idempotence, cree_le
    ) VALUES (
      UUID(), v_session, NULL, p_inscription_id, 'confirmation', p_cle, UTC_TIMESTAMP(3)
    );
  ELSE
    INSERT INTO inscription_evenements (
      id, inscription_id, type, source, resume, cle_idempotence, cree_le
    ) VALUES (
      UUID(), p_inscription_id, 'confirmation', 'site', 'confirmation', p_cle, UTC_TIMESTAMP(3)
    );
  END IF;

  CALL verifier_places(v_session);
  COMMIT;
  SELECT 'ok' AS resultat;
END //

CREATE PROCEDURE annuler_inscription(
  IN p_inscription_id CHAR(36),
  IN p_cle VARCHAR(128),
  IN p_source VARCHAR(32)
)
proc: BEGIN
  DECLARE v_statut VARCHAR(32);
  DECLARE v_session CHAR(36);
  DECLARE v_contingent CHAR(36);
  DECLARE v_blo INT;
  DECLARE v_conf INT;
  DECLARE v_reel INT;
  DECLARE v_block INT;
  DECLARE v_code VARCHAR(32);
  DECLARE v_errno INT;
  DECLARE v_msg TEXT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    ROLLBACK;
    IF v_errno = 1062 THEN
      CALL classer_cle(p_cle, 'liberation', p_inscription_id, v_contingent, NULL, NULL, NULL, v_code);
      IF v_code IN ('deja_applique', 'cle_deja_utilisee') THEN
        CALL sortir_cle(v_code);
      ELSE
        RESIGNAL;
      END IF;
    ELSE
      RESIGNAL;
    END IF;
  END;

  IF p_cle IS NULL OR CHAR_LENGTH(p_cle) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'cle_requise';
  END IF;
  IF p_source NOT IN ('site', 'filemaker', 'admin') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'source_inconnue';
  END IF;

  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  CALL classer_cle(p_cle, 'liberation', p_inscription_id, NULL, NULL, NULL, NULL, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;

  SELECT COUNT(*) INTO v_blo FROM inscriptions WHERE id = p_inscription_id;
  IF v_blo = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'inscription_inconnue';
  END IF;
  SELECT session_id INTO v_session FROM inscriptions WHERE id = p_inscription_id;

  SELECT places_bloquees, places_confirmees INTO v_blo, v_conf
  FROM sessions WHERE id = v_session FOR UPDATE;
  CALL verrouiller_contingents(v_session);
  SELECT statut_administratif, contingent_id
    INTO v_statut, v_contingent
  FROM inscriptions WHERE id = p_inscription_id FOR UPDATE;
  CALL classer_cle(p_cle, 'liberation', p_inscription_id, v_contingent, NULL, NULL, NULL, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;

  IF v_statut NOT IN ('place_bloquee', 'confirmee') THEN
    COMMIT;
    SELECT 'deja_inactif' AS resultat;
    LEAVE proc;
  END IF;

  UPDATE inscriptions
  SET statut_administratif = 'annulee', modifie_le = UTC_TIMESTAMP(3)
  WHERE id = p_inscription_id;

  IF v_contingent IS NULL THEN
    IF v_statut = 'place_bloquee' AND v_blo < 1 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'incoherence_compteurs';
    END IF;
    IF v_statut = 'confirmee' AND v_conf < 1 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'incoherence_compteurs';
    END IF;
    UPDATE sessions
    SET places_bloquees = places_bloquees - IF(v_statut = 'place_bloquee', 1, 0),
        places_confirmees = places_confirmees - IF(v_statut = 'confirmee', 1, 0),
        places_liberees = places_liberees + 1,
        modifie_le = UTC_TIMESTAMP(3)
    WHERE id = v_session;
    INSERT INTO suivi_places (
      id, session_id, contingent_id, inscription_id, effet, cle_idempotence, cree_le
    ) VALUES (
      UUID(), v_session, NULL, p_inscription_id, 'liberation', p_cle, UTC_TIMESTAMP(3)
    );
  ELSE
    SELECT realise INTO v_reel FROM contingents WHERE id = v_contingent FOR UPDATE;
    IF v_reel < 1 THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'incoherence_realise';
    END IF;
    UPDATE contingents
    SET realise = realise - 1, modifie_le = UTC_TIMESTAMP(3)
    WHERE id = v_contingent;
    SELECT places_bloquees INTO v_block FROM contingents WHERE id = v_contingent;
    INSERT INTO historique_contingents (
      id, contingent_id, champ, valeur_avant, valeur_apres, places_bloquees_apres,
      source, cle_idempotence, cree_le
    ) VALUES (
      UUID(), v_contingent, 'realise', v_reel, v_reel - 1, v_block,
      p_source, p_cle, UTC_TIMESTAMP(3)
    );
    INSERT INTO inscription_evenements (
      id, inscription_id, type, source, resume, cle_idempotence, cree_le
    ) VALUES (
      UUID(), p_inscription_id, 'annulation', p_source, 'annulation', p_cle, UTC_TIMESTAMP(3)
    );
  END IF;

  CALL verifier_places(v_session);
  COMMIT;
  SELECT 'ok' AS resultat;
END //

CREATE PROCEDURE ajuster_contingent(
  IN p_contingent_id CHAR(36),
  IN p_champ VARCHAR(32),
  IN p_valeur INT,
  IN p_cle VARCHAR(128),
  IN p_source VARCHAR(32)
)
proc: BEGIN
  DECLARE v_session CHAR(36);
  DECLARE v_options INT;
  DECLARE v_reel INT;
  DECLARE v_realise INT;
  DECLARE v_block INT;
  DECLARE v_cap INT;
  DECLARE v_blo INT;
  DECLARE v_conf INT;
  DECLARE v_sum INT;
  DECLARE v_dispo INT;
  DECLARE v_nouveau_block INT;
  DECLARE v_apres INT;
  DECLARE v_commercial VARCHAR(32);
  DECLARE v_code VARCHAR(32);
  DECLARE v_errno INT;
  DECLARE v_msg TEXT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    ROLLBACK;
    IF v_errno = 1062 THEN
      CALL classer_cle(p_cle, 'ajustement', NULL, p_contingent_id, p_champ, NULL, NULL, v_code);
      IF v_code IN ('deja_applique', 'cle_deja_utilisee') THEN
        CALL sortir_cle(v_code);
      ELSE
        RESIGNAL;
      END IF;
    ELSE
      RESIGNAL;
    END IF;
  END;

  IF p_cle IS NULL OR CHAR_LENGTH(p_cle) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'cle_requise';
  END IF;
  IF p_source NOT IN ('site', 'filemaker', 'admin') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'source_inconnue';
  END IF;
  IF p_champ NOT IN ('reel_estime', 'options_posees') OR p_valeur < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ajustement_interdit';
  END IF;

  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  CALL classer_cle(p_cle, 'ajustement', NULL, p_contingent_id, p_champ, NULL, NULL, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;

  SELECT COUNT(*) INTO v_cap FROM contingents WHERE id = p_contingent_id;
  IF v_cap = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'contingent_inconnu';
  END IF;

  SELECT session_id INTO v_session FROM contingents WHERE id = p_contingent_id;
  SELECT capacite, places_bloquees, places_confirmees, statut_commercial
    INTO v_cap, v_blo, v_conf, v_commercial
  FROM sessions WHERE id = v_session FOR UPDATE;
  CALL verrouiller_contingents(v_session);
  CALL classer_cle(p_cle, 'ajustement', NULL, p_contingent_id, p_champ, NULL, NULL, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;

  SELECT options_posees, reel_estime, realise, places_bloquees
    INTO v_options, v_reel, v_realise, v_block
  FROM contingents WHERE id = p_contingent_id;

  IF p_champ = 'options_posees' AND p_valeur = v_options THEN
    COMMIT;
    SELECT 'inchange' AS resultat;
    LEAVE proc;
  END IF;
  IF p_champ = 'reel_estime' AND p_valeur = v_reel THEN
    COMMIT;
    SELECT 'inchange' AS resultat;
    LEAVE proc;
  END IF;

  IF p_champ = 'reel_estime' THEN
    SET v_nouveau_block = IF(p_valeur > v_realise, p_valeur, v_realise);
    SELECT COALESCE(SUM(places_bloquees), 0) INTO v_sum
    FROM contingents WHERE session_id = v_session;
    SET v_dispo = v_cap - v_blo - v_conf - v_sum;
    IF v_nouveau_block > v_block AND v_commercial <> 'ouverte' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'session_non_ouverte';
    END IF;
    IF v_nouveau_block - v_block > v_dispo THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'capacite_insuffisante';
    END IF;
    UPDATE contingents
    SET reel_estime = p_valeur, modifie_le = UTC_TIMESTAMP(3)
    WHERE id = p_contingent_id;
    SET v_apres = p_valeur;
  ELSE
    UPDATE contingents
    SET options_posees = p_valeur, modifie_le = UTC_TIMESTAMP(3)
    WHERE id = p_contingent_id;
    SET v_apres = p_valeur;
  END IF;

  SELECT places_bloquees INTO v_block FROM contingents WHERE id = p_contingent_id;
  INSERT INTO historique_contingents (
    id, contingent_id, champ, valeur_avant, valeur_apres, places_bloquees_apres,
    source, cle_idempotence, cree_le
  ) VALUES (
    UUID(), p_contingent_id, p_champ,
    IF(p_champ = 'reel_estime', v_reel, v_options), v_apres, v_block,
    p_source, p_cle, UTC_TIMESTAMP(3)
  );

  CALL verifier_places(v_session);
  COMMIT;
  SELECT 'ok' AS resultat;
END //

CREATE PROCEDURE inscrire_contingent(
  IN p_inscription_id CHAR(36),
  IN p_commande_id CHAR(36),
  IN p_famille_id CHAR(36),
  IN p_enfant_id CHAR(36),
  IN p_sejour_id CHAR(36),
  IN p_session_id CHAR(36),
  IN p_contingent_id CHAR(36),
  IN p_cle VARCHAR(128),
  IN p_source VARCHAR(32)
)
proc: BEGIN
  DECLARE v_cap INT;
  DECLARE v_blo INT;
  DECLARE v_conf INT;
  DECLARE v_sum INT;
  DECLARE v_dispo INT;
  DECLARE v_session CHAR(36);
  DECLARE v_reel INT;
  DECLARE v_realise INT;
  DECLARE v_block INT;
  DECLARE v_statut VARCHAR(32);
  DECLARE v_trouvee INT DEFAULT 0;
  DECLARE v_autre INT DEFAULT 0;
  DECLARE v_delta INT;
  DECLARE v_commercial VARCHAR(32);
  DECLARE v_code VARCHAR(32);
  DECLARE v_errno INT;
  DECLARE v_msg TEXT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    ROLLBACK;
    IF v_errno = 1062 THEN
      CALL classer_cle(p_cle, 'inscription_contingent', p_inscription_id, p_contingent_id, NULL, NULL, NULL, v_code);
      IF v_code IN ('deja_applique', 'cle_deja_utilisee') THEN
        CALL sortir_cle(v_code);
      ELSEIF v_msg LIKE '%uq_inscriptions_actif%' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'deja_inscrit';
      ELSE
        RESIGNAL;
      END IF;
    ELSE
      RESIGNAL;
    END IF;
  END;

  IF p_cle IS NULL OR CHAR_LENGTH(p_cle) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'cle_requise';
  END IF;
  IF p_source NOT IN ('site', 'filemaker', 'admin') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'source_inconnue';
  END IF;

  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  CALL classer_cle(p_cle, 'inscription_contingent', p_inscription_id, p_contingent_id, NULL, NULL, NULL, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;

  SELECT COUNT(*) INTO v_trouvee FROM contingents WHERE id = p_contingent_id;
  IF v_trouvee = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'contingent_inconnu';
  END IF;
  SELECT session_id INTO v_session FROM contingents WHERE id = p_contingent_id;
  IF v_session <> p_session_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'contingent_hors_session';
  END IF;

  SELECT capacite, places_bloquees, places_confirmees, statut_commercial
    INTO v_cap, v_blo, v_conf, v_commercial
  FROM sessions WHERE id = p_session_id FOR UPDATE;
  CALL verrouiller_contingents(p_session_id);
  CALL classer_cle(p_cle, 'inscription_contingent', p_inscription_id, p_contingent_id, NULL, NULL, NULL, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;
  SELECT reel_estime, realise, places_bloquees
    INTO v_reel, v_realise, v_block
  FROM contingents WHERE id = p_contingent_id;

  SELECT COUNT(*) INTO v_trouvee FROM inscriptions WHERE id = p_inscription_id;
  IF v_trouvee = 1 THEN
    SELECT statut_administratif, session_id, contingent_id
      INTO v_statut, v_session, v_sum
    FROM inscriptions WHERE id = p_inscription_id FOR UPDATE;
    IF v_session <> p_session_id THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'etat_incompatible';
    END IF;
    IF v_statut IN ('place_bloquee', 'confirmee') AND v_sum = p_contingent_id THEN
      COMMIT;
      SELECT 'deja_actif' AS resultat;
      LEAVE proc;
    END IF;
    IF v_statut IN ('place_bloquee', 'confirmee') THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'etat_incompatible';
    END IF;
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'reactivation_interdite';
  END IF;

  SELECT COUNT(*) INTO v_autre
  FROM inscriptions
  WHERE enfant_id = p_enfant_id
    AND session_id = p_session_id
    AND statut_administratif IN ('place_bloquee', 'confirmee')
    AND id <> p_inscription_id;
  IF v_autre > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'deja_inscrit';
  END IF;

  IF v_commercial <> 'ouverte' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'session_non_ouverte';
  END IF;

  SET v_delta = IF(v_reel > v_realise, v_reel, v_realise + 1) - v_block;
  SELECT COALESCE(SUM(places_bloquees), 0) INTO v_sum
  FROM contingents WHERE session_id = p_session_id;
  SET v_dispo = v_cap - v_blo - v_conf - v_sum;
  IF v_delta > v_dispo THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'capacite_insuffisante';
  END IF;

  INSERT INTO inscriptions (
    id, commande_id, famille_id, enfant_id, sejour_id, session_id, contingent_id,
    statut_administratif, statut_financier, statut_documentaire, cree_le, modifie_le
  ) VALUES (
    p_inscription_id, p_commande_id, p_famille_id, p_enfant_id, p_sejour_id, p_session_id,
    p_contingent_id, 'place_bloquee', 'aucun', 'manquant', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)
  );

  UPDATE contingents
  SET realise = realise + 1, modifie_le = UTC_TIMESTAMP(3)
  WHERE id = p_contingent_id;
  SELECT places_bloquees INTO v_block FROM contingents WHERE id = p_contingent_id;
  INSERT INTO historique_contingents (
    id, contingent_id, champ, valeur_avant, valeur_apres, places_bloquees_apres,
    source, cle_idempotence, cree_le
  ) VALUES (
    UUID(), p_contingent_id, 'realise', v_realise, v_realise + 1, v_block,
    p_source, p_cle, UTC_TIMESTAMP(3)
  );
  INSERT INTO inscription_evenements (
    id, inscription_id, type, source, resume, cle_idempotence, cree_le
  ) VALUES (
    UUID(), p_inscription_id, 'creation', p_source, 'inscription contingent', p_cle, UTC_TIMESTAMP(3)
  );

  CALL verifier_places(p_session_id);
  COMMIT;
  SELECT 'ok' AS resultat;
END //

CREATE PROCEDURE rapprocher_contingent(
  IN p_inscription_id CHAR(36),
  IN p_contingent_id CHAR(36),
  IN p_cle VARCHAR(128),
  IN p_source VARCHAR(32)
)
proc: BEGIN
  DECLARE v_statut VARCHAR(32);
  DECLARE v_session CHAR(36);
  DECLARE v_actuel CHAR(36);
  DECLARE v_c_session CHAR(36);
  DECLARE v_blo INT;
  DECLARE v_conf INT;
  DECLARE v_reel INT;
  DECLARE v_realise INT;
  DECLARE v_block INT;
  DECLARE v_trouvee INT;
  DECLARE v_code VARCHAR(32);
  DECLARE v_errno INT;
  DECLARE v_msg TEXT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    ROLLBACK;
    IF v_errno = 1062 THEN
      CALL classer_cle(p_cle, 'rapprochement', p_inscription_id, p_contingent_id, NULL, NULL, NULL, v_code);
      IF v_code IN ('deja_applique', 'cle_deja_utilisee') THEN
        CALL sortir_cle(v_code);
      ELSE
        RESIGNAL;
      END IF;
    ELSE
      RESIGNAL;
    END IF;
  END;

  IF p_cle IS NULL OR CHAR_LENGTH(p_cle) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'cle_requise';
  END IF;
  IF p_source NOT IN ('site', 'filemaker', 'admin') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'source_inconnue';
  END IF;

  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  CALL classer_cle(p_cle, 'rapprochement', p_inscription_id, p_contingent_id, NULL, NULL, NULL, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;

  SELECT COUNT(*) INTO v_trouvee FROM inscriptions WHERE id = p_inscription_id;
  IF v_trouvee = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'inscription_inconnue';
  END IF;
  SELECT COUNT(*) INTO v_trouvee FROM contingents WHERE id = p_contingent_id;
  IF v_trouvee = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'contingent_inconnu';
  END IF;
  SELECT session_id INTO v_session FROM inscriptions WHERE id = p_inscription_id;
  SELECT session_id INTO v_c_session FROM contingents WHERE id = p_contingent_id;
  IF v_c_session <> v_session THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'contingent_hors_session';
  END IF;

  SELECT places_bloquees, places_confirmees INTO v_blo, v_conf
  FROM sessions WHERE id = v_session FOR UPDATE;
  CALL verrouiller_contingents(v_session);
  CALL classer_cle(p_cle, 'rapprochement', p_inscription_id, p_contingent_id, NULL, NULL, NULL, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;
  SELECT statut_administratif, contingent_id
    INTO v_statut, v_actuel
  FROM inscriptions WHERE id = p_inscription_id FOR UPDATE;

  IF v_actuel = p_contingent_id THEN
    COMMIT;
    SELECT 'deja_rapproche' AS resultat;
    LEAVE proc;
  END IF;
  IF v_actuel IS NOT NULL OR v_statut NOT IN ('place_bloquee', 'confirmee') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'etat_incompatible';
  END IF;
  SELECT reel_estime, realise INTO v_reel, v_realise
  FROM contingents WHERE id = p_contingent_id;

  IF v_statut = 'place_bloquee' AND v_blo < 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'incoherence_compteurs';
  END IF;
  IF v_statut = 'confirmee' AND v_conf < 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'incoherence_compteurs';
  END IF;

  UPDATE sessions
  SET places_bloquees = places_bloquees - IF(v_statut = 'place_bloquee', 1, 0),
      places_confirmees = places_confirmees - IF(v_statut = 'confirmee', 1, 0),
      modifie_le = UTC_TIMESTAMP(3)
  WHERE id = v_session;

  UPDATE inscriptions
  SET contingent_id = p_contingent_id, modifie_le = UTC_TIMESTAMP(3)
  WHERE id = p_inscription_id;

  UPDATE contingents
  SET realise = realise + 1, modifie_le = UTC_TIMESTAMP(3)
  WHERE id = p_contingent_id;
  SELECT places_bloquees INTO v_block FROM contingents WHERE id = p_contingent_id;
  INSERT INTO historique_contingents (
    id, contingent_id, champ, valeur_avant, valeur_apres, places_bloquees_apres,
    source, cle_idempotence, cree_le
  ) VALUES (
    UUID(), p_contingent_id, 'realise', v_realise, v_realise + 1, v_block,
    p_source, p_cle, UTC_TIMESTAMP(3)
  );
  INSERT INTO inscription_evenements (
    id, inscription_id, type, source, resume, cle_idempotence, cree_le
  ) VALUES (
    UUID(), p_inscription_id, 'synchro', p_source, 'rapprochement contingent', p_cle, UTC_TIMESTAMP(3)
  );

  CALL verifier_places(v_session);
  COMMIT;
  SELECT 'ok' AS resultat;
END //

CREATE PROCEDURE modifier_capacite(
  IN p_session_id CHAR(36),
  IN p_capacite INT,
  IN p_cle VARCHAR(128),
  IN p_source VARCHAR(32)
)
proc: BEGIN
  DECLARE v_cap INT;
  DECLARE v_blo INT;
  DECLARE v_conf INT;
  DECLARE v_sum INT;
  DECLARE v_occupees INT;
  DECLARE v_code VARCHAR(32);
  DECLARE v_errno INT;
  DECLARE v_msg TEXT;
  DECLARE v_n INT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_msg = MESSAGE_TEXT;
    ROLLBACK;
    IF v_errno = 1062 THEN
      CALL classer_cle(p_cle, 'capacite', NULL, NULL, NULL, p_session_id, p_capacite, v_code);
      IF v_code IN ('deja_applique', 'cle_deja_utilisee') THEN
        CALL sortir_cle(v_code);
      ELSE
        RESIGNAL;
      END IF;
    ELSE
      RESIGNAL;
    END IF;
  END;

  IF p_cle IS NULL OR CHAR_LENGTH(p_cle) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'cle_requise';
  END IF;
  IF p_source NOT IN ('site', 'filemaker', 'admin') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'source_inconnue';
  END IF;
  IF p_capacite IS NULL OR p_capacite < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'capacite_invalide';
  END IF;

  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  CALL classer_cle(p_cle, 'capacite', NULL, NULL, NULL, p_session_id, p_capacite, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;

  SELECT COUNT(*) INTO v_n FROM sessions WHERE id = p_session_id;
  IF v_n = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'session_inconnue';
  END IF;

  SELECT capacite, places_bloquees, places_confirmees
    INTO v_cap, v_blo, v_conf
  FROM sessions WHERE id = p_session_id FOR UPDATE;
  CALL verrouiller_contingents(p_session_id);
  CALL classer_cle(p_cle, 'capacite', NULL, NULL, NULL, p_session_id, p_capacite, v_code);
  CALL sortir_cle(v_code);
  IF v_code <> 'absente' THEN LEAVE proc; END IF;

  CALL verifier_places(p_session_id);

  SELECT COALESCE(SUM(places_bloquees), 0) INTO v_sum
  FROM contingents WHERE session_id = p_session_id;
  SET v_occupees = v_blo + v_conf + v_sum;

  IF p_capacite < v_occupees THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'capacite_insuffisante';
  END IF;
  IF p_capacite = v_cap THEN
    COMMIT;
    SELECT 'inchange' AS resultat;
    LEAVE proc;
  END IF;

  UPDATE sessions
  SET capacite = p_capacite, modifie_le = UTC_TIMESTAMP(3)
  WHERE id = p_session_id;

  INSERT INTO historique_capacites (
    id, session_id, capacite_avant, capacite_apres, places_occupees,
    source, cle_idempotence, cree_le
  ) VALUES (
    UUID(), p_session_id, v_cap, p_capacite, v_occupees,
    p_source, p_cle, UTC_TIMESTAMP(3)
  );

  CALL verifier_places(p_session_id);
  COMMIT;
  SELECT 'ok' AS resultat;
END //

DELIMITER ;
