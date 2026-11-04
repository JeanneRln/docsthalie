#!/bin/bash
# Modification de capacité. Base fixe : thalie_test.
# Ne supprime pas les jeux 1.4C, 1.5, 1.5B ni 1.5C.
set -u
DB=thalie_test
MARIA=(mariadb --protocol=socket "$DB")
fail=0
P=15d00000-0000-4000-8000

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
  got=$("${MARIA[@]}" -N -e "$stmt" 2>/tmp/thalie_15d.err) || { bad "$name erreur SQL"; cat /tmp/thalie_15d.err; return; }
  got=$(printf '%s\n' "$got" | tail -n 1)
  if [ "$got" = "$expected" ]; then pass "$name -> $got"; else bad "$name attendu=$expected obtenu=$got"; fi
}

call_fail() {
  local name="$1" stmt="$2" needle="$3"
  if "${MARIA[@]}" -e "$stmt" >/tmp/thalie_15d.out 2>/tmp/thalie_15d.err; then
    bad "$name aurait dû échouer"
  elif grep -q "$needle" /tmp/thalie_15d.err; then
    pass "$name refuse ($needle)"
  else
    bad "$name mauvais message"
    cat /tmp/thalie_15d.err
  fi
}

tenir() {
  local session="$1" out="$2"
  "${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; START TRANSACTION; SELECT id FROM sessions WHERE id = '${session}' FOR UPDATE; SELECT SLEEP(4); COMMIT;" >"$out" 2>"${out}.err" &
  echo $! >"${out}.pid"
}

attentes() { sql "SELECT COUNT(*) FROM information_schema.INNODB_LOCK_WAITS"; }

courant=$(sql "SELECT DATABASE()")
if [ "$courant" != "$DB" ]; then
  echo "Base inattendue : $courant"
  exit 1
fi

