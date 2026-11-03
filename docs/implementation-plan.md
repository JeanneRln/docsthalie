# Plan de réalisation

Référence Lot 1.0 — précisée le 3 novembre 2026.

Découpage en missions Cursor courtes. Aucune de ces missions n’est lancée par ce document. Le Lot 1.0 est la rédaction des cinq fichiers `docs/`, déjà autorisée.

Chaque mission de code laisse la maquette utilisable. Les routes actuelles restent. Les données fictives restent fictives.

Dépendances documentaires : `architecture-thalie.md`, `database-model-v0.3.md`, `filemaker-sync-matrix.md`, `migration-sources.md`.

## 1. Déjà tranché, et ce qui bloque encore

Tranché : MariaDB, pas Supabase ; validation des pièces familles exclusivement dans FileMaker ; une place hors contingent confirmée ne compte pas deux fois ; contingent CSE compris dans la capacité, blocage égal au plus grand entre le réel estimé et le réalisé, options initiales sans effet sur les places ; pas d’unicité permanente enfant-session ; prix figé ; paiement ventilé en écritures FileMaker distinctes ; imports séparés ; sanitaire absent du schéma.

Encore ouvert, et donc hors des premières missions de code :

| Sujet | Effet |
| --- | --- |
| Version MariaDB du VPS et lieu du processus Next.js | Bloque la mise en production et la mission de migrations |
| Noms de rubriques FileMaker | Bloque tout connecteur |
| Rubrique FileMaker qui désigne le partenaire d’une inscription nominative | Bloque le rapprochement automatique vers le contingent. La règle de non-double-compte est déjà fixée |
| Le contrat Axepta autorise-t-il le trois fois à J, J+30 et J+60 ? | Bloque la création de ces échéances et l’appel prestataire |
| Niveau des échéances : commande ou inscription, selon les règles de paiement | Bloque le paramétrage du tunnel, pas la forme des tables |
| Lieu où le bureau confirme une réservation | Bloque l’écran de confirmation |
| Motifs de remboursement après refus payé | Bloque le bouton de remboursement |
| Quels séjours exigent un pass nautique | Bloque le paramétrage de cette exigence |
| Export des URL Oxatis | Bloque les redirections |
| Clé OneDrive et unicité de la référence de facturation | Bloque le rattachement automatique des factures |
| Cadre sanitaire | Bloque toute table et toute synchro de santé |
| Périmètre réellement livrable fin novembre 2026 | Bloque une promesse commerciale, pas la mission 1.1 |

## 2. Lot 1 — fondation sur la maquette

### Mission 1.1 — Un seul identifiant de séjour

Objectif. Enfants, dossier, fiche, documents et bureau utilisent les identifiants de `lib/sejours.ts` (`passion-2027`, `studio-theatre-2026`, et les deux séjours passés). L’ancienne query `sejour=passion` reste acceptée comme alias, pour ne pas casser un lien déjà ouvert.

Fichiers. `app/enfants/page.tsx`, `app/dossier/page.tsx`, `app/fiche/page.tsx`, `app/documents/page.tsx`. Lecture de `lib/sejours.ts`. Aucun autre fichier.

Dépendances. Aucune. C’est la première mission de développement recommandée.

Risque. Un lien dossier qui retomberait sur Studio Théâtre dès que le paramètre n’est pas `passion`. Le test ci-dessous couvre ce cas.

Tests. À la main sur `http://localhost:3000` :

- Léa, Passion Cinéma, ouvre le bon dossier et la bonne fiche.
- Léa, Studio Théâtre, ouvre Studio Théâtre et non Passion.
- Tom, Studio Théâtre, reste « Complet » et « Voir les documents » filtre `studio-theatre-2026`.
- `?sejour=passion` ouvre encore Passion Cinéma.
- Les filtres documents (année, enfant, séjour, type) et le retour vers les enfants fonctionnent.

Acceptation. Un seul vocabulaire d’identifiant dans les liens neufs. L’alias `passion` est explicite dans le code. Aucun changement de charte, de texte métier ou de PDF.

### Mission 1.2 — Types de domaine et une seule liste de séjours

Objectif. Décrire dans `lib/domain.ts` famille, adulte, enfant, centre, séjour, session, inscription, et les trois statuts avec les valeurs de `database-model-v0.3.md`. `app/enfants/page.tsx` lit `lib/sejours.ts` au lieu d’une deuxième liste écrite dans le JSX. L’écran affiché reste le même.

