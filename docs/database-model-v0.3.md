# Modèle de données MariaDB v0.3

Référence Lot 1.0 — précisée le 3 novembre 2026.

Dictionnaire logique. Ce n’est pas une migration et ce fichier ne contient pas de script à exécuter.

Les décisions métier sont dans `architecture-thalie.md`. Les directions de synchro sont dans `filemaker-sync-matrix.md`. Les imports sont détaillés dans `migration-sources.md`.

## 1. Conventions

**Validé comme contrainte de portabilité :**

- Moteur InnoDB, base unique nommée `thalie`, caractères `utf8mb4`.
- Pas de schéma au sens PostgreSQL, pas de `search_path`, pas de `JSONB`, pas de `TIMESTAMPTZ`, pas de type `uuid` PostgreSQL, pas de `ON CONFLICT`, pas d’index unique partiel (`WHERE` sur un index).
- Clé primaire `CHAR(36)` : UUID produit par l’application, pas par une fonction propre à un autre moteur.
- Identifiant externe : `VARCHAR(64)` NULL. La forme réelle des identifiants FileMaker (nombre, texte) est **à vérifier**. 64 caractères est une largeur d’attente.
- Montants : `DECIMAL(10,2)`, devise EUR implicite. Une colonne `devise CHAR(3)` n’est ajoutée que si une devise autre qu’EUR apparaît. Ce n’est pas le cas aujourd’hui.
- Instants : `DATETIME(3)`, stockés en UTC. Dates de séjour et de naissance : `DATE`.
- Booléens : `TINYINT(1)`, 0 ou 1.
- Statuts : `VARCHAR` avec `CHECK`. MariaDB applique `CHECK` depuis la 10.2. **À vérifier** sur la version du VPS.
- Chaque table vivante a `cree_le` et `modifie_le` en `DATETIME(3)` NOT NULL, sauf mention.
- `ON DELETE RESTRICT` sur les liens métier. On ne supprime pas un séjour qui a des sessions, ni une session qui a des inscriptions.
- Les fichiers ne sont pas des `BLOB`.

**Hypothèse à confirmer sur le VPS (MariaDB ≥ 10.2) :** une colonne générée stockée, indexée par une contrainte d’unicité, reste vide quand la règle ne s’applique pas. Une unicité MariaDB accepte plusieurs valeurs vides. C’est le mécanisme retenu pour « une seule inscription active par enfant et par session », sans index unique partiel. Si la version du VPS ne le permet pas, le repli est un déclencheur à l’écriture qui rejette la deuxième ligne active. Le repli est aussi du MariaDB.

### Ce que MariaDB peut imposer

Sur une même instance, InnoDB impose notamment :

- les clés étrangères, y compris d’une base vers une table d’une autre base de cette instance ;
- l’unicité, y compris plusieurs vides dans une colonne unique ;
- les contraintes de domaine (`CHECK`), depuis MariaDB 10.2, **à vérifier** sur le VPS ;
- l’interdiction de supprimer une ligne encore référencée.

Une affirmation précédente de ce dossier disait que MariaDB ne permettait pas de clé étrangère entre bases. C’était inexact. Ce qui n’existe pas, c’est le schéma PostgreSQL (`search_path`, index unique partiel, `JSONB`). Dans MariaDB, `CREATE SCHEMA` désigne une base, pas un espace de noms dans une base.

### Ce que seule une transaction applicative peut garantir

Aucune clé étrangère n’exprime les points suivants. Ils sont contrôlés dans une transaction, au moment de l’écriture :

- la somme des ventilations égale le montant du mouvement ;
- la prise de place, la baisse de capacité et la hausse de `reel_estime` se font dans le même geste que le contrôle de la disponibilité commerciale ;
- le sens du transport choisi est bien `aller` ou bien `retour` (l’appartenance du transport à la session, elle, est une clé étrangère) ;
- une décision de validation sur une pièce famille a pour origine FileMaker ;
- un bloc de contenu pointe vers un centre ou un séjour qui existe (la cible est de deux tables possibles, ce qu’une seule clé étrangère ne couvre pas).

## 2. Identifiants externes

Une seule table porte les identifiants hors MariaDB. Les tables métier ne dupliquent pas `id_filemaker`.

`identifiants_externes`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| systeme | VARCHAR(32) | NOT NULL. Valeurs : `filemaker`, plus tard `polymnie`, `oxatis`, `prestashop` |
| entite | VARCHAR(32) | NOT NULL. Voir liste plus bas |
| id_local | CHAR(36) | NOT NULL |
| id_externe | VARCHAR(64) | NOT NULL |
| cree_le | DATETIME(3) | NOT NULL |

Unique `(systeme, entite, id_externe)`. Unique `(systeme, entite, id_local)`.

Entités prévues : `centre`, `sejour`, `session`, `famille`, `enfant`, `inscription`, `mouvement`, `ventilation`, `piece`, `document_publie`, `facture`.

Pas d’entité `adulte` tant que FileMaker n’a pas d’adulte autonome. **À vérifier.**

Un identifiant n’est écrit ici qu’après un rapprochement sûr ou une création acquittée par le système externe. Un import ambigu n’écrit pas dans cette table.

## 3. Catalogue