photo_avant=$(sql "
SELECT CONCAT(
  (SELECT CONCAT(options_posees,'/',reel_estime,'/',realise,'/',places_bloquees) FROM contingents WHERE id='ffffffff-ffff-4fff-8fff-fffffffffff2'),
  '|',
  (SELECT CONCAT(places_bloquees,'/',places_confirmees,'/',places_liberees) FROM sessions WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'),
  '|',
  (SELECT statut_administratif FROM inscriptions WHERE id='12121212-1212-4121-8121-121212121214')
)")

echo "---- préparation 15d ----"
sql "
DELETE FROM historique_capacites WHERE session_id LIKE '${P}-%';
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
  ('${P}-000000000002', '${P}-000000000001', 'Mael', 'Essai', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO enfants (id, famille_id, prenom, nom, naissance, naissance_incomplete, cree_le, modifie_le) VALUES
  ('${P}-000000000101', '${P}-000000000001', 'Cap', 'Un', '2016-04-01', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000102', '${P}-000000000001', 'Cap', 'Deux', '2016-04-02', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000103', '${P}-000000000001', 'Cap', 'Trois', '2016-04-03', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000104', '${P}-000000000001', 'Cap', 'Quatre', '2016-04-04', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000105', '${P}-000000000001', 'Cap', 'Cinq', '2016-04-05', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO commandes (id, famille_id, adulte_id, statut, cree_le, modifie_le) VALUES
  ('${P}-000000000010', '${P}-000000000001', '${P}-000000000002', 'enregistree', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO centres (id, nom, slug, cree_le, modifie_le) VALUES
  ('${P}-000000000020', 'Centre Capacite', 'centre-capacite-15d', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO sejours (id, centre_id, titre, slug, publie, cree_le, modifie_le) VALUES
  ('${P}-000000000021', '${P}-000000000020', 'Sejour Capacite', 'sejour-capacite-15d', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO sessions (id, sejour_id, debut, fin, capacite, statut_commercial, cree_le, modifie_le) VALUES
  ('${P}-000000000031', '${P}-000000000021', '2027-03-01', '2027-03-07', 10, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000032', '${P}-000000000021', '2027-03-08', '2027-03-14', 10, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000033', '${P}-000000000021', '2027-03-15', '2027-03-21', 20, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000034', '${P}-000000000021', '2027-03-22', '2027-03-28', 10, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000035', '${P}-000000000021', '2027-04-01', '2027-04-07', 10, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000036', '${P}-000000000021', '2027-04-08', '2027-04-14', 1, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000037', '${P}-000000000021', '2027-04-15', '2027-04-21', 5, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000038', '${P}-000000000021', '2027-04-22', '2027-04-28', 8, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO segments_clients (id, code, libelle, cree_le, modifie_le) VALUES
  ('${P}-000000000041', 'cap-cse-a', 'Capacite A', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000042', 'cap-cse-b', 'Capacite B', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO contingents (id, session_id, segment_id, options_posees, reel_estime, realise, cree_le, modifie_le) VALUES
  ('${P}-000000000051', '${P}-000000000032', '${P}-000000000041', 0, 0, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000052', '${P}-000000000033', '${P}-000000000041', 0, 6, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000053', '${P}-000000000033', '${P}-000000000042', 0, 5, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000054', '${P}-000000000037', '${P}-000000000041', 0, 0, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
"

A="'${P}-000000000010', '${P}-000000000001'"
S="'${P}-000000000021'"

echo "---- 1. augmentation ----"
call_ok "hausse 10 vers 14" "CALL modifier_capacite('${P}-000000000031', 14, 'cap-hausse', 'admin')" "ok"
assert_eq "capacité augmentée" "SELECT capacite FROM sessions WHERE id='${P}-000000000031'" "14"
assert_eq "historique de hausse" "SELECT CONCAT(capacite_avant,'/',capacite_apres,'/',places_occupees) FROM historique_capacites WHERE cle_idempotence='cap-hausse'" "10/14/0"

echo "---- 2. diminution autorisée ----"
call_ok "estimation 3" "CALL ajuster_contingent('${P}-000000000051', 'reel_estime', 3, 'cap-reel-3', 'admin')" "ok"
call_ok "une réservation" "CALL bloquer_place('${P}-000000000201', $A, '${P}-000000000101', $S, '${P}-000000000032', 'cap-book')" "ok"
call_ok "baisse jusqu'aux places tenues" "CALL modifier_capacite('${P}-000000000032', 4, 'cap-baisse', 'admin')" "ok"
assert_eq "capacité au plancher" "SELECT capacite FROM sessions WHERE id='${P}-000000000032'" "4"
assert_eq "historique de baisse" "SELECT CONCAT(capacite_avant,'/',capacite_apres,'/',places_occupees) FROM historique_capacites WHERE cle_idempotence='cap-baisse'" "10/4/4"
assert_eq "l'estimation n'a pas bougé" "SELECT reel_estime FROM contingents WHERE id='${P}-000000000051'" "3"
assert_eq "l'inscription n'a pas bougé" "SELECT statut_administratif FROM inscriptions WHERE id='${P}-000000000201'" "place_bloquee"

echo "---- 3. diminution trop basse ----"
call_fail "sous les places tenues" "CALL modifier_capacite('${P}-000000000032', 3, 'cap-trop-bas', 'admin')" "capacite_insuffisante"
assert_eq "capacité inchangée après refus" "SELECT capacite FROM sessions WHERE id='${P}-000000000032'" "4"
assert_eq "pas de ligne d'historique pour le refus" "SELECT COUNT(*) FROM historique_capacites WHERE cle_idempotence='cap-trop-bas'" "0"

echo "---- 4. plusieurs contingents ----"
call_ok "réservation parmi deux CSE" "CALL bloquer_place('${P}-000000000202', $A, '${P}-000000000102', $S, '${P}-000000000033', 'cap-multi-book')" "ok"
call_ok "baisse couvrant 6 + 5 + 1" "CALL modifier_capacite('${P}-000000000033', 12, 'cap-multi', 'admin')" "ok"
assert_eq "historique multi-contingents" "SELECT CONCAT(capacite_avant,'/',capacite_apres,'/',places_occupees) FROM historique_capacites WHERE cle_idempotence='cap-multi'" "20/12/12"
call_fail "un cran sous les deux CSE" "CALL modifier_capacite('${P}-000000000033', 11, 'cap-multi-bas', 'admin')" "capacite_insuffisante"
assert_eq "capacité multi inchangée" "SELECT capacite FROM sessions WHERE id='${P}-000000000033'" "12"
assert_eq "les deux estimations restent" "SELECT CONCAT(SUM(reel_estime),'/',SUM(places_bloquees)) FROM contingents WHERE session_id='${P}-000000000033'" "11/11"

echo "---- 5 et 6. même clé, puis clé détournée ----"
call_ok "première modification" "CALL modifier_capacite('${P}-000000000034', 12, 'cap-idem', 'admin')" "ok"
call_ok "même clé et même capacité" "CALL modifier_capacite('${P}-000000000034', 12, 'cap-idem', 'admin')" "deja_applique"
assert_eq "une seule ligne d'historique" "SELECT COUNT(*) FROM historique_capacites WHERE session_id='${P}-000000000034'" "1"
assert_eq "capacité non doublée" "SELECT capacite FROM sessions WHERE id='${P}-000000000034'" "12"
call_fail "même clé, autre capacité" "CALL modifier_capacite('${P}-000000000034', 13, 'cap-idem', 'admin')" "cle_deja_utilisee"
assert_eq "l'autre capacité n'est pas appliquée" "SELECT capacite FROM sessions WHERE id='${P}-000000000034'" "12"
call_fail "clé de capacité réutilisée pour réserver" "CALL bloquer_place('${P}-000000000203', $A, '${P}-000000000103', $S, '${P}-000000000034', 'cap-idem')" "cle_deja_utilisee"
call_ok "réservation avec sa propre clé" "CALL bloquer_place('${P}-000000000203', $A, '${P}-000000000103', $S, '${P}-000000000034', 'cap-book-idem')" "ok"
call_fail "clé de réservation réutilisée pour la capacité" "CALL modifier_capacite('${P}-000000000034', 15, 'cap-book-idem', 'admin')" "cle_deja_utilisee"
assert_eq "capacité toujours 12" "SELECT capacite FROM sessions WHERE id='${P}-000000000034'" "12"
assert_eq "la réservation tient toujours" "SELECT places_bloquees FROM sessions WHERE id='${P}-000000000034'" "1"

echo "---- 7. deux modifications concurrentes ----"
tenir "${P}-000000000035" /tmp/d15_lock_a.out
lock=$(cat /tmp/d15_lock_a.out.pid)
sleep 0.5
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL modifier_capacite('${P}-000000000035', 6, 'cap-course-6', 'admin');" >/tmp/d15_a.out 2>/tmp/d15_a.err &
p6=$!
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL modifier_capacite('${P}-000000000035', 4, 'cap-course-4', 'admin');" >/tmp/d15_b.out 2>/tmp/d15_b.err &
p4=$!
sleep 0.6
n=$(attentes)
if [ "$n" -ge 2 ]; then pass "les deux modifications attendent ($n)"; else bad "attente insuffisante ($n)"; fi
wait "$lock" "$p6" "$p4" || true
okn=0
grep -q '^ok$' /tmp/d15_a.out && okn=$((okn + 1))
grep -q '^ok$' /tmp/d15_b.out && okn=$((okn + 1))
fin=$(sql "SELECT capacite FROM sessions WHERE id='${P}-000000000035'")
chaine=$(sql "SELECT GROUP_CONCAT(CONCAT(capacite_avant,'>',capacite_apres) ORDER BY cree_le, id SEPARATOR ',') FROM historique_capacites WHERE session_id='${P}-000000000035'")
if [ "$okn" -eq 2 ] && { [ "$chaine" = "10>6,6>4" ] || [ "$chaine" = "10>4,4>6" ]; } && { [ "$fin" = "4" ] || [ "$fin" = "6" ]; }; then
  pass "les deux valeurs s'enchaînent ($chaine), capacité finale $fin"
else
  bad "course de capacités okn=$okn chaine=$chaine fin=$fin"
  cat /tmp/d15_a.out /tmp/d15_a.err /tmp/d15_b.out /tmp/d15_b.err
fi

echo "---- 8. capacité et réservation simultanées ----"
tenir "${P}-000000000036" /tmp/d15_lock_b.out
lock=$(cat /tmp/d15_lock_b.out.pid)
sleep 0.5
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL modifier_capacite('${P}-000000000036', 0, 'cap-vers-0', 'admin');" >/tmp/d15_c.out 2>/tmp/d15_c.err &
pc=$!
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL bloquer_place('${P}-000000000204', $A, '${P}-000000000104', $S, '${P}-000000000036', 'cap-derniere');" >/tmp/d15_d.out 2>/tmp/d15_d.err &
pb=$!
sleep 0.6
n=$(attentes)
if [ "$n" -ge 2 ]; then pass "capacité et réservation attendent ($n)"; else bad "attente capacité/réservation insuffisante ($n)"; fi
wait "$lock" "$pc" "$pb" || true
cok=0; bok=0
grep -q '^ok$' /tmp/d15_c.out && cok=1
grep -q '^ok$' /tmp/d15_d.out && bok=1
etat=$(sql "SELECT CONCAT(capacite,'/',places_bloquees) FROM sessions WHERE id='${P}-000000000036'")
if [ $((cok + bok)) -eq 1 ] && { [ "$etat" = "0/0" ] || [ "$etat" = "1/1" ]; }; then
  pass "une seule demande passe, état $etat"
else
  bad "course capacité/réservation cap=$cok book=$bok etat=$etat"
  cat /tmp/d15_c.out /tmp/d15_c.err /tmp/d15_d.out /tmp/d15_d.err
fi
ecart=$(sql "CALL constater_ecart_places('${P}-000000000036')" || true)
if [ -z "$ecart" ]; then
  pass "aucun écart après capacité/réservation"
else
  bad "écart après capacité/réservation"
  printf '%s\n' "$ecart"
fi

echo "---- 9. capacité et hausse CSE simultanées ----"
tenir "${P}-000000000037" /tmp/d15_lock_c.out
lock=$(cat /tmp/d15_lock_c.out.pid)
sleep 0.5
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL modifier_capacite('${P}-000000000037', 2, 'cap-vers-2', 'admin');" >/tmp/d15_e.out 2>/tmp/d15_e.err &
pe=$!
"${MARIA[@]}" -N -e "SET SESSION innodb_lock_wait_timeout = 8; CALL ajuster_contingent('${P}-000000000054', 'reel_estime', 4, 'cap-reel-4', 'admin');" >/tmp/d15_f.out 2>/tmp/d15_f.err &
pf=$!
sleep 0.6
n=$(attentes)
if [ "$n" -ge 2 ]; then pass "capacité et estimation attendent ($n)"; else bad "attente capacité/estimation insuffisante ($n)"; fi
wait "$lock" "$pe" "$pf" || true
eok=0; fok=0
grep -q '^ok$' /tmp/d15_e.out && eok=1
grep -q '^ok$' /tmp/d15_f.out && fok=1
etat=$(sql "SELECT CONCAT(capacite,'/',reel_estime) FROM sessions s JOIN contingents c ON c.session_id=s.id WHERE s.id='${P}-000000000037'")
if [ $((eok + fok)) -eq 1 ] && { [ "$etat" = "2/0" ] || [ "$etat" = "5/4" ]; }; then
  pass "une seule hausse passe, état $etat"
else
  bad "course capacité/estimation cap=$eok reel=$fok etat=$etat"
  cat /tmp/d15_e.out /tmp/d15_e.err /tmp/d15_f.out /tmp/d15_f.err
fi
dispo=$(sql "SELECT capacite - places_bloquees - places_confirmees - (SELECT COALESCE(SUM(places_bloquees),0) FROM contingents WHERE session_id='${P}-000000000037') FROM sessions WHERE id='${P}-000000000037'")
if [ "$dispo" -ge 0 ]; then pass "disponibilité non négative ($dispo)"; else bad "disponibilité $dispo"; fi

echo "---- compteur faux : la capacité n'est pas réécrite ----"
sql "UPDATE sessions SET places_bloquees = 3 WHERE id = '${P}-000000000038'"
call_fail "modification sur compteur incohérent" "CALL modifier_capacite('${P}-000000000038', 10, 'cap-incoherent', 'admin')" "incoherence_compteurs"
assert_eq "capacité non corrigée" "SELECT capacite FROM sessions WHERE id='${P}-000000000038'" "8"
assert_eq "compteur non corrigé" "SELECT places_bloquees FROM sessions WHERE id='${P}-000000000038'" "3"

photo_apres=$(sql "
SELECT CONCAT(
  (SELECT CONCAT(options_posees,'/',reel_estime,'/',realise,'/',places_bloquees) FROM contingents WHERE id='ffffffff-ffff-4fff-8fff-fffffffffff2'),
  '|',
  (SELECT CONCAT(places_bloquees,'/',places_confirmees,'/',places_liberees) FROM sessions WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'),
  '|',
  (SELECT statut_administratif FROM inscriptions WHERE id='12121212-1212-4121-8121-121212121214')
)")
if [ "$photo_avant" = "$photo_apres" ]; then pass "données 1.4C inchangées ($photo_apres)"; else bad "données 1.4C modifiées : $photo_avant -> $photo_apres"; fi

if [ "$fail" -eq 0 ]; then echo "BILAN 15d ok"; else echo "BILAN 15d echec"; exit 1; fi