Fichiers. `lib/domain.ts` (nouveau), `lib/sejours.ts`, `app/enfants/page.tsx`.

Dépendances. 1.1.

Risque. Écarter un séjour passé ou changer un libellé. Comparer la page avant et après.

Tests. Les quatre séjours fictifs, les pastilles « À compléter » et « Complet », le bouton documents de Tom, le bouton secondaire des documents administratifs.

Acceptation. Aucune nouvelle route. Les statuts du type TypeScript sont exactement `place_bloquee`, `confirmee`, `refusee`, `annulee`, `transferee`, et les deux autres listes du modèle v0.3. Le booléen unique « complet » de la maquette devient un affichage calculé, encore alimenté par les fixtures.

### Mission 1.3 — Vocabulaire documentaire, sans connecteur

Objectif. Nommer, dans les types seulement, le flux validé : dépôt sur le site, copie FileMaker, validation FileMaker, verrou au retour. Ne pas brancher FileMaker. Ne pas retirer le bouton de la maquette dans cette mission : il reste une démonstration locale. Un commentaire de module, au-dessus du type, dit que ce bouton n’est pas la validation qui fera foi.

Fichiers. `lib/domain.ts`.

Dépendances. 1.2.

Risque. Confondre le verrou local et le futur `verrouille_le`. La mission ne change pas l’interface, justement pour éviter cette confusion dans le même geste que le typage.

Tests. Compilation TypeScript. Parcours dossier inchangé : « Enregistrer et valider » se comporte comme aujourd’hui.

Acceptation. Les statuts de pièce du modèle v0.3 sont ceux du type. Aucun appel réseau.

### Mission 1.4 — Migrations SQL, sur demande séparée

Objectif. Traduire `database-model-v0.3.md` dans `db/migrations/`, après accord explicite et après avoir lu la version MariaDB du VPS. Le script applique et ré-applique sans doublon. Aucune page ne se connecte.

Fichiers. `db/migrations/` seulement, plus un script de lancement s’il est inclus dans l’accord.

Dépendances. Ces documents acceptés. Version MariaDB connue. Interdit d’utiliser un index unique partiel, `JSONB`, ou un schéma PostgreSQL.

Risque. Écrire une contrainte que la version réelle refuse. D’où le contrôle de version avant le script.

Tests. Deux passages du script sur une base vide jetable. Deux inscriptions actives du même enfant sur la même session : refusées. Une inscription annulée puis une inscription bloquée pour le même couple : acceptées. Confirmer déplace une place de `places_bloquees` vers `places_confirmees` sans augmenter le total tenu. Une inscription dont l’enfant n’est pas de la famille de la commande : refusée. Une session qui n’appartient pas au séjour indiqué : refusée. Un transport qui n’appartient pas à la session : refusé.

Acceptation. Aucune table sanitaire. Aucune donnée réelle. Les tables d’import n’ont pas de clé étrangère vers les tables vivantes. Le contingent bloque le plus grand entre le réel estimé et le réalisé. Les options initiales ne retirent pas de place.

### Mission 1.5 — Places atomiques, hors interface

Objectif. Un script, pas un bouton, qui prend la dernière place deux fois en parallèle et n’en laisse passer qu’une. Confirmer déplace la place hors contingent sans augmenter le total tenu. Libérer l’ajoute à `places_liberees` une fois. Rejouer la même clé ne libère pas une deuxième fois. Baisser la capacité sous les places tenues, contingents compris, est refusé dans la même transaction. Le cas chiffré validé est rejoué : capacité 30, options 12, réel estimé 7, réalisé 5, disponibilité 23. Monter l’estimation au-delà du reste est refusé. La baisser libère des places sans passer sous le réalisé. Rapprocher une inscription FileMaker du contingent ne la compte pas deux fois.

Fichiers. Script de test hors des pages, seulement quand la mission de migrations aura été autorisée.

Dépendances. 1.4.

Tests. Deux transactions concurrentes. Une confirmation. Une libération. Un rejeu. Une baisse de capacité impossible. L’exemple 30 / 12 / 7 / 5. Une hausse d’estimation acceptée puis refusée. Une baisse d’estimation sous le réalisé. Un rapprochement FileMaker rejoué.

Acceptation. Disponibilité 23 dans l’exemple. Blocage égal au plus grand des deux nombres. Historique d’une modification présent une seule fois. Le chevauchement de dates n’a rien refusé.

