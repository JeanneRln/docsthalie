#!/bin/bash
# Tests du moteur de places. Base fixe : thalie_test. Ne touche à aucune autre base.
set -u
DB=thalie_test
MARIA=(mariadb --protocol=socket "$DB")
fail=0

pass() { echo "PASS $1"; }
bad() { echo "FAIL $1"; fail=1; }

sql() { "${MARIA[@]}" -N -e "$1"; }

assert_eq() {
  local name="$1" query="$2" expected="$3" got
  got=$(sql "$query")
  if [ "$got" = "$expected" ]; then pass "$name = $got"; else bad "$name attendu=$expected obtenu=$got"; fi
}

call_ok() {
  local name="$1" stmt="$2" expected="$3" got
  got=$("${MARIA[@]}" -N -e "$stmt" 2>/tmp/thalie_cap.err) || { bad "$name erreur SQL"; cat /tmp/thalie_cap.err; return; }
  got=$(printf '%s\n' "$got" | tail -n 1)
  if [ "$got" = "$expected" ]; then pass "$name -> $got"; else bad "$name attendu=$expected obtenu=$got"; fi
}

call_fail() {
  local name="$1" stmt="$2" needle="$3"
  if "${MARIA[@]}" -e "$stmt" >/tmp/thalie_cap.out 2>/tmp/thalie_cap.err; then
    bad "$name aurait dû échouer"
  elif grep -q "$needle" /tmp/thalie_cap.err; then
    pass "$name refuse ($needle)"
  else
    bad "$name mauvais message"
    cat /tmp/thalie_cap.err
  fi
}

courant=$(sql "SELECT DATABASE()")
if [ "$courant" != "$DB" ]; then
  echo "Base inattendue : $courant"
  exit 1
fi