Le catalogue est du contenu métier, éditable par l’équipe dans l’admin, sans livraison de code. Aucune colonne ne porte une couleur, une police, une grille ou une direction graphique. La charte reste dans les feuilles de style.

`centres` — fiche indépendante, unique par lieu, modifiable.

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| nom | VARCHAR(200) | NOT NULL |
| adresse | TEXT | NULL |
| slug | VARCHAR(200) | NOT NULL, unique. URL stable du centre |

Le nom n’est pas unique : deux lieux peuvent porter un libellé proche. L’identité est `id`. L’adresse est une donnée. Les textes longs sont des contenus éditables, pas des colonnes figées.

`categories` : `id`, `libelle` VARCHAR(200) NOT NULL, `slug` VARCHAR(200) NOT NULL unique, `parent_id` CHAR(36) NULL, clé étrangère vers `categories`. Une catégorie peut en contenir d’autres. La liste réelle des catégories du site est **à vérifier**. Aucun libellé n’est inventé ici.

`sejour_categories` : `sejour_id`, `categorie_id`, clé primaire composée. Un séjour a plusieurs catégories. Une catégorie regroupe plusieurs séjours.

`disciplines` : `id`, `libelle` VARCHAR(120) NOT NULL unique, `slug` VARCHAR(200) NOT NULL unique. Les disciplines ne sont pas des catégories : les deux existent côte à côte.

`sejours`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| centre_id | CHAR(36) | NOT NULL, FK `centres` |
| titre | VARCHAR(200) | NOT NULL |
| slug | VARCHAR(200) | NOT NULL, unique. URL stable du séjour |
| age_min | TINYINT | NULL |
| age_max | TINYINT | NULL |
| publie | TINYINT(1) | NOT NULL, défaut 0 |

Index `(centre_id)`. Le programme est commun aux sessions. Il vit dans `contenus_editoriaux`, pour que l’équipe le modifie sans déploiement. Unique `(id, centre_id)` afin qu’une session puisse référencer le couple séjour-centre.

`sejour_disciplines` : `sejour_id` FK, `discipline_id` FK. Clé primaire composée.

`contenus_editoriaux`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| cible_type | VARCHAR(16) | NOT NULL. `centre` ou `sejour` |
| cible_id | CHAR(36) | NOT NULL |
| code | VARCHAR(64) | NOT NULL |
| corps | TEXT | NOT NULL |
| ordre | INT | NOT NULL |
| publie | TINYINT(1) | NOT NULL, défaut 0 |

Codes initiaux, **hypothèse de départ, extensibles sans changer le schéma** : pour un centre, `description` et `equipements` ; pour un séjour, `description_commerciale`, `programme`, `infos_pratiques`. L’équipe peut ajouter un code. L’unicité `(cible_type, cible_id, code, ordre)` est contrôlée dans la transaction : une clé étrangère unique ne peut pas viser à la fois `centres` et `sejours`. La transaction vérifie aussi que `cible_id` existe dans la table annoncée par `cible_type`.

`medias` — photographies et autres médias des fiches centre et séjour. Remplace d’anciennes tables de photos séparées.

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| cible_type | VARCHAR(16) | NOT NULL. `centre` ou `sejour` |
| cible_id | CHAR(36) | NOT NULL |
| nature | VARCHAR(16) | NOT NULL. `photo`, `video`, `autre` |
| cle_stockage | VARCHAR(500) | NOT NULL. Référence de fichier, hors de `public/` |
| texte_alternatif | VARCHAR(300) | NULL |
| legende | VARCHAR(200) | NULL |
| ordre | INT | NOT NULL |

Même contrôle de cible que les contenus. `texte_alternatif` sert le référencement et l’accessibilité. Ce n’est pas une consigne graphique.

`referencement` — métadonnées SEO des URL stables.

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| cible_type | VARCHAR(16) | NOT NULL. `centre`, `sejour`, `categorie` |
| cible_id | CHAR(36) | NOT NULL |
| titre | VARCHAR(200) | NULL. Titre de page, distinct du titre métier si besoin |
| description | VARCHAR(300) | NULL |

Unique `(cible_type, cible_id)`. Le slug stable reste sur la fiche (`centres.slug`, `sejours.slug`, `categories.slug`). Changer un slug écrit une ligne dans `redirections` et ne réutilise pas l’ancien chemin.

`redirections`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| ancienne_url | VARCHAR(500) | NOT NULL, unique |
| url_cible | VARCHAR(500) | NOT NULL |
| source | VARCHAR(16) | NOT NULL. `oxatis` ou `interne` |
| code_http | SMALLINT | NOT NULL, défaut 301 |

Une URL Oxatis n’est insérée ici qu’après rapprochement sûr avec une fiche, selon `migration-sources.md`. Une URL absente de l’export n’est pas inventée.

`sessions`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| sejour_id | CHAR(36) | NOT NULL, FK `sejours` |
| debut | DATE | NOT NULL |
| fin | DATE | NOT NULL |
| capacite | INT | NOT NULL, au moins 0 |
| places_bloquees | INT | NOT NULL, défaut 0, au moins 0 |
| places_confirmees | INT | NOT NULL, défaut 0, au moins 0 |
| places_liberees | INT | NOT NULL, défaut 0, au moins 0. Cumul historique, ne revient pas dans le stock |
| statut_commercial | VARCHAR(32) | NOT NULL. `brouillon`, `ouverte`, `fermee`, `annulee` |