### Mission 1.6 — Accès mémoire derrière une interface

Objectif. Les lectures de la maquette passent par des fonctions de `server/` dont l’implémentation reste la mémoire actuelle. MariaDB n’est pas appelée. But : pouvoir brancher la base plus tard sans réécrire les pages une deuxième fois.

Fichiers. `server/` nouveau, puis les pages qui lisent les fixtures, une page par petit pas si le diff grossit. On commence par la liste des séjours.

Dépendances. 1.2. Peut avancer sans 1.4.

Risque. Importer `server/` dans un composant qui tirerait un futur client SQL vers le navigateur. La première interface n’importe aucun driver.

Tests. Parcours connexion, enfants, dossier, fiche, documents, bureau. L’état en mémoire se vide encore au rechargement complet : c’est accepté tant que la base n’est pas le chemin par défaut.

Acceptation. Comportement visible identique à 1.2.

### Mission 1.7 — Hôtes, sans effet en local

Objectif. Préparer la distinction `www.thalie.eu` / `admin.thalie.org` sans rediriger `localhost`. `/bureau` ne bouge pas.

Fichiers. `middleware.ts` si la mission est acceptée.

Dépendances. Aucune technique forte. À faire après 1.1 pour limiter les diffs simultanés.

Tests. `localhost:3000` sert les mêmes pages. Un en-tête `Host` de test, en développement seulement, peut être journalisé. Pas de bascule DNS.

Acceptation. Aucune configuration Vercel modifiée par la mission.

## 3. Lot 2 — MariaDB sur des données fictives

Ces missions attendent un VPS ou une MariaDB locale et un accord séparé. Elles n’extraient rien.

- 2.1 Connexion depuis `server/` avec un compte applicatif sans droit de migration. Jeu fictif inséré par un script, la famille déjà dessinée dans la maquette, sans autre personne.
- 2.2 L’espace familles lit ce jeu. Le verrou de démonstration reste local tant que FileMaker n’est pas connecté.
- 2.3 Comptes : email, hash, drapeau de confirmation. Le mot de passe de la première étape de la maquette n’est plus jeté, ou l’écran cesse de le demander. Décision d’interface à prendre dans la mission, pas avant.
- 2.4 Fichiers d’essai hors de `public/`, téléchargement par une route authentifiée, avec un fichier fictif.

## 4. Lot 3 — réservation, encore sans prestataire

- 3.1 Créer une commande et des inscriptions en `place_bloquee` via le script de capacité.
- 3.2 Figer les lignes de prix, y compris aller et retour.
- 3.3 Échéances au niveau commande ou inscription, sans créer de trois fois J / J+30 / J+60 tant qu’Axepta ne l’a pas confirmé.
- 3.4 Ventiler un mouvement fictif sur deux inscriptions, vérifier la somme, et prévoir une écriture FileMaker distincte par ventilation, sans connecteur.
- 3.5 Historique d’un transfert sous les deux formes (même ligne, ou nouvelle ligne `transferee`), avec libération et nouveau blocage sans double compte.

Axepta, ANCV Connect et le remboursement réel sont un lot suivant, après la confirmation prestataire et la liste des motifs.

## 5. Lot 4 — sources externes

Chaque connecteur est une mission, dans l’ordre de `filemaker-sync-matrix.md` section 4, et seulement avec les rubriques fournies.

- FileMaker : identifiants, puis inscriptions, puis règlements, puis fichiers et statuts.
- OneDrive : factures en file d’attente si la clé n’est pas sûre.
- Oxatis : URL et historique, sans tunnel.
- PrestaShop : rattachement uniquement par identifiant déjà porté par FileMaker. Le reste en file `ambigu` ou `en_attente`.

Le sanitaire n’a pas de numéro de mission. Il commencera par un document de cadre, pas par une table.

## 6. Definition de fini pour une mission

- Le diff ne contient que les fichiers annoncés.
- Les tests listés ont été faits et leur résultat est rapporté.
- Aucun secret, aucun export client.
- La maquette fictive se parcourt encore de la connexion jusqu’au bureau.
- Une règle non tranchée dans la section 1 reste non codée.

## 7. Première mission recommandée

La mission 1.1. Elle corrige le défaut le plus concret du dépôt, ne demande aucune information manquante, et ne préjuge pas de FileMaker, d’Axepta ni du VPS.