echo "---- préparation fictive, sans modifier le jeu 1.4C ----"
sql "
DELETE FROM inscription_evenements WHERE inscription_id LIKE '15000000-0000-4000-8000-%';
DELETE FROM suivi_places WHERE session_id LIKE '15000000-0000-4000-8000-%';
DELETE FROM historique_contingents WHERE contingent_id LIKE '15000000-0000-4000-8000-%';
DELETE FROM inscriptions WHERE id LIKE '15000000-0000-4000-8000-%';
DELETE FROM contingents WHERE id LIKE '15000000-0000-4000-8000-%';
DELETE FROM sessions WHERE id LIKE '15000000-0000-4000-8000-%';
DELETE FROM commandes WHERE id LIKE '15000000-0000-4000-8000-%';
DELETE FROM enfants WHERE id LIKE '15000000-0000-4000-8000-%';
DELETE FROM adultes WHERE id LIKE '15000000-0000-4000-8000-%';
DELETE FROM familles WHERE id LIKE '15000000-0000-4000-8000-%';
DELETE FROM sejours WHERE id LIKE '15000000-0000-4000-8000-%';
DELETE FROM centres WHERE id LIKE '15000000-0000-4000-8000-%';
DELETE FROM segments_clients WHERE id LIKE '15000000-0000-4000-8000-%';
"
sql "
INSERT INTO familles (id, responsable_administratif_id, cree_le, modifie_le) VALUES
  ('15000000-0000-4000-8000-000000000001', NULL, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO adultes (id, famille_id, prenom, nom, cree_le, modifie_le) VALUES
  ('15000000-0000-4000-8000-000000000002', '15000000-0000-4000-8000-000000000001', 'Noa', 'Essai', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO enfants (id, famille_id, prenom, nom, naissance, naissance_incomplete, cree_le, modifie_le) VALUES
  ('15000000-0000-4000-8000-000000000101', '15000000-0000-4000-8000-000000000001', 'Enfant', 'Un', '2016-01-01', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000102', '15000000-0000-4000-8000-000000000001', 'Enfant', 'Deux', '2016-01-02', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000103', '15000000-0000-4000-8000-000000000001', 'Enfant', 'Trois', '2016-01-03', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000104', '15000000-0000-4000-8000-000000000001', 'Enfant', 'Quatre', '2016-01-04', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000105', '15000000-0000-4000-8000-000000000001', 'Enfant', 'Cinq', '2016-01-05', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000106', '15000000-0000-4000-8000-000000000001', 'Enfant', 'Six', '2016-01-06', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000107', '15000000-0000-4000-8000-000000000001', 'Enfant', 'Sept', '2016-01-07', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000108', '15000000-0000-4000-8000-000000000001', 'Enfant', 'Huit', '2016-01-08', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO commandes (id, famille_id, adulte_id, statut, cree_le, modifie_le) VALUES
  ('15000000-0000-4000-8000-000000000010', '15000000-0000-4000-8000-000000000001', '15000000-0000-4000-8000-000000000002', 'enregistree', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO centres (id, nom, slug, cree_le, modifie_le) VALUES
  ('15000000-0000-4000-8000-000000000020', 'Centre Laboratoire', 'centre-laboratoire', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO sejours (id, centre_id, titre, slug, publie, cree_le, modifie_le) VALUES
  ('15000000-0000-4000-8000-000000000021', '15000000-0000-4000-8000-000000000020', 'Sejour Laboratoire', 'sejour-laboratoire', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO sessions (id, sejour_id, debut, fin, capacite, statut_commercial, cree_le, modifie_le) VALUES
  ('15000000-0000-4000-8000-000000000031', '15000000-0000-4000-8000-000000000021', '2026-07-01', '2026-07-07', 1, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000032', '15000000-0000-4000-8000-000000000021', '2026-08-01', '2026-08-07', 30, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000033', '15000000-0000-4000-8000-000000000021', '2026-09-01', '2026-09-07', 30, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000034', '15000000-0000-4000-8000-000000000021', '2026-10-01', '2026-10-07', 10, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO segments_clients (id, code, libelle, cree_le, modifie_le) VALUES
  ('15000000-0000-4000-8000-000000000041', 'lab-cse-a', 'Laboratoire A', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000042', 'lab-cse-b', 'Laboratoire B', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000043', 'lab-cse-c', 'Laboratoire C', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO contingents (id, session_id, segment_id, options_posees, reel_estime, realise, cree_le, modifie_le) VALUES
  ('15000000-0000-4000-8000-000000000051', '15000000-0000-4000-8000-000000000032', '15000000-0000-4000-8000-000000000041', 12, 7, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000052', '15000000-0000-4000-8000-000000000033', '15000000-0000-4000-8000-000000000041', 0, 7, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000053', '15000000-0000-4000-8000-000000000033', '15000000-0000-4000-8000-000000000042', 0, 4, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('15000000-0000-4000-8000-000000000054', '15000000-0000-4000-8000-000000000034', '15000000-0000-4000-8000-000000000043', 0, 0, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
"

B='CALL bloquer_place'
C='CALL confirmer_inscription'
A='CALL annuler_inscription'
base_args="'15000000-0000-4000-8000-000000000010', '15000000-0000-4000-8000-000000000001'"

echo "---- 1. dernière place, deux réservations simultanées ----"
"${MARIA[@]}" -N -e "$B('15000000-0000-4000-8000-000000000201', $base_args, '15000000-0000-4000-8000-000000000101', '15000000-0000-4000-8000-000000000021', '15000000-0000-4000-8000-000000000031', 'course-a');" > /tmp/course_a.out 2>/tmp/course_a.err &
"${MARIA[@]}" -N -e "$B('15000000-0000-4000-8000-000000000202', $base_args, '15000000-0000-4000-8000-000000000102', '15000000-0000-4000-8000-000000000021', '15000000-0000-4000-8000-000000000031', 'course-b');" > /tmp/course_b.out 2>/tmp/course_b.err &
wait
ok_count=0
fail_count=0
if grep -q '^ok$' /tmp/course_a.out; then ok_count=$((ok_count + 1)); else fail_count=$((fail_count + 1)); fi
if grep -q '^ok$' /tmp/course_b.out; then ok_count=$((ok_count + 1)); else fail_count=$((fail_count + 1)); fi
if [ "$ok_count" = 1 ] && [ "$fail_count" = 1 ] && { grep -q capacite_insuffisante /tmp/course_a.err /tmp/course_b.err; }; then
  pass "une seule des deux courses prend la place"
else
  bad "course simultanée ok=$ok_count"
  echo "-- A --"; cat /tmp/course_a.out /tmp/course_a.err
  echo "-- B --"; cat /tmp/course_b.out /tmp/course_b.err
fi
assert_eq "places bloquées après la course" "SELECT places_bloquees + places_confirmees FROM sessions WHERE id='15000000-0000-4000-8000-000000000031'" "1"

gagnant=$(sql "SELECT id FROM inscriptions WHERE session_id='15000000-0000-4000-8000-000000000031' AND statut_administratif='place_bloquee'")
enfant=$(sql "SELECT enfant_id FROM inscriptions WHERE id='$gagnant'")

echo "---- répétition d'un blocage avec une nouvelle clé ----"
call_ok "blocage déjà actif" "$B('$gagnant', $base_args, '$enfant', '15000000-0000-4000-8000-000000000021', '15000000-0000-4000-8000-000000000031', 'course-nouvelle-cle')" "deja_actif"
assert_eq "le compteur n'a pas augmenté" "SELECT places_bloquees FROM sessions WHERE id='15000000-0000-4000-8000-000000000031'" "1"

echo "---- 2. confirmation sans deuxième place ----"
call_ok "confirmation" "$C('$gagnant', 'confirm-1')" "ok"
assert_eq "bloquées après confirmation" "SELECT places_bloquees FROM sessions WHERE id='15000000-0000-4000-8000-000000000031'" "0"
assert_eq "confirmées après confirmation" "SELECT places_confirmees FROM sessions WHERE id='15000000-0000-4000-8000-000000000031'" "1"
call_ok "confirmation répétée, nouvelle clé" "$C('$gagnant', 'confirm-2')" "deja_confirme"
assert_eq "total tenu inchangé" "SELECT places_bloquees + places_confirmees FROM sessions WHERE id='15000000-0000-4000-8000-000000000031'" "1"

echo "---- 3. annulation répétée ----"
call_ok "annulation" "$A('$gagnant', 'annul-1', 'site')" "ok"
assert_eq "place libérée" "SELECT places_confirmees FROM sessions WHERE id='15000000-0000-4000-8000-000000000031'" "0"
assert_eq "libérées cumulées" "SELECT places_liberees FROM sessions WHERE id='15000000-0000-4000-8000-000000000031'" "1"
call_ok "annulation répétée, nouvelle clé" "$A('$gagnant', 'annul-2', 'site')" "deja_inactif"
assert_eq "pas de seconde libération" "SELECT places_liberees FROM sessions WHERE id='15000000-0000-4000-8000-000000000031'" "1"
assert_eq "disponibilité revenue à 1" "SELECT capacite - places_bloquees - places_confirmees FROM sessions WHERE id='15000000-0000-4000-8000-000000000031'" "1"

echo "---- 4. nouvelle inscription après annulation ----"
call_ok "nouvelle inscription" "$B('15000000-0000-4000-8000-000000000203', $base_args, '$enfant', '15000000-0000-4000-8000-000000000021', '15000000-0000-4000-8000-000000000031', 'retour-1')" "ok"
assert_eq "une seule active" "SELECT COUNT(*) FROM inscriptions WHERE session_id='15000000-0000-4000-8000-000000000031' AND statut_administratif IN ('place_bloquee','confirmee')" "1"
assert_eq "l'ancienne reste annulée" "SELECT statut_administratif FROM inscriptions WHERE id='$gagnant'" "annulee"
assert_eq "capacité de 1 respectée" "SELECT capacite - places_bloquees - places_confirmees FROM sessions WHERE id='15000000-0000-4000-8000-000000000031'" "0"

echo "---- 5 à 7. contingents, exemple 30 / 12 / 7 / 5 ----"
for n in 1 2 3 4 5; do
  id=$(printf "15000000-0000-4000-8000-00000000021%d" "$n")
  enfant=$(printf "15000000-0000-4000-8000-00000000010%d" "$n")
  call_ok "inscrit contingent $n" "CALL inscrire_contingent('$id', $base_args, '$enfant', '15000000-0000-4000-8000-000000000021', '15000000-0000-4000-8000-000000000032', '15000000-0000-4000-8000-000000000051', 'cse-$n', 'site')" "ok"
done
assert_eq "exemple réalisé" "SELECT realise FROM contingents WHERE id='15000000-0000-4000-8000-000000000051'" "5"
assert_eq "exemple bloqué CSE" "SELECT places_bloquees FROM contingents WHERE id='15000000-0000-4000-8000-000000000051'" "7"
assert_eq "exemple hors contingent vide" "SELECT places_bloquees + places_confirmees FROM sessions WHERE id='15000000-0000-4000-8000-000000000032'" "0"
assert_eq "exemple disponible" "SELECT capacite - places_bloquees - places_confirmees - (SELECT COALESCE(SUM(places_bloquees),0) FROM contingents WHERE session_id='15000000-0000-4000-8000-000000000032') FROM sessions WHERE id='15000000-0000-4000-8000-000000000032'" "23"

call_fail "hausse impossible" "CALL ajuster_contingent('15000000-0000-4000-8000-000000000051', 'reel_estime', 31, 'hausse-impossible', 'admin')" "capacite_insuffisante"
assert_eq "réel estimé inchangé après refus" "SELECT reel_estime FROM contingents WHERE id='15000000-0000-4000-8000-000000000051'" "7"

call_ok "baisse du réel estimé" "CALL ajuster_contingent('15000000-0000-4000-8000-000000000051', 'reel_estime', 4, 'baisse-4', 'admin')" "ok"
assert_eq "blocage plancher au réalisé" "SELECT places_bloquees FROM contingents WHERE id='15000000-0000-4000-8000-000000000051'" "5"
assert_eq "places libérées par la baisse" "SELECT capacite - places_bloquees - places_confirmees - (SELECT COALESCE(SUM(places_bloquees),0) FROM contingents WHERE session_id='15000000-0000-4000-8000-000000000032') FROM sessions WHERE id='15000000-0000-4000-8000-000000000032'" "25"

call_ok "options sans effet sur les places" "CALL ajuster_contingent('15000000-0000-4000-8000-000000000051', 'options_posees', 99, 'options-99', 'admin')" "ok"
assert_eq "disponibilité après options" "SELECT capacite - places_bloquees - places_confirmees - (SELECT COALESCE(SUM(places_bloquees),0) FROM contingents WHERE session_id='15000000-0000-4000-8000-000000000032') FROM sessions WHERE id='15000000-0000-4000-8000-000000000032'" "25"

echo "---- deux contingents sur une session ----"
assert_eq "deux blocages additionnés" "SELECT SUM(places_bloquees) FROM contingents WHERE session_id='15000000-0000-4000-8000-000000000033'" "11"
assert_eq "disponible avec deux CSE" "SELECT capacite - places_bloquees - places_confirmees - (SELECT SUM(places_bloquees) FROM contingents WHERE session_id='15000000-0000-4000-8000-000000000033') FROM sessions WHERE id='15000000-0000-4000-8000-000000000033'" "19"
call_ok "inscription dans le premier CSE" "CALL inscrire_contingent('15000000-0000-4000-8000-000000000221', $base_args, '15000000-0000-4000-8000-000000000106', '15000000-0000-4000-8000-000000000021', '15000000-0000-4000-8000-000000000033', '15000000-0000-4000-8000-000000000052', 'cse-deux-a', 'site')" "ok"
assert_eq "le second contingent ne bouge pas" "SELECT places_bloquees FROM contingents WHERE id='15000000-0000-4000-8000-000000000053'" "4"
assert_eq "disponible inchangé dans l'estimation" "SELECT capacite - places_bloquees - places_confirmees - (SELECT SUM(places_bloquees) FROM contingents WHERE session_id='15000000-0000-4000-8000-000000000033') FROM sessions WHERE id='15000000-0000-4000-8000-000000000033'" "19"
call_ok "confirmation dans le contingent" "CALL confirmer_inscription('15000000-0000-4000-8000-000000000221', 'cse-confirm')" "ok"
assert_eq "réalisé inchangé par la confirmation" "SELECT realise FROM contingents WHERE id='15000000-0000-4000-8000-000000000052'" "1"
call_ok "confirmation contingent répétée, nouvelle clé" "CALL confirmer_inscription('15000000-0000-4000-8000-000000000221', 'cse-confirm-2')" "deja_confirme"
call_ok "annulation dans l'estimation" "CALL annuler_inscription('15000000-0000-4000-8000-000000000221', 'cse-annul', 'site')" "ok"
assert_eq "réalisé décrémenté" "SELECT realise FROM contingents WHERE id='15000000-0000-4000-8000-000000000052'" "0"
assert_eq "blocage CSE inchangé" "SELECT places_bloquees FROM contingents WHERE id='15000000-0000-4000-8000-000000000052'" "7"
assert_eq "aucune place publique rendue" "SELECT capacite - places_bloquees - places_confirmees - (SELECT SUM(places_bloquees) FROM contingents WHERE session_id='15000000-0000-4000-8000-000000000033') FROM sessions WHERE id='15000000-0000-4000-8000-000000000033'" "19"
call_ok "annulation contingent répétée, nouvelle clé" "CALL annuler_inscription('15000000-0000-4000-8000-000000000221', 'cse-annul-2', 'site')" "deja_inactif"

echo "---- 8 et 9. rapprochement FileMaker puis répétition ----"
call_ok "réservation hors contingent" "$B('15000000-0000-4000-8000-000000000231', $base_args, '15000000-0000-4000-8000-000000000107', '15000000-0000-4000-8000-000000000021', '15000000-0000-4000-8000-000000000034', 'fm-hors')" "ok"
avant=$(sql "SELECT capacite - places_bloquees - places_confirmees - (SELECT COALESCE(SUM(places_bloquees),0) FROM contingents WHERE session_id='15000000-0000-4000-8000-000000000034') FROM sessions WHERE id='15000000-0000-4000-8000-000000000034'")
call_ok "rapprochement" "CALL rapprocher_contingent('15000000-0000-4000-8000-000000000231', '15000000-0000-4000-8000-000000000054', 'fm-match', 'filemaker')" "ok"
assert_eq "plus de place hors contingent" "SELECT places_bloquees + places_confirmees FROM sessions WHERE id='15000000-0000-4000-8000-000000000034'" "0"
assert_eq "réalisé du partenaire" "SELECT realise FROM contingents WHERE id='15000000-0000-4000-8000-000000000054'" "1"
assert_eq "blocage égal au réalisé" "SELECT places_bloquees FROM contingents WHERE id='15000000-0000-4000-8000-000000000054'" "1"
apres=$(sql "SELECT capacite - places_bloquees - places_confirmees - (SELECT COALESCE(SUM(places_bloquees),0) FROM contingents WHERE session_id='15000000-0000-4000-8000-000000000034') FROM sessions WHERE id='15000000-0000-4000-8000-000000000034'")
if [ "$avant" = "$apres" ]; then pass "disponibilité inchangée ($avant), pas de double compte"; else bad "disponibilité $avant -> $apres"; fi
call_ok "même clé de synchro" "CALL rapprocher_contingent('15000000-0000-4000-8000-000000000231', '15000000-0000-4000-8000-000000000054', 'fm-match', 'filemaker')" "deja_applique"
call_ok "nouvelle clé, état déjà rapproché" "CALL rapprocher_contingent('15000000-0000-4000-8000-000000000231', '15000000-0000-4000-8000-000000000054', 'fm-match-bis', 'filemaker')" "deja_rapproche"
assert_eq "réalisé non doublé" "SELECT realise FROM contingents WHERE id='15000000-0000-4000-8000-000000000054'" "1"

echo "---- 10. capacité jamais dépassée sur les sessions du laboratoire ----"
neg=$(sql "SELECT COUNT(*) FROM sessions WHERE id LIKE '15000000-0000-4000-8000-00000000003%' AND capacite - places_bloquees - places_confirmees - (SELECT COALESCE(SUM(places_bloquees),0) FROM contingents c WHERE c.session_id = sessions.id) < 0")
if [ "$neg" = 0 ]; then pass "aucune disponibilité négative"; else bad "disponibilités négatives : $neg"; fi

echo "---- le jeu fictif 1.4C est inchangé ----"
assert_eq "ancien contingent" "SELECT CONCAT(options_posees,'/',reel_estime,'/',realise,'/',places_bloquees) FROM contingents WHERE id='ffffffff-ffff-4fff-8fff-fffffffffff2'" "12/7/5/7"
assert_eq "anciens compteurs de session" "SELECT CONCAT(places_bloquees,'/',places_confirmees,'/',places_liberees) FROM sessions WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'" "0/0/0"
assert_eq "ancienne inscription active" "SELECT statut_administratif FROM inscriptions WHERE id='12121212-1212-4121-8121-121212121214'" "place_bloquee"

if [ "$fail" -eq 0 ]; then echo "BILAN ok"; else echo "BILAN echec"; exit 1; fi