Index `(sejour_id, debut)`. Unique `(id, sejour_id)` pour la cohérence avec l’inscription. Les sessions passées restent. Aucune suppression automatique.

`places_bloquees` et `places_confirmees` ne comptent que les inscriptions actives sans contingent. Confirmer en déplace 1 sans changer leur somme. Libérer retire 1 du compteur concerné et ajoute 1 à `places_liberees`. Une session dont `fin` est passée n’est pas laissée `ouverte`.

La disponibilité commerciale est `capacite`, moins cette somme hors contingent, moins la somme des places bloquées par les contingents de la session. Le blocage d’un contingent est décrit à la section 6. Il inclut déjà ses inscriptions réalisées.

Une contrainte de domaine peut rappeler que cette disponibilité n’est pas négative. Elle ne suffit pas sous deux réservations simultanées, ni quand on baisse `capacite` ou qu’on monte `reel_estime`. Ces gestes sont des transactions. Rejouer la même clé ne compte pas une deuxième fois.

**Règle de disponibilité appliquée :** une nouvelle inscription hors contingent est refusée quand la disponibilité commerciale est à zéro. Le chevauchement de dates entre deux sessions d’un même enfant n’est pas une règle posée.

## 4. Personnes

`familles` : `id`, `responsable_administratif_id` CHAR(36) NULL.

`familles` et `adultes` se référencent l’un l’autre. On crée les deux tables, puis on ajoute la clé étrangère du responsable. MariaDB n’accepte pas ce cycle dans un seul `CREATE` simultané.

`adultes`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| famille_id | CHAR(36) | NOT NULL, FK `familles` |
| prenom | VARCHAR(120) | NOT NULL |
| nom | VARCHAR(120) | NOT NULL |
| email | VARCHAR(254) | NULL |
| telephone | VARCHAR(40) | NULL |

Unique `(id, famille_id)` pour permettre la clé étrangère composée ci-dessous.

`familles.responsable_administratif_id` est au plus un adulte. La clé étrangère `(responsable_administratif_id, id)` référence `adultes(id, famille_id)` : le responsable appartient à cette famille. La colonne est NULL pendant un import incomplet. Elle est renseignée avant qu’une commande puisse être payée. C’est une colonne unique par famille, pas un index partiel. **Validé :** un seul responsable administratif.

`comptes`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| adulte_id | CHAR(36) | NOT NULL, unique, FK `adultes` |
| email | VARCHAR(254) | NOT NULL, unique |
| mot_de_passe_hash | VARCHAR(255) | NULL tant que le compte n’est pas activé |
| email_confirme_le | DATETIME(3) | NULL |

**Validé :** un compte personnel par adulte. Le hash n’est jamais un mot de passe en clair.

`enfants`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| famille_id | CHAR(36) | NOT NULL, FK `familles` |
| prenom | VARCHAR(120) | NOT NULL |
| nom | VARCHAR(120) | NOT NULL |
| naissance | DATE | NULL |
| naissance_incomplete | TINYINT(1) | NOT NULL, défaut 0 |
| sexe | VARCHAR(16) | NULL |

Index `(famille_id)`. Unicité `(id, famille_id)`, pour la clé étrangère composée de l’inscription.

**Validé :** un enfant, une famille. Un changement de famille est un `UPDATE` journalisé, pas une deuxième fiche.

**Règle :** toute création nouvelle sur le site exige `naissance`. Un import historique sans date met `naissance` NULL et `naissance_incomplete` à 1, et bloque une nouvelle réservation pour cet enfant tant que la date manque. Ceci reprend la règle métier déjà posée pour le modèle réel, avec une porte d’entrée pour l’historique.

## 5. Commandes et inscriptions

`commandes`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| famille_id | CHAR(36) | NOT NULL, FK |
| adulte_id | CHAR(36) | NOT NULL, FK. L’adulte qui passe la commande |
| statut | VARCHAR(32) | `CHECK` dans `brouillon`, `enregistree`, `annulee` |

Le statut de la commande ne remplace pas les trois statuts de l’inscription. **Hypothèse** sur ces trois valeurs de commande : à confirmer au moment du tunnel. Unicité `(id, famille_id)`, pour la clé étrangère composée de l’inscription.

`inscriptions`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| commande_id | CHAR(36) | NOT NULL, FK `commandes` |
| famille_id | CHAR(36) | NOT NULL |
| enfant_id | CHAR(36) | NOT NULL, FK `enfants` |
| sejour_id | CHAR(36) | NOT NULL |
| session_id | CHAR(36) | NOT NULL, FK `sessions` |
| inscription_origine_id | CHAR(36) | NULL, FK `inscriptions`. Renseigné si une nouvelle ligne prolonge un transfert |
| statut_administratif | VARCHAR(32) | NOT NULL |
| statut_financier | VARCHAR(32) | NOT NULL |
| statut_documentaire | VARCHAR(32) | NOT NULL |
| transport_aller_id | CHAR(36) | NULL |
| transport_retour_id | CHAR(36) | NULL |
| contingent_id | CHAR(36) | NULL, FK `contingents`. Renseigné quand l’inscription est celle d’un partenaire |
| motif_refus | VARCHAR(500) | NULL |
| active_enfant_session | VARCHAR(73) | Colonne générée, voir plus bas |

