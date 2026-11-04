#!/bin/bash
# Audit du moteur de places. Base fixe : thalie_test. Ne corrige aucune donnée.
set -u
DB=thalie_test
MARIA=(mariadb --protocol=socket "$DB")
fail=0
P=15b00000-0000-4000-8000

pass() { echo "PASS $1"; }
bad() { echo "FAIL $1"; fail=1; }
sql() { "${MARIA[@]}" -N -e "$1"; }

cleanup_probe() {
  "${MARIA[@]}" -e "DROP PROCEDURE IF EXISTS probe_rollback_audit" >/dev/null 2>&1 || true
}
trap cleanup_probe EXIT

assert_eq() {
  local name="$1" query="$2" expected="$3" got
  got=$(sql "$query")
  if [ "$got" = "$expected" ]; then pass "$name = $got"; else bad "$name attendu=$expected obtenu=$got"; fi
}

ecarts() {
  "${MARIA[@]}" -N -e "CALL constater_ecart_places('$1')" 2>/dev/null || true
}

courant=$(sql "SELECT DATABASE()")
if [ "$courant" != "$DB" ]; then
  echo "Base inattendue : $courant"
  exit 1
fi

echo "---- version et sécurité des procédures ----"
sql "SELECT VERSION()"
sql "SELECT routine_name, security_type FROM information_schema.routines WHERE routine_schema = DATABASE() ORDER BY routine_name"

