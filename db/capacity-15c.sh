#!/bin/bash
# Sécurisation du moteur de places. Base fixe : thalie_test.
# Ne supprime pas les jeux 1.4C, 1.5 ni 1.5B.
set -u
DB=thalie_test
MARIA=(mariadb --protocol=socket "$DB")
fail=0
P=15c00000-0000-4000-8000

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
  got=$("${MARIA[@]}" -N -e "$stmt" 2>/tmp/thalie_15c.err) || { bad "$name erreur SQL"; cat /tmp/thalie_15c.err; return; }
  got=$(printf '%s\n' "$got" | tail -n 1)
  if [ "$got" = "$expected" ]; then pass "$name -> $got"; else bad "$name attendu=$expected obtenu=$got"; fi
}

call_fail() {
  local name="$1" stmt="$2" needle="$3"
  if "${MARIA[@]}" -e "$stmt" >/tmp/thalie_15c.out 2>/tmp/thalie_15c.err; then
    bad "$name aurait dû échouer"
  elif grep -q "$needle" /tmp/thalie_15c.err; then
    pass "$name refuse ($needle)"
  else
    bad "$name mauvais message"
    cat /tmp/thalie_15c.err
  fi
}

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

echo "---- préparation 15c, sans effacer les autres jeux ----"
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
  ('${P}-000000000002', '${P}-000000000001', 'Nils', 'Essai', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO enfants (id, famille_id, prenom, nom, naissance, naissance_incomplete, cree_le, modifie_le) VALUES
  ('${P}-000000000101', '${P}-000000000001', 'Secu', 'Un', '2016-03-01', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000102', '${P}-000000000001', 'Secu', 'Deux', '2016-03-02', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000103', '${P}-000000000001', 'Secu', 'Trois', '2016-03-03', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000104', '${P}-000000000001', 'Secu', 'Quatre', '2016-03-04', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000105', '${P}-000000000001', 'Secu', 'Cinq', '2016-03-05', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000106', '${P}-000000000001', 'Secu', 'Six', '2016-03-06', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000107', '${P}-000000000001', 'Secu', 'Sept', '2016-03-07', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000108', '${P}-000000000001', 'Secu', 'Huit', '2016-03-08', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO commandes (id, famille_id, adulte_id, statut, cree_le, modifie_le) VALUES
  ('${P}-000000000010', '${P}-000000000001', '${P}-000000000002', 'enregistree', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO centres (id, nom, slug, cree_le, modifie_le) VALUES
  ('${P}-000000000020', 'Centre Securite', 'centre-securite-15c', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO sejours (id, centre_id, titre, slug, publie, cree_le, modifie_le) VALUES
  ('${P}-000000000021', '${P}-000000000020', 'Sejour Securite', 'sejour-securite-15c', 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO sessions (id, sejour_id, debut, fin, capacite, statut_commercial, cree_le, modifie_le) VALUES
  ('${P}-000000000031', '${P}-000000000021', '2026-11-01', '2026-11-07', 6, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000032', '${P}-000000000021', '2026-11-08', '2026-11-14', 4, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000033', '${P}-000000000021', '2026-11-15', '2026-11-21', 4, 'brouillon', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000034', '${P}-000000000021', '2026-11-22', '2026-11-28', 4, 'annulee', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000035', '${P}-000000000021', '2026-12-01', '2026-12-07', 4, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000036', '${P}-000000000021', '2026-12-08', '2026-12-14', 4, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000037', '${P}-000000000021', '2026-12-15', '2026-12-21', 4, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000038', '${P}-000000000021', '2026-12-22', '2026-12-28', 10, 'ouverte', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO segments_clients (id, code, libelle, cree_le, modifie_le) VALUES
  ('${P}-000000000041', 'secu-cse', 'Securite CSE', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
INSERT INTO contingents (id, session_id, segment_id, options_posees, reel_estime, realise, cree_le, modifie_le) VALUES
  ('${P}-000000000051', '${P}-000000000038', '${P}-000000000041', 0, 4, 0, UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
"

A="'${P}-000000000010', '${P}-000000000001'"
S="'${P}-000000000021'"
B="CALL bloquer_place"

echo "---- session ouverte, fermée, brouillon, annulée ----"
call_ok "réservation ouverte" "$B('${P}-000000000201', $A, '${P}-000000000101', $S, '${P}-000000000031', 'livre-ok')" "ok"
assert_eq "place bloquée" "SELECT places_bloquees FROM sessions WHERE id='${P}-000000000031'" "1"
call_ok "prépare la première inscription à fermer" "$B('${P}-000000000211', $A, '${P}-000000000102', $S, '${P}-000000000032', 'ferme-1')" "ok"
call_ok "prépare la seconde inscription à fermer" "$B('${P}-000000000212', $A, '${P}-000000000103', $S, '${P}-000000000032', 'ferme-2')" "ok"
sql "UPDATE sessions SET statut_commercial = 'fermee' WHERE id = '${P}-000000000032'"
call_fail "réservation sur session fermée" "$B('${P}-000000000213', $A, '${P}-000000000104', $S, '${P}-000000000032', 'ferme-3')" "session_non_ouverte"
call_ok "confirmation sur session fermée" "CALL confirmer_inscription('${P}-000000000211', 'ferme-confirm')" "ok"
call_ok "confirmation fermée répétée, même clé" "CALL confirmer_inscription('${P}-000000000211', 'ferme-confirm')" "deja_applique"
assert_eq "une seule confirmation" "SELECT places_confirmees FROM sessions WHERE id='${P}-000000000032'" "1"
call_ok "annulation sur session fermée" "CALL annuler_inscription('${P}-000000000212', 'ferme-annul', 'site')" "ok"
call_ok "annulation fermée répétée, même clé" "CALL annuler_inscription('${P}-000000000212', 'ferme-annul', 'site')" "deja_applique"
assert_eq "une seule libération" "SELECT places_liberees FROM sessions WHERE id='${P}-000000000032'" "1"
assert_eq "plus de place bloquée après annulation" "SELECT places_bloquees FROM sessions WHERE id='${P}-000000000032'" "0"
call_fail "brouillon" "$B('${P}-000000000221', $A, '${P}-000000000101', $S, '${P}-000000000033', 'brouillon-1')" "session_non_ouverte"
call_fail "session annulée" "$B('${P}-000000000222', $A, '${P}-000000000101', $S, '${P}-000000000034', 'annulee-1')" "session_non_ouverte"

echo "---- idempotence ----"
call_ok "première confirmation" "CALL confirmer_inscription('${P}-000000000201', 'conf-meme')" "ok"
call_ok "même clé de confirmation" "CALL confirmer_inscription('${P}-000000000201', 'conf-meme')" "deja_applique"
call_ok "nouvelle clé, transition déjà faite" "CALL confirmer_inscription('${P}-000000000201', 'conf-nouvelle')" "deja_confirme"
assert_eq "confirmées toujours à 1" "SELECT places_confirmees FROM sessions WHERE id='${P}-000000000031'" "1"
call_ok "réservation dont la clé sera réutilisée" "$B('${P}-000000000205', $A, '${P}-000000000105', $S, '${P}-000000000031', 'melange')" "ok"
call_fail "même clé pour une annulation" "CALL annuler_inscription('${P}-000000000205', 'melange', 'site')" "cle_deja_utilisee"
assert_eq "l'inscription mal rejouée reste bloquée" "SELECT statut_administratif FROM inscriptions WHERE id='${P}-000000000205'" "place_bloquee"
assert_eq "la clé étrangère n'a pas libéré la place" "SELECT places_bloquees FROM sessions WHERE id='${P}-000000000031'" "1"

echo "---- deux confirmations identiques concurrentes ----"
"${MARIA[@]}" -N -e "CALL confirmer_inscription('${P}-000000000205', 'conf-course')" >/tmp/c15_a.out 2>/tmp/c15_a.err &
"${MARIA[@]}" -N -e "CALL confirmer_inscription('${P}-000000000205', 'conf-course')" >/tmp/c15_b.out 2>/tmp/c15_b.err &
wait || true
okn=0; dejn=0
grep -q '^ok$' /tmp/c15_a.out && okn=$((okn + 1))
grep -q '^ok$' /tmp/c15_b.out && okn=$((okn + 1))
grep -q '^deja_applique$' /tmp/c15_a.out && dejn=$((dejn + 1))
grep -q '^deja_applique$' /tmp/c15_b.out && dejn=$((dejn + 1))
if [ "$okn" -eq 1 ] && [ "$dejn" -eq 1 ]; then
  pass "une confirmation et une répétition explicite"
else
  bad "course confirmation ok=$okn deja=$dejn"
  echo "-- A --"; cat /tmp/c15_a.out /tmp/c15_a.err
  echo "-- B --"; cat /tmp/c15_b.out /tmp/c15_b.err
fi
assert_eq "la course ne confirme qu'une fois" "SELECT places_confirmees FROM sessions WHERE id='${P}-000000000031'" "2"
assert_eq "la course ne laisse pas la place bloquée" "SELECT places_bloquees FROM sessions WHERE id='${P}-000000000031'" "0"

echo "---- deux blocages identiques concurrents ----"
"${MARIA[@]}" -N -e "$B('${P}-000000000214', $A, '${P}-000000000104', $S, '${P}-000000000031', 'double-identique')" >/tmp/c15_c.out 2>/tmp/c15_c.err &
"${MARIA[@]}" -N -e "$B('${P}-000000000214', $A, '${P}-000000000104', $S, '${P}-000000000031', 'double-identique')" >/tmp/c15_d.out 2>/tmp/c15_d.err &
wait || true
okn=0; dejn=0
grep -q '^ok$' /tmp/c15_c.out && okn=$((okn + 1))
grep -q '^ok$' /tmp/c15_d.out && okn=$((okn + 1))
grep -q '^deja_applique$' /tmp/c15_c.out && dejn=$((dejn + 1))
grep -q '^deja_applique$' /tmp/c15_d.out && dejn=$((dejn + 1))
if [ "$okn" -eq 1 ] && [ "$dejn" -eq 1 ]; then
  pass "un blocage et une répétition explicite"
else
  bad "course blocage ok=$okn deja=$dejn"
  echo "-- C --"; cat /tmp/c15_c.out /tmp/c15_c.err
  echo "-- D --"; cat /tmp/c15_d.out /tmp/c15_d.err
fi
assert_eq "une seule ligne pour la clé répétée" "SELECT COUNT(*) FROM inscriptions WHERE id='${P}-000000000214'" "1"

echo "---- historique non réactivé ----"
call_ok "inscription qui sera annulée" "$B('${P}-000000000206', $A, '${P}-000000000106', $S, '${P}-000000000035', 'histo-1')" "ok"
call_ok "annulation conservée" "CALL annuler_inscription('${P}-000000000206', 'histo-annul', 'site')" "ok"
call_fail "réactivation annulée" "$B('${P}-000000000206', $A, '${P}-000000000106', $S, '${P}-000000000035', 'histo-2')" "reactivation_interdite"
assert_eq "l'ancienne reste annulée" "SELECT statut_administratif FROM inscriptions WHERE id='${P}-000000000206'" "annulee"
call_ok "nouvelle inscription après l'historique" "$B('${P}-000000000207', $A, '${P}-000000000106', $S, '${P}-000000000035', 'histo-3')" "ok"
assert_eq "deux lignes, une seule active" "SELECT CONCAT(SUM(statut_administratif='annulee'),'/',SUM(statut_administratif='place_bloquee')) FROM inscriptions WHERE session_id='${P}-000000000035'" "1/1"
sql "
INSERT INTO inscriptions (
  id, commande_id, famille_id, enfant_id, sejour_id, session_id,
  statut_administratif, statut_financier, statut_documentaire, cree_le, modifie_le
) VALUES
  ('${P}-000000000208', '${P}-000000000010', '${P}-000000000001', '${P}-000000000107', $S, '${P}-000000000036', 'refusee', 'aucun', 'manquant', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3)),
  ('${P}-000000000209', '${P}-000000000010', '${P}-000000000001', '${P}-000000000108', $S, '${P}-000000000037', 'transferee', 'aucun', 'manquant', UTC_TIMESTAMP(3), UTC_TIMESTAMP(3));
"
call_fail "réactivation refusée" "$B('${P}-000000000208', $A, '${P}-000000000107', $S, '${P}-000000000036', 'refus-1')" "reactivation_interdite"
call_fail "réactivation transférée" "$B('${P}-000000000209', $A, '${P}-000000000108', $S, '${P}-000000000037', 'transf-1')" "reactivation_interdite"
assert_eq "le refus est intact" "SELECT statut_administratif FROM inscriptions WHERE id='${P}-000000000208'" "refusee"
assert_eq "le transfert est intact" "SELECT statut_administratif FROM inscriptions WHERE id='${P}-000000000209'" "transferee"
assert_eq "aucune place prise par l'historique" "SELECT places_bloquees + places_confirmees FROM sessions WHERE id='${P}-000000000036'" "0"

echo "---- contingent : la hausse est refusée si la session est fermée ----"
sql "UPDATE sessions SET statut_commercial = 'fermee' WHERE id = '${P}-000000000038'"
call_ok "baisse du réel estimé sur session fermée" "CALL ajuster_contingent('${P}-000000000051', 'reel_estime', 2, 'baisse-fermee', 'admin')" "ok"
call_fail "hausse du réel estimé sur session fermée" "CALL ajuster_contingent('${P}-000000000051', 'reel_estime', 5, 'hausse-fermee', 'admin')" "session_non_ouverte"
assert_eq "le réel estimé reste à 2" "SELECT reel_estime FROM contingents WHERE id='${P}-000000000051'" "2"
call_fail "nouvelle inscription de contingent sur session fermée" "CALL inscrire_contingent('${P}-000000000230', $A, '${P}-000000000102', $S, '${P}-000000000038', '${P}-000000000051', 'cse-ferme', 'filemaker')" "session_non_ouverte"

echo "---- capacité : couverte par db/capacity-15d.sh ----"

photo_apres=$(sql "
SELECT CONCAT(
  (SELECT CONCAT(options_posees,'/',reel_estime,'/',realise,'/',places_bloquees) FROM contingents WHERE id='ffffffff-ffff-4fff-8fff-fffffffffff2'),
  '|',
  (SELECT CONCAT(places_bloquees,'/',places_confirmees,'/',places_liberees) FROM sessions WHERE id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3'),
  '|',
  (SELECT statut_administratif FROM inscriptions WHERE id='12121212-1212-4121-8121-121212121214')
)")
if [ "$photo_avant" = "$photo_apres" ]; then pass "données 1.4C inchangées ($photo_apres)"; else bad "données 1.4C modifiées : $photo_avant -> $photo_apres"; fi

if [ "$fail" -eq 0 ]; then echo "BILAN 15c ok"; else echo "BILAN 15c echec"; exit 1; fi