`statut_administratif` : `place_bloquee`, `confirmee`, `refusee`, `annulee`, `transferee`.

`statut_financier` — **vocabulaire de travail, à confirmer** : `aucun`, `acompte`, `solde`, `trop_percu`, `remboursement_partiel`, `rembourse`.

`statut_documentaire` — **vocabulaire de travail issu du flux validé** : `manquant`, `depose`, `copie_en_echec`, `en_validation`, `a_corriger`, `valide`.

Ce statut résume les `pieces` de l’inscription. On ne l’écrit pas en parallèle. `valide` signifie que chaque exigence applicable dont `bloque_convocation` vaut 1 a une pièce `valide`. Si les pièces d’une même inscription ne sont pas au même palier, la priorité exacte est **à vérifier** avec les statuts réels renvoyés par FileMaker.

Il n’existe pas de contrainte d’unicité sur le couple `(enfant_id, session_id)`. Une annulation laisse la ligne. Une nouvelle inscription active du même enfant sur la même session reste possible.

`active_enfant_session` est une colonne générée stockée. Elle contient une clé enfant-session lorsque le statut est `place_bloquee` ou `confirmee`, et elle est vide sinon. L’unicité porte sur cette colonne. Plusieurs vides sont acceptés : les lignes annulées, refusées ou transférées s’accumulent. Deux inscriptions actives du même enfant sur la même session sont rejetées.

Cohérence imposée par des clés étrangères composées, donc par MariaDB :

- `(enfant_id, famille_id)` référence `enfants(id, famille_id)` : l’enfant appartient à la famille de la ligne ;
- `(commande_id, famille_id)` référence `commandes(id, famille_id)` : la commande est celle de cette même famille ;
- `(session_id, sejour_id)` référence `sessions(id, sejour_id)` : la session appartient à ce séjour.

`enfants` porte une unicité `(id, famille_id)`, `commandes` une unicité `(id, famille_id)`, `sessions` une unicité `(id, sejour_id)`. Ces unicités ne changent pas l’identité : `id` reste la clé primaire. Elles existent pour que la clé étrangère composée puisse s’appuyer dessus.

Cohérence du transport : `session_transports` porte une unicité `(id, session_id)`. `(transport_aller_id, session_id)` et `(transport_retour_id, session_id)` référencent cette unicité. Le transport choisi appartient donc à la session. Le contrôle du sens (`aller` sur la colonne aller, `retour` sur la colonne retour) reste dans la transaction applicative.

Cohérence du contingent : `contingents` porte une unicité `(id, session_id)`. `(contingent_id, session_id)` la référence. L’inscription rattachée vise donc un contingent de sa propre session. Une inscription active avec `contingent_id` compte dans `realise` et pas dans les compteurs hors contingent.

Index ordinaires : `(commande_id)`, `(enfant_id)`, `(session_id)`, `(statut_administratif)`.

`inscription_evenements`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| inscription_id | CHAR(36) | NOT NULL, FK |
| type | VARCHAR(32) | NOT NULL. Exemples : `creation`, `confirmation`, `refus`, `annulation`, `transfert`, `changement_session`, `synchro` |
| source | VARCHAR(32) | NOT NULL. `site`, `filemaker`, `admin` |
| resume | VARCHAR(500) | NOT NULL |
| details_json | JSON | NULL. Type JSON MariaDB, pas JSONB |
| cle_idempotence | VARCHAR(128) | NULL, unique |

L’historique n’est pas réécrit. Un transfert in-place met à jour `session_id` et ajoute un événement. Un transfert qui crée une nouvelle inscription FileMaker laisse l’ancienne en `transferee` et pointe `inscription_origine_id`.

## 6. Capacité et contingents

`segments_clients` : `id`, `code` VARCHAR(64) NOT NULL unique, `libelle` VARCHAR(200) NOT NULL. Les codes réels des CSE et des collectivités sont **à vérifier**. Aucun nom de partenaire n’est inscrit ici.

`contingents` — **validé.** Compris dans la capacité de la session. Une ligne par partenaire et par session.

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| session_id | CHAR(36) | NOT NULL, FK |
| segment_id | CHAR(36) | NOT NULL, FK `segments_clients` |
| options_posees | INT | NOT NULL, au moins 0. Options initiales du partenaire, suivi commercial seulement |
| reel_estime | INT | NOT NULL, au moins 0. Effectif que Thalie estime devoir attendre |
| realise | INT | NOT NULL, défaut 0, au moins 0. Inscriptions actives rattachées |
| places_bloquees | INT | NOT NULL. Résultat tenu à jour, égal au plus grand de `reel_estime` et `realise`. Pas une saisie |

Unique `(session_id, segment_id)`. Unique `(id, session_id)` pour l’inscription.

`options_posees` ne retire aucune place. `places_bloquees` vaut `MAX(reel_estime, realise)`. Le réalisé y est inclus. Les mêmes enfants ne figurent pas dans `sessions.places_bloquees` ni dans `sessions.places_confirmees`.

Exemple validé, sans autre réservation : capacité 30, options 12, réel estimé 7, réalisé 5. Blocage du contingent : 7. Disponibilité hors CSE : 23.