photo_avant=$(sql "
SELECT CONCAT(
  (SELECT CONCAT(options_posees,'/',reel_estime,'/',realise,'/',places_bloquees) FROM contingents WHERE id='ffffffff-ffff-4fff-8fff-fffffffffff2'),
  '|',
  (SELECT CONCAT(places_bloquees,'/',places_confirmees,'/',places_liberees) FROM sessions WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'),
  '|',
  (SELECT statut_administratif FROM inscriptions WHERE id='12121212-1212-4121-8121-121212121214')
)")

echo "---- préparation des sessions d'audit ----"
sql "
DELETE FROM inscription_evenements WHERE inscription_id LIKE '${P}-%';
DELETE FROM suivi_places WHERE session_id LIKE '${P}-%';
DELETE FROM historique_contingents WHERE contingent_id LIKE '${P}-%';
DELETE FROM inscriptions WHERE id LIKE '${P}-%';
DELETE FROM contingents WHERE id LIKE '${P}-%';
DELETE FROM sessions WHERE id LIKE '${P}-%';
DELETE FROM commandes WHERE id LIKE '${P}-%';
DELETE FROM enfants WHERE id LIKE '${P}-%';
DELETE FROM adultes WHERE id LIKE '${P}-%';
DELETE FROM familles WHERE id LIKE '${P}-%';
DELETE FROM sejours WHERE id LIKE '${P}-%';
DELETE FROM centres WHERE id LIKE '${P}-%';
DELETE FROM segments_clients WHERE id LIKE '${P}-%';
INSERT INTO familles (id, responsable_administratif_id, cree_le, modifie_le) VALUES
  ('${P}-000000000001', NULL, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO adultes (id, famille_id, prenom, nom, cree_le, modifie_le) VALUES
  ('${P}-000000000002', '${P}-000000000001', 'Lio', 'Essai', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO enfants (id, famille_id, prenom, nom, naissance, naissance_incomplete, cree_le, modifie_le) VALUES
  ('${P}-000000000101', '${P}-000000000001', 'Audit', 'Un', '2016-02-01', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000102', '${P}-000000000001', 'Audit', 'Deux', '2016-02-02', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000103', '${P}-000000000001', 'Audit', 'Trois', '2016-02-03', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000104', '${P}-000000000001', 'Audit', 'Quatre', '2016-02-04', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000105', '${P}-000000000001', 'Audit', 'Cinq', '2016-02-05', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000106', '${P}-000000000001', 'Audit', 'Six', '2016-02-06', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000107', '${P}-000000000001', 'Audit', 'Sept', '2016-02-07', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000108', '${P}-000000000001', 'Audit', 'Huit', '2016-02-08', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO commandes (id, famille_id, adulte_id, statut, cree_le, modifie_le) VALUES
  ('${P}-000000000010', '${P}-000000000001', '${P}-000000000002', 'enregistree', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO centres (id, nom, slug, cree_le, modifie_le) VALUES
  ('${P}-000000000020', 'Centre Audit', 'centre-audit-15b', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO sejours (id, centre_id, titre, slug, publie, cree_le, modifie_le) VALUES
  ('${P}-000000000021', '${P}-000000000020', 'Sejour Audit', 'sejour-audit-15b', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO sessions (id, sejour_id, debut, fin, capacite, statut_commercial, cree_le, modifie_le) VALUES
  ('${P}-000000000031', '${P}-000000000021', '2026-07-01', '2026-07-07', 2, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000032', '${P}-000000000021', '2026-07-08', '2026-07-14', 10, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000033', '${P}-000000000021', '2026-07-15', '2026-07-21', 1, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000034', '${P}-000000000021', '2026-07-22', '2026-07-28', 1, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000035', '${P}-000000000021', '2026-08-01', '2026-08-07', 4, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000036', '${P}-000000000021', '2026-08-08', '2026-08-14', 4, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000037', '${P}-000000000021', '2026-08-15', '2026-08-21', 5, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000038', '${P}-000000000021', '2026-08-22', '2026-08-28', 6, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000039', '${P}-000000000021', '2026-09-01', '2026-09-07', 3, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO segments_clients (id, code, libelle, cree_le, modifie_le) VALUES
  ('${P}-000000000041', 'audit-cse', 'Audit CSE', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO contingents (id, session_id, segment_id, options_posees, reel_estime, realise, cree_le, modifie_le) VALUES
  ('${P}-000000000051', '${P}-000000000031', '${P}-000000000041', 0, 0, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000052', '${P}-000000000032', '${P}-000000000041', 0, 0, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000054', '${P}-000000000034', '${P}-000000000041', 0, 0, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
"

ARGS="'${P}-000000000010', '${P}-000000000001'"
SEJ="'${P}-000000000021'"

tenir() {
  local session="$1" out="$2"
  "${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; START TRANSACTION; SELECT id FROM sessions WHERE id = '${session}' FOR UPDATE; SELECT SLEEP(4); COMMIT;" >"$out" 2>"${out}.err" &
  echo $! >"${out}.pid"
}

attentes() {
  sql "SELECT COUNT(*) FROM information_schema.INNODB_LOCK_WAITS"
}

echo "---- réservation et hausse d'estimation sous le même verrou ----"
tenir "${P}-000000000031" /tmp/audit_lock_a.out
lock=$(cat /tmp/audit_lock_a.out.pid)
sleep 0.5
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL bloquer_place('${P}-000000000201', $ARGS, '${P}-000000000101', $SEJ, '${P}-000000000031', 'audit-book');" >/tmp/audit_book.out 2>/tmp/audit_book.err &
book=$!
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL ajuster_contingent('${P}-000000000051', 'reel_estime', 2, 'audit-hausse', 'admin');" >/tmp/audit_hausse.out 2>/tmp/audit_hausse.err &
hausse=$!
sleep 0.6
n=$(attentes)
if [ "$n" -ge 2 ]; then pass "réservation et hausse attendent le verrou ($n)"; else bad "attente de verrou insuffisante ($n)"; fi
wait "$lock" "$book" "$hausse" || true
book_ok=0; hausse_ok=0
grep -q '^ok$' /tmp/audit_book.out && book_ok=1
grep -q '^ok$' /tmp/audit_hausse.out && hausse_ok=1
if [ $((book_ok + hausse_ok)) -eq 1 ]; then pass "une seule des deux demandes est acceptée"; else bad "résultat book=$book_ok hausse=$hausse_ok"; echo "-- book --"; cat /tmp/audit_book.out /tmp/audit_book.err; echo "-- hausse --"; cat /tmp/audit_hausse.out /tmp/audit_hausse.err; fi
tenu=$(sql "SELECT places_bloquees + places_confirmees + (SELECT places_bloquees FROM contingents WHERE id='${P}-000000000051') FROM sessions WHERE id='${P}-000000000031'")
if [ "$tenu" -le 2 ]; then pass "places tenues $tenu sur une capacité de 2"; else bad "places tenues $tenu"; fi
if [ -z "$(ecarts "${P}-000000000031")" ]; then pass "aucun écart après la course réservation/hausse"; else bad "écart après la course"; ecarts "${P}-000000000031"; fi

echo "---- deux estimations concurrentes du même contingent ----"
tenir "${P}-000000000032" /tmp/audit_lock_b.out
lock=$(cat /tmp/audit_lock_b.out.pid)
sleep 0.5
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL ajuster_contingent('${P}-000000000052', 'reel_estime', 6, 'audit-reel-6', 'admin');" >/tmp/audit_r6.out 2>/tmp/audit_r6.err &
p6=$!
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL ajuster_contingent('${P}-000000000052', 'reel_estime', 7, 'audit-reel-7', 'admin');" >/tmp/audit_r7.out 2>/tmp/audit_r7.err &
p7=$!
sleep 0.6
n=$(attentes)
if [ "$n" -ge 2 ]; then pass "les deux estimations attendent ($n)"; else bad "attente des estimations insuffisante ($n)"; fi
wait "$lock" "$p6" "$p7" || true
reel=$(sql "SELECT reel_estime FROM contingents WHERE id='${P}-000000000052'")
if [ "$reel" = "6" ] || [ "$reel" = "7" ]; then pass "le réel estimé final est $reel, pas la somme"; else bad "réel estimé inattendu $reel"; fi
if [ -z "$(ecarts "${P}-000000000032")" ]; then pass "aucun écart après les deux estimations"; else bad "écart après les estimations"; fi

echo "---- deux inscriptions FileMaker sur la dernière place du contingent ----"
tenir "${P}-000000000034" /tmp/audit_lock_c.out
lock=$(cat /tmp/audit_lock_c.out.pid)
sleep 0.5
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL inscrire_contingent('${P}-000000000211', $ARGS, '${P}-000000000103', $SEJ, '${P}-000000000034', '${P}-000000000054', 'audit-fm-1', 'filemaker');" >/tmp/audit_fm1.out 2>/tmp/audit_fm1.err &
f1=$!
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL inscrire_contingent('${P}-000000000212', $ARGS, '${P}-000000000104', $SEJ, '${P}-000000000034', '${P}-000000000054', 'audit-fm-2', 'filemaker');" >/tmp/audit_fm2.out 2>/tmp/audit_fm2.err &
f2=$!
sleep 0.6
n=$(attentes)
if [ "$n" -ge 2 ]; then pass "les deux inscriptions FileMaker attendent ($n)"; else bad "attente FileMaker insuffisante ($n)"; fi
wait "$lock" "$f1" "$f2" || true
fm=0
grep -q '^ok$' /tmp/audit_fm1.out && fm=$((fm + 1))
grep -q '^ok$' /tmp/audit_fm2.out && fm=$((fm + 1))
if [ "$fm" -eq 1 ]; then pass "une seule inscription FileMaker sur la dernière place"; else bad "inscriptions FileMaker acceptées : $fm"; cat /tmp/audit_fm1.out /tmp/audit_fm1.err /tmp/audit_fm2.out /tmp/audit_fm2.err; fi
assert_eq "réalisé après la course FileMaker" "SELECT realise FROM contingents WHERE id='${P}-000000000054'" "1"

echo "---- confirmation et annulation concurrentes ----"
sql "CALL bloquer_place('${P}-000000000221', $ARGS, '${P}-000000000105', $SEJ, '${P}-000000000033', 'audit-avant-course')" >/dev/null
tenir "${P}-000000000033" /tmp/audit_lock_d.out
lock=$(cat /tmp/audit_lock_d.out.pid)
sleep 0.5
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL confirmer_inscription('${P}-000000000221', 'audit-confirm');" >/tmp/audit_conf.out 2>/tmp/audit_conf.err &
cpid=$!
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL annuler_inscription('${P}-000000000221', 'audit-annul', 'site');" >/tmp/audit_ann.out 2>/tmp/audit_ann.err &
apid=$!
sleep 0.6
n=$(attentes)
if [ "$n" -ge 2 ]; then pass "confirmation et annulation attendent ($n)"; else bad "attente confirmation/annulation insuffisante ($n)"; fi
wait "$lock" "$cpid" "$apid" || true
statut=$(sql "SELECT statut_administratif FROM inscriptions WHERE id='${P}-000000000221'")
compteurs=$(sql "SELECT CONCAT(places_bloquees,'/',places_confirmees,'/',places_liberees) FROM sessions WHERE id='${P}-000000000033'")
if [ "$statut" = "annulee" ] && [ "$compteurs" = "0/0/1" ]; then
  pass "l'inscription finit annulée et les compteurs sont 0/0/1"
else
  bad "état final statut=$statut compteurs=$compteurs"
  echo "-- confirmation --"; cat /tmp/audit_conf.out /tmp/audit_conf.err
  echo "-- annulation --"; cat /tmp/audit_ann.out /tmp/audit_ann.err
fi
if [ -z "$(ecarts "${P}-000000000033")" ]; then pass "aucun écart après confirmation/annulation"; else bad "écart après confirmation/annulation"; ecarts "${P}-000000000033"; fi

echo "---- transfert : le moteur actuel refuse, l'essai direct est annulé ----"
sql "CALL bloquer_place('${P}-000000000231', $ARGS, '${P}-000000000106', $SEJ, '${P}-000000000035', 'audit-origine')" >/dev/null
if "${MARIA[@]}" -e "CALL bloquer_place('${P}-000000000231', $ARGS, '${P}-000000000106', $SEJ, '${P}-000000000036', 'audit-transfert');" >/tmp/audit_tr.out 2>/tmp/audit_tr.err; then
  bad "le déplacement vers une autre session aurait dû être refusé"
else
  grep -q etat_incompatible /tmp/audit_tr.err && pass "aucune procédure ne déplace une inscription" || { bad "refus inattendu"; cat /tmp/audit_tr.err; }
fi
assert_eq "l'inscription reste sur la session d'origine" "SELECT session_id FROM inscriptions WHERE id='${P}-000000000231'" "${P}-000000000035"
avant_tr=$(sql "SELECT CONCAT(places_bloquees,'/',places_confirmees) FROM sessions WHERE id='${P}-000000000035'")
"${MARIA[@]}" -N -e "
START TRANSACTION;
UPDATE inscriptions SET session_id = '${P}-000000000036' WHERE id = '${P}-000000000231';
CALL constater_ecart_places('${P}-000000000035');
CALL constater_ecart_places('${P}-000000000036');
ROLLBACK;
" > /tmp/audit_tr_ecart.out
if grep -q places_bloquees /tmp/audit_tr_ecart.out; then
  pass "un changement direct de session crée un écart, puis la transaction est annulée"
else
  bad "l'écart de transfert n'a pas été vu"
  cat /tmp/audit_tr_ecart.out
fi
assert_eq "session d'origine après annulation" "SELECT session_id FROM inscriptions WHERE id='${P}-000000000231'" "${P}-000000000035"
assert_eq "compteurs d'origine restaurés" "SELECT CONCAT(places_bloquees,'/',places_confirmees) FROM sessions WHERE id='${P}-000000000035'" "$avant_tr"
if [ -z "$(ecarts "${P}-000000000035")" ] && [ -z "$(ecarts "${P}-000000000036")" ]; then
  pass "les deux sessions sont cohérentes après l'annulation"
else
  bad "un écart de transfert a été conservé"
fi

echo "---- échec au milieu d'une transaction ----"
"${MARIA[@]}" <<'SQL'
DROP PROCEDURE IF EXISTS probe_rollback_audit;
DELIMITER //
CREATE PROCEDURE probe_rollback_audit(IN p_session_id CHAR(36))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;
  START TRANSACTION;
  UPDATE sessions
  SET places_bloquees = places_bloquees + 1
  WHERE id = p_session_id;
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'echec_volontaire';
END //
DELIMITER ;
SQL
avant=$(sql "SELECT places_bloquees FROM sessions WHERE id='${P}-000000000037'")
if "${MARIA[@]}" -e "CALL probe_rollback_audit('${P}-000000000037')" >/tmp/audit_probe.out 2>/tmp/audit_probe.err; then
  bad "la sonde aurait dû échouer"
else
  grep -q echec_volontaire /tmp/audit_probe.err && pass "l'échec volontaire est signalé" || { bad "message de sonde inattendu"; cat /tmp/audit_probe.err; }
fi
assert_eq "compteur inchangé après l'échec" "SELECT places_bloquees FROM sessions WHERE id='${P}-000000000037'" "$avant"

"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL bloquer_place('${P}-000000000241', $ARGS, '${P}-000000000107', $SEJ, '${P}-000000000037', 'audit-meme-cle');" >/tmp/audit_k1.out 2>/tmp/audit_k1.err &
k1=$!
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL bloquer_place('${P}-000000000242', $ARGS, '${P}-000000000108', $SEJ, '${P}-000000000037', 'audit-meme-cle');" >/tmp/audit_k2.out 2>/tmp/audit_k2.err &
k2=$!
wait "$k1" "$k2" || true
actifs=$(sql "SELECT COUNT(*) FROM inscriptions WHERE session_id='${P}-000000000037' AND statut_administratif IN ('place_bloquee','confirmee')")
if [ "$actifs" = "1" ]; then pass "la clé répétée ne laisse qu'une inscription"; else bad "inscriptions actives après la clé répétée : $actifs"; cat /tmp/audit_k1.out /tmp/audit_k1.err /tmp/audit_k2.out /tmp/audit_k2.err; fi
assert_eq "compteur égal à l'inscription conservée" "SELECT places_bloquees FROM sessions WHERE id='${P}-000000000037'" "1"

echo "---- interruption d'un verrou ----"
"${MARIA[@]}" -N -e "START TRANSACTION; SELECT id FROM sessions WHERE id='${P}-000000000039' FOR UPDATE; SELECT SLEEP(20); COMMIT;" >/tmp/audit_sleep.out 2>/tmp/audit_sleep.err &
sleep_pid=$!
sleep 0.5
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL bloquer_place('${P}-000000000251', $ARGS, '${P}-000000000102', $SEJ, '${P}-000000000039', 'audit-apres-coupure');" >/tmp/audit_apres.out 2>/tmp/audit_apres.err &
apres=$!
sleep 0.6
n=$(attentes)
if [ "$n" -ge 1 ]; then pass "la réservation attend le verrou tenu ($n)"; else bad "la réservation n'attendait pas ($n)"; fi
kill "$sleep_pid" 2>/dev/null || true
wait "$sleep_pid" || true
wait "$apres" || true
grep -q '^ok$' /tmp/audit_apres.out && pass "la coupure libère le verrou et la réservation aboutit" || { bad "la réservation n'a pas abouti après la coupure"; cat /tmp/audit_apres.out /tmp/audit_apres.err; }

echo "---- historique inactif, import actif, constat sans correction ----"
sql "
INSERT INTO inscriptions (
  id, commande_id, famille_id, enfant_id, sejour_id, session_id,
  statut_administratif, statut_financier, statut_documentaire, cree_le, modifie_le
) VALUES
  ('${P}-000000000261', '${P}-000000000010', '${P}-000000000001', '${P}-000000000101', $SEJ, '${P}-000000000038', 'annulee', 'aucun', 'manquant', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000262', '${P}-000000000010', '${P}-000000000001', '${P}-000000000103', $SEJ, '${P}-000000000038', 'refusee', 'aucun', 'manquant', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000263', '${P}-000000000010', '${P}-000000000001', '${P}-000000000104', $SEJ, '${P}-000000000038', 'transferee', 'aucun', 'manquant', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
"
if [ -z "$(ecarts "${P}-000000000038")" ]; then pass "annulé, refusé et transféré ne créent pas d'écart"; else bad "écart sur des statuts inactifs"; ecarts "${P}-000000000038"; fi
assert_eq "disponibilité intacte avec l'historique inactif" "SELECT capacite - places_bloquees - places_confirmees FROM sessions WHERE id='${P}-000000000038'" "6"
sql "
INSERT INTO inscriptions (
  id, commande_id, famille_id, enfant_id, sejour_id, session_id,
  statut_administratif, statut_financier, statut_documentaire, cree_le, modifie_le
) VALUES (
  '${P}-000000000264', '${P}-000000000010', '${P}-000000000001', '${P}-000000000108', $SEJ, '${P}-000000000038',
  'place_bloquee', 'aucun', 'manquant', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)
);
"
ecart_import=$(ecarts "${P}-000000000038")
echo "$ecart_import" | grep -q "places_bloquees" && pass "l'import actif est détecté" || { bad "l'import actif n'est pas détecté"; echo "$ecart_import"; }
if "${MARIA[@]}" -e "CALL bloquer_place('${P}-000000000265', $ARGS, '${P}-000000000107', $SEJ, '${P}-000000000038', 'audit-sur-ecart');" >/tmp/audit_ecart.out 2>/tmp/audit_ecart.err; then
  bad "une réservation sur un compteur faux aurait dû échouer"
else
  grep -q incoherence_compteurs /tmp/audit_ecart.err && pass "le moteur refuse d'écrire tant que le compteur est faux" || { bad "refus inattendu"; cat /tmp/audit_ecart.err; }
fi
assert_eq "le constat ne réécrit pas le compteur" "SELECT places_bloquees FROM sessions WHERE id='${P}-000000000038'" "0"
assert_eq "l'import actif est toujours là" "SELECT COUNT(*) FROM inscriptions WHERE session_id='${P}-000000000038' AND statut_administratif='place_bloquee'" "1"
assert_eq "aucune inscription supplémentaire" "SELECT COUNT(*) FROM inscriptions WHERE id='${P}-000000000265'" "0"

echo "---- le jeu 1.4C est seulement lu ----"
ecart_ancien=$(ecarts "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3")
echo "$ecart_ancien" | grep -q "places_bloquees" && echo "$ecart_ancien" | grep -q "realise" && pass "les écarts historiques sont visibles" || { bad "les écarts historiques ne sont pas tous visibles"; echo "$ecart_ancien"; }
photo_apres=$(sql "
SELECT CONCAT(
  (SELECT CONCAT(options_posees,'/',reel_estime,'/',realise,'/',places_bloquees) FROM contingents WHERE id='ffffffff-ffff-4fff-8fff-fffffffffff2'),
  '|',
  (SELECT CONCAT(places_bloquees,'/',places_confirmees,'/',places_liberees) FROM sessions WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'),
  '|',
  (SELECT statut_administratif FROM inscriptions WHERE id='12121212-1212-4121-8121-121212121214')
)")
if [ "$photo_avant" = "$photo_apres" ]; then pass "données 1.4C inchangées ($photo_apres)"; else bad "données 1.4C modifiées : $photo_avant -> $photo_apres"; fi

if [ "$fail" -eq 0 ]; then echo "BILAN audit ok"; else echo "BILAN audit echec"; exit 1; fi