Baisser `reel_estime` peut augmenter la disponibilité, sans descendre le blocage sous `realise`. Monter `reel_estime`, ou voir `realise` dépasser `reel_estime`, n’est accepté que si la disponibilité commerciale couvre la hausse, dans la même transaction que la lecture de la capacité.

`realise` suit les inscriptions actives (`place_bloquee` ou `confirmee`) dont `contingent_id` est cette ligne. Confirmer l’une d’elles ne change pas `realise`. L’annuler le diminue. Ce n’est pas un compteur saisi à la main.

`historique_contingents` — chaque modification.

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| contingent_id | CHAR(36) | NOT NULL, FK |
| champ | VARCHAR(32) | NOT NULL. `options_posees`, `reel_estime` ou `realise` |
| valeur_avant | INT | NOT NULL |
| valeur_apres | INT | NOT NULL |
| places_bloquees_apres | INT | NOT NULL |
| source | VARCHAR(32) | NOT NULL. `site`, `filemaker` ou `admin` |
| cle_idempotence | VARCHAR(128) | NOT NULL, unique |

L’historique n’est pas réécrit. Rejouer la même clé ne crée pas une deuxième ligne et ne change pas les compteurs.

`suivi_places`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| session_id | CHAR(36) | NOT NULL, FK |
| contingent_id | CHAR(36) | NULL, FK `contingents` |
| inscription_id | CHAR(36) | NOT NULL, FK |
| effet | VARCHAR(16) | NOT NULL. `blocage`, `confirmation`, `liberation` |
| cle_idempotence | VARCHAR(128) | NOT NULL, unique |

Chaque blocage, confirmation ou libération hors contingent laisse une ligne. La confirmation ne crée pas un second blocage. Une inscription FileMaker déjà rattachée à un contingent n’écrit pas ici : elle alimente `realise`. Tant qu’elle n’est pas rattachée, elle tient une place hors contingent. Le rattachement, dans une seule transaction, retire cette place et augmente `realise`. Le blocage du contingent devient le plus grand des deux nombres, sans compter l’enfant deux fois. La rubrique FileMaker qui identifie le partenaire est **à vérifier**.

Une modification de `capacite` se fait dans la même transaction que la lecture de la disponibilité. Elle est refusée si la nouvelle capacité ne couvre plus les places hors contingent et les blocages de contingents.

## 7. Tarifs et transports

`tarifs`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| sejour_id | CHAR(36) | NULL, FK |
| session_id | CHAR(36) | NULL, FK |
| segment_id | CHAR(36) | NULL, FK. NULL = tarif ouvert à tous |
| montant | DECIMAL(10,2) | NOT NULL |
| valide_du | DATE | NOT NULL |
| valide_au | DATE | NULL |

`CHECK (sejour_id IS NOT NULL OR session_id IS NOT NULL)`.

Index `(session_id, segment_id, valide_du)`, `(sejour_id, segment_id, valide_du)`.

Cette table est le catalogue. Elle peut changer. Elle n’est pas la vente.

`points_transport` : `id`, `libelle` VARCHAR(200) NOT NULL, `precision_lieu` VARCHAR(300) NULL.

`session_transports`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| session_id | CHAR(36) | NOT NULL, FK |
| point_id | CHAR(36) | NOT NULL, FK |
| sens | VARCHAR(16) | NOT NULL, `CHECK` dans `aller`, `retour` |
| montant | DECIMAL(10,2) | NOT NULL |

Unique `(session_id, point_id, sens)`. Unique `(id, session_id)` pour la clé étrangère de l’inscription. Aller et retour sont deux lignes.

`inscription_prix_lignes`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| inscription_id | CHAR(36) | NOT NULL, FK |
| code | VARCHAR(32) | NOT NULL. `sejour`, `transport_aller`, `transport_retour`, `autre` |
| libelle | VARCHAR(200) | NOT NULL |
| montant | DECIMAL(10,2) | NOT NULL |
| tarif_id | CHAR(36) | NULL, FK `tarifs`. NULL si la ligne ne vient pas d’une grille |
| ordre | INT | NOT NULL |
| fige_le | DATETIME(3) | NOT NULL |

Unique `(inscription_id, code, ordre)`.

**Validé :** ces lignes sont la vente. Un changement de `tarifs` ou de `session_transports` ne les met pas à jour. L’application ne propose pas d’`UPDATE` sur cette table. **Hypothèse d’enforcement :** trigger `BEFORE UPDATE` qui rejette la modification, et trigger `BEFORE DELETE` qui la rejette aussi. Une correction exceptionnelle serait une nouvelle ligne d’avoir, pas un écrasement. La forme de cet avoir est **à vérifier** avec la comptabilité.

## 8. Paiements

`echeances` — au niveau de la commande ou de l’inscription, selon la règle de paiement de cette vente. Laquelle des deux s’applique à quel cas est **à vérifier**. Le schéma les autorise toutes les deux. Il n’en choisit pas une par défaut.

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| commande_id | CHAR(36) | NULL, FK `commandes` |
| inscription_id | CHAR(36) | NULL, FK `inscriptions` |
| echeance_le | DATE | NOT NULL |
| montant | DECIMAL(10,2) | NOT NULL |
| mode | VARCHAR(32) | NOT NULL |
| rang | TINYINT | NOT NULL |

Exactement une des deux colonnes `commande_id` et `inscription_id` est renseignée. MariaDB peut l’imposer par une contrainte de domaine.

`mode` : `cb_comptant`, `cb_3_fois`, `cheque`, `virement`, `ancv_papier`, `ancv_connect`.

Le métier souhaite un paiement en trois fois à J, J+30 et J+60. **Ce calendrier n’est pas une capacité acquise du contrat Axepta.** Tant qu’Axepta ne l’a pas confirmé, on ne crée pas ces trois échéances et on n’appelle pas le prestataire pour ce mode. Le mode reste nommé pour ne pas le redessiner plus tard. Monetico n’est pas intégré.

`transactions_bancaires`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| commande_id | CHAR(36) | NOT NULL, FK |
| prestataire | VARCHAR(32) | NOT NULL. `axepta` pour la CB |
| reference_prestataire | VARCHAR(128) | NOT NULL |
| type | VARCHAR(32) | NOT NULL. `autorisation`, `capture`, `refus`, `remboursement` |
| montant | DECIMAL(10,2) | NOT NULL |
| statut | VARCHAR(32) | NOT NULL |
| resume | VARCHAR(500) | NULL. Jamais de numéro de carte, jamais de payload brut secret |

Unique `(prestataire, reference_prestataire, type)`. Un webhook rejoué retombe sur cette clé et ne crée pas une deuxième transaction.

Chèque, virement et ANCV papier n’ont pas de ligne ici.

`mouvements`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| commande_id | CHAR(36) | NOT NULL, FK |
| transaction_bancaire_id | CHAR(36) | NULL, FK |
| sens | VARCHAR(16) | NOT NULL, `CHECK` dans `encaissement`, `remboursement` |
| mode | VARCHAR(32) | NOT NULL, même liste que les échéances |
| montant | DECIMAL(10,2) | NOT NULL, `CHECK (montant > 0)` |
| date_valeur | DATE | NOT NULL |
| reference | VARCHAR(128) | NULL. Numéro de chèque, libellé de virement, référence ANCV |
| cle_idempotence | VARCHAR(128) | NOT NULL, unique |

`ventilations`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| mouvement_id | CHAR(36) | NOT NULL, FK |
| inscription_id | CHAR(36) | NOT NULL, FK |
| montant | DECIMAL(10,2) | NOT NULL, `CHECK (montant > 0)` |

Index `(mouvement_id)`, `(inscription_id)`.

**Invariant, contrôlé dans la transaction applicative :** la somme des ventilations d’un mouvement égale le montant du mouvement. Chaque ventilation est strictement positive et ne dépasse pas ce montant. MariaDB ne porte pas cette somme par une clé étrangère. Un mouvement issu de FileMaker a exactement une ventilation, parce que FileMaker a un règlement distinct par inscription. Un mouvement né sur le site peut en avoir plusieurs : un paiement unique ventilé. Chaque ventilation devient une écriture FileMaker distincte. Le lien FileMaker est `identifiants_externes` sur l’entité `ventilation`, pas sur la transaction bancaire.

Un remboursement CB crée une transaction bancaire de type `remboursement`, un mouvement de sens `remboursement`, puis les ventilations, puis les écritures FileMaker correspondantes. Le site initie l’appel Axepta seulement après une décision du bureau. Un refus payé n’ouvre pas cet appel tout seul.

## 9. Documents

`types_pieces` — le catalogue des natures de pièces. Anciennement décrit comme `regles_pieces`. Le nom change pour distinguer le type, qui est stable, de l’exigence, qui dépend du séjour ou de la session.

| Colonne | Type | Contrainte |
| --- | --- | --- |
| type | VARCHAR(32) | PK |
| libelle | VARCHAR(120) | NOT NULL |
| autorise_declaration | TINYINT(1) | NOT NULL. 1 si un texte peut remplacer le fichier |

Natures connues de la maquette : `fiche_sanitaire`, `droit_image`, `regime`, `vaccination`, `secu`, `mutuelle`, `ordonnance`, `pai`, `pass_nautique`.

`exigences_documentaires` — configurables par séjour ou par session, sans redéploiement.

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| type | VARCHAR(32) | NOT NULL, FK `types_pieces` |
| sejour_id | CHAR(36) | NULL, FK `sejours` |
| session_id | CHAR(36) | NULL, FK `sessions` |
| obligatoire | TINYINT(1) | NOT NULL |
| bloque_convocation | TINYINT(1) | NOT NULL |

Les deux rattachements peuvent être vides : c’est alors le défaut pour tous les séjours. **Hypothèse de résolution, à confirmer :** une exigence de session l’emporte sur celle du séjour, qui l’emporte sur le défaut. Si `session_id` est renseigné, la transaction vérifie que cette session appartient au `sejour_id` quand celui-ci l’est aussi.

Jeu initial issu de la maquette, modifiable par l’équipe. Il ne fige pas les séjours nautiques : on ne sait pas encore lesquels portent un pass.

| type | portée du défaut | obligatoire | bloque la convocation | déclaration possible |
| --- | --- | --- | --- | --- |
| fiche_sanitaire | tous | 1 | 1 | non |
| droit_image | tous | 1 | 1 | non |
| regime | tous | 1 | 1 | non |
| vaccination | tous | 1 | 1 | non |
| secu | tous | 1 | 1 | oui, refus du justificatif |
| pai | tous | 0 | 0 | oui, pas de PAI |
| ordonnance | tous | 0 | 0 | oui, aucun traitement |
| mutuelle | tous | 0 | 0 | oui, refus du justificatif |
| pass_nautique | aucun défaut global | 0 | 0 | non |

Le pass nautique n’est pas demandé partout. Une exigence de séjour ou de session le rend obligatoire pour les séjours nautiques seulement. Quels séjours sont nautiques est **à vérifier**. On n’en marque aucun ici.

Textes de déclaration déjà fixés par la maquette, conservés :

- PAI : « Mon enfant n’a pas de PAI ».
- Ordonnance : aucun traitement ne sera pris pendant le séjour, y compris sans ordonnance (paracétamol, Spasfon, etc.).
- Sécu et mutuelle, en cas de refus : « Je reconnais qu’en refusant de téléverser ce document, cela pourra amener Thalie à avancer des frais médicaux sur place, qu’il vous faudra rembourser en échange des feuilles de soins et des factures. »

`pieces`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| inscription_id | CHAR(36) | NOT NULL, FK |
| type | VARCHAR(32) | NOT NULL, FK `types_pieces` |
| statut | VARCHAR(32) | NOT NULL, même vocabulaire que `statut_documentaire` |
| verrouille_le | DATETIME(3) | NULL. Renseigné seulement par une décision FileMaker de validation |

Index `(inscription_id, type)`. Pas d’unicité : une pièce à corriger peut être suivie d’une nouvelle version. Une pièce validée ne reçoit plus de fichier ni de déclaration.

`fichiers` — versions conservées.

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| piece_id | CHAR(36) | NOT NULL, FK |
| numero_version | INT | NOT NULL |
| cle_stockage | VARCHAR(500) | NOT NULL. Hors de `public/` |
| nom_original | VARCHAR(255) | NOT NULL |

Unique `(piece_id, numero_version)`. On n’efface pas une version précédente.

`declarations_pieces`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| piece_id | CHAR(36) | NOT NULL, FK |
| code | VARCHAR(32) | NOT NULL. `pas_de_pai`, `aucun_traitement`, `refus_justificatif` |
| texte_accepte | VARCHAR(1000) | NOT NULL. Le texte montré au parent |
| accepte_le | DATETIME(3) | NOT NULL |

La transaction refuse une déclaration si le type de pièce n’a pas `autorise_declaration`. Un fichier et une déclaration ne s’effacent pas l’un l’autre : chacun reste dans l’historique.

`decisions_pieces` — historique des décisions. La validation des pièces familles vient exclusivement de FileMaker. L’admin du site ne peut pas y écrire une validation.

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| piece_id | CHAR(36) | NOT NULL, FK |
| decision | VARCHAR(32) | NOT NULL. `valide` ou `a_corriger` |
| motif | VARCHAR(500) | NULL |
| cree_le | DATETIME(3) | NOT NULL |

`demandes_attestations` : `id`, `inscription_id` FK, `statut` parmi `demandee`, `traitee`. Index `(inscription_id, statut)`. Pas d’unicité définitive : **à vérifier** si une deuxième demande est autorisée après traitement. En attendant, l’application ignore un second clic tant qu’une ligne `demandee` existe, comme la maquette.

`documents_publies` — déposés depuis l’admin. Chaque document a une référence de fichier. Il est rattaché à un seul niveau, selon sa nature : centre, séjour, session ou inscription.

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| type | VARCHAR(32) | NOT NULL |
| centre_id | CHAR(36) | NULL, FK |
| sejour_id | CHAR(36) | NULL, FK |
| session_id | CHAR(36) | NULL, FK |
| inscription_id | CHAR(36) | NULL, FK |
| cle_stockage | VARCHAR(500) | NOT NULL |
| visible | TINYINT(1) | NOT NULL, défaut 0 |

Exactement un des quatre rattachements est renseigné. MariaDB peut l’imposer par une contrainte de domaine. Natures connues de la maquette, et portée observée : trousseau et lettre du séjour au niveau du séjour ; convocation transport au niveau du séjour. Une pièce de centre ou une pièce limitée à une inscription sont possibles. La portée exacte de chaque nature au-delà de la maquette est **à vérifier**.

`versions_documents_publies` : `id`, `document_id` FK, `numero_version` INT NOT NULL, `cle_stockage` VARCHAR(500) NOT NULL. Unique `(document_id, numero_version)`. Remplacer un fichier publié conserve l’ancienne référence.

La convocation n’est montrée à une famille que si le document est visible et si, pour cette inscription, chaque exigence applicable dont `bloque_convocation` vaut 1 est validée dans FileMaker.

`factures` — une facture FileMaker n’est pas forcément une commande web.

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| reference_facturation | VARCHAR(128) | NULL. Référence de facturation FileMaker, distincte de l’identifiant technique |
| origine | VARCHAR(32) | NOT NULL. `web`, `historique`, `institutionnelle` |
| commande_id | CHAR(36) | NULL, FK `commandes`. Renseigné seulement si un rapprochement sûr lie la facture à une commande du site |
| famille_id | CHAR(36) | NULL, FK `familles`. Utile pour une facture historique sans commande web |
| cle_onedrive | VARCHAR(200) | NULL, unique. Plusieurs vides restent possibles |
| cle_stockage | VARCHAR(500) | NULL |
| statut | VARCHAR(32) | NOT NULL. `en_attente_rapprochement`, `rattachee`, `rejetee` |

L’identifiant technique FileMaker, quand il est connu, va dans `identifiants_externes` (`entite = facture`). On ne suppose pas qu’il est identique à `reference_facturation`. L’unicité de la référence de facturation est **à vérifier** : elle n’est pas imposée tant que ce point n’est pas connu.

`facture_inscriptions` : `facture_id`, `inscription_id`, clé primaire composée. Une facture peut viser une inscription, plusieurs, ou aucune tant qu’elle n’est pas rapprochée. Une facture institutionnelle peut rester sans commande web. Une facture historique aussi.

Rapprochement OneDrive : `commande_id`, `famille_id` ou des lignes `facture_inscriptions` ne sont écrits que si une clé relie la facture sans ambiguïté. Sinon le statut reste `en_attente_rapprochement`. Aucun rattachement par nom de famille seul. Un second passage sur la même `cle_onedrive` ne crée pas une deuxième facture.

## 10. Journal, conflits, imports

`journal_sync`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| cle_idempotence | VARCHAR(128) | NOT NULL, unique |
| direction | VARCHAR(32) | NOT NULL, `CHECK` dans `vers_filemaker`, `vers_site`, `vers_onedrive` |
| entite | VARCHAR(32) | NOT NULL |
| id_local | CHAR(36) | NULL |
| statut | VARCHAR(32) | NOT NULL, `CHECK` dans `en_attente`, `envoye`, `acquitte`, `erreur`, `a_rejouer` |
| tentative | INT | NOT NULL, défaut 0 |
| derniere_erreur | VARCHAR(500) | NULL |
| acquitte_le | DATETIME(3) | NULL |

Rejouer une clé déjà `acquitte` est un succès vide. Une erreur FileMaker passe la ligne en `a_rejouer` sans annuler la transaction métier déjà commitée.

`conflits`

| Colonne | Type | Contrainte |
| --- | --- | --- |
| id | CHAR(36) | PK |
| entite | VARCHAR(32) | NOT NULL |
| id_local | CHAR(36) | NOT NULL |
| champ | VARCHAR(64) | NOT NULL |
| valeur_site | TEXT | NULL |
| valeur_filemaker | TEXT | NULL |
| resolu_le | DATETIME(3) | NULL |
| resolu_par | CHAR(36) | NULL, FK `comptes` |

Index `(entite, id_local, resolu_le)`.

Tables d’import, sans clé étrangère vers les tables vivantes. `id_cible` CHAR(36) NULL est une note après décision humaine, pas une FK. `statut_rapprochement` : `importe`, `en_attente`, `rapproche`, `ambigu`, `rejete`. Une ligne `ambigu` ne passe jamais seule à `rapproche`.

- `import_filemaker_familles`
- `import_filemaker_enfants`
- `import_filemaker_inscriptions`
- `import_filemaker_reglements`
- `import_filemaker_documents`
- `import_oxatis_produits`
- `import_oxatis_commandes`
- `import_oxatis_lignes`
- `import_oxatis_urls`
- `import_prestashop_clients`
- `import_prestashop_documents`

Colonnes communes : `id`, `id_externe` VARCHAR(64) NULL, `payload_json` JSON NOT NULL, `statut_rapprochement`, `id_cible` NULL, `motif` VARCHAR(500) NULL, `cree_le`.

`payload_json` conserve la ligne brute. Aucune rubrique FileMaker n’est promue en colonne tant que son nom n’est pas connu. `id_externe` reçoit l’identifiant stable quand le mapping a été fourni, pas avant.

## 11. Données sanitaires

Aucune table sanitaire dans v0.3. Elles ne font pas partie des premières migrations.

Le jour où le cadre de conservation et de sécurité sera validé, une autre base MariaDB sur la même instance pourra recevoir le questionnaire. InnoDB sait relier deux bases de la même instance par une clé étrangère. S’en servir ou non sera une décision de cloisonnement, pas une limite du moteur. Cette base n’est pas créée maintenant, et aucune table sanitaire ne figure dans ce dictionnaire.

L’inventaire des questions existe déjà dans la maquette (`FicheAnswers` dans `lib/generateFiche.ts`). Il sert de liste fonctionnelle. Il n’est pas recopié ici en colonnes, pour ne pas devenir un modèle qu’on crée par erreur.

## 12. Index utiles en plus des uniques

- `sessions(sejour_id, debut)` pour le catalogue.
- `inscriptions(session_id, statut_administratif)` pour les places et le bureau.
- `suivi_places(session_id, effet)` pour le suivi des places hors contingent.
- `inscriptions(contingent_id)` et `historique_contingents(contingent_id, cree_le)` pour le réalisé et l’historique CSE.
- `journal_sync(statut, cree_le)` pour la reprise.
- `factures(statut)`, `factures(reference_facturation)` pour la file et la référence FileMaker.
- `redirections(ancienne_url)` est déjà unique.
- `conflits(resolu_le)` pour l’admin.

Les index définitifs se caleront sur les requêtes réelles. Ceux-ci couvrent les accès déjà connus.
