# Architecture Thalie

Référence Lot 1.0 — précisée le 3 novembre 2026.

Ce document fixe l’architecture cible. Il ne décrit pas un code déjà écrit : le dépôt `docsthalie` reste une maquette Next.js de l’espace familles, sans base et sans serveur métier.

Légende utilisée dans les cinq documents :

- **Validé** — décision actée.
- **Hypothèse** — choix technique proposé, réversible tant qu’il n’est pas codé.
- **À vérifier** — information absente. Elle n’est pas inventée.
- **Bloquant** — empêche une mission nommée, pas la documentation.

Les statuts, tables et invariants cités ici sont ceux de `database-model-v0.3.md`. Les directions de synchronisation sont celles de `filemaker-sync-matrix.md`.

## 1. Décisions validées

- Une application Next.js.
- `www.thalie.eu` : vitrine, catalogue, réservation, paiement, espace familles.
- `admin.thalie.org` : administration interne.
- `webdirect.thalie.org` : FileMaker Server existant, conservé.
- MariaDB sur un VPS en France.
- Supabase n’est pas utilisé.
- Les modules doivent pouvoir remplacer FileMaker par Polymnie sans réécrire les pages.
- Un centre est une fiche unique et modifiable. Il accueille plusieurs séjours. Un séjour appartient à un seul centre et possède plusieurs sessions. Le programme est commun aux sessions. Les sessions portent dates, capacité et tarifs. Les anciennes sessions restent en base.
- Une famille a plusieurs adultes possibles et un seul responsable administratif. Chaque adulte a un compte personnel. Un enfant appartient à une seule famille.
- Les identifiants FileMaker des familles, des enfants et des inscriptions sont stables.
- FileMaker ne distingue pas encore systématiquement les adultes comme entités autonomes.
- Une commande regroupe plusieurs enfants et plusieurs séjours. Une inscription est un enfant dans une session.
- Réserver bloque une place tout de suite, jusqu’à confirmation ou annulation. Encaisser ne confirme pas. Le bureau confirme à la main.
- Les statuts administratif, financier et documentaire sont indépendants.
- Une inscription peut être modifiée ou transférée dans FileMaker. L’historique des changements est conservé.
- Il n’y a pas de contrainte `UNIQUE(enfant_id, session_id)` : une inscription annulée ou transférée reste, et une nouvelle inscription active peut exister. Une règle empêche deux inscriptions actives pour le même enfant sur la même session.
- Les tarifs peuvent dépendre du séjour, de la session et du client. CSE et collectivités peuvent avoir un tarif négocié et un contingent. **Validé :** ce contingent est compris dans la capacité de la session. Il bloque `MAX(reel_estime, realise)` places. Les options initiales ne bloquent pas. Les inscriptions nominatives du partenaire sont comprises dans ce blocage, jamais ajoutées une seconde fois.
- La disponibilité commerciale est la capacité moins les places hors contingent tenues, moins la somme des blocages de contingents. Les inscriptions actives FileMaker sont rapprochées de leur contingent avant l’ouverture des ventes. Confirmer une place hors contingent ne la compte pas une deuxième fois.
- Aller et retour sont indépendants.
- Le prix vendu est figé avec toutes ses composantes. Un changement de catalogue ne réécrit pas une vente.
- Axepta remplace Monetico. Le métier souhaite la CB comptant et la CB en trois fois à J, J+30 et J+60. Le contrat Axepta n’est pas supposé déjà capable de ce trois fois. Chèque, virement, ANCV papier et ANCV Connect sont prévus.
- Les échéances se posent sur la commande ou sur l’inscription, selon la règle de paiement applicable. Cette répartition est **à vérifier**.
- Un paiement peut être ventilé sur plusieurs inscriptions. FileMaker reçoit une écriture distincte par inscription. La synchro est bidirectionnelle, sans doublon.
- Les remboursements CB partent du site via Axepta, puis vers FileMaker.
- Le traitement d’un refus de réservation déjà payée dépend du motif et de la décision du bureau.
- Les familles déposent leurs fichiers sur le site, rattachés à l’inscription. Copie automatique vers FileMaker. La validation se fait dans FileMaker, pas dans le back-office. Le statut revient sur le site. Une pièce validée est verrouillée.
- FileMaker gère aujourd’hui les documents à la fois par des enregistrements dédiés et par des rubriques Conteneur. Lequel sert à quoi n’est pas connu.
- Les documents publiés par Thalie sont déposés depuis `admin.thalie.org`.
- Les factures naissent dans FileMaker, puis peuvent arriver par OneDrive. Une facture FileMaker n’est pas forcément une commande du site : elle peut être historique ou institutionnelle. Le site ne la rattache qu’après un rapprochement sûr, à une ou plusieurs inscriptions quand la clé le permet.
- Aucun traitement réel de données sanitaires tant que le cadre de conservation et de sécurité n’est pas validé.
- Oxatis et PrestaShop 1.7.5.1 seront importés dans des structures séparées. Un rapprochement de familles ambigu n’est jamais automatique. Les identifiants PrestaShop ne sont présents que dans une partie des dossiers FileMaker.

## 2. Ce que le dépôt contient aujourd’hui

Maquette navigateur : connexion, enfants, dossier, fiche sanitaire avec PDF, documents publiés, écran bureau. État en mémoire dans `components/Providers.tsx`. Dépendances : Next.js 15.5, React 19, TypeScript, `pdf-lib`. Aucune route API, aucun middleware, aucun test, aucune base.

À conserver comme spécification d’interface, pas comme couche de données :

- le parcours familles et les textes déjà validés avec les utilisatrices ;
- la charte (logo non rogné, rouge `#b40024`, Fraunces, Outfit) ;
- la liste de pièces de la maquette et la règle d’affichage de la convocation ;
- le contrat de champs du PDF (`FicheAnswers`) et le modèle vierge `public/fiche/modele.pdf`.

La maquette verrouille des pièces dans l’écran bureau de démonstration. **La cible est différente : la validation documentaire fait foi dans FileMaker.** Le code n’est pas modifié par ce document. Les missions 1.1 à 1.3 laissent ce bouton en place comme démonstration. Séparer à l’écran l’enregistrement du choix famille et la validation FileMaker viendra après, dans une mission dédiée.

Deux catalogues coexistent dans le code (`sejour=passion` d’un côté, `passion-2027` de l’autre). `ficheSent` est un booléen global. Ce sont des défauts de maquette, pas des règles métier.

## 3. Forme de l’application

**Hypothèse.** Un seul dépôt, une seule application Next.js, trois hôtes distingués plus tard par l’en-tête `Host`. Les URL actuelles de la maquette (`/`, `/enfants`, `/dossier`, `/fiche`, `/documents`, `/bureau`) restent en place pendant le Lot 1.

Découpage visé, sans déplacement de fichiers tant qu’une mission ne le demande pas :

| Zone | Rôle |
| --- | --- |
| `app/(public)` | Vitrine, catalogue, tunnel de réservation |
| `app/(famille)` | Espace familles, routes actuelles |
| `app/(admin)` | `admin.thalie.org` |
| `server/` | MariaDB, fichiers, Axepta, FileMaker, OneDrive. Jamais importé par un composant client |
| `db/migrations/` | SQL versionné, quand une mission y sera autorisée |

`/bureau` reste l’écran de démonstration. L’administration cible n’est pas cet écran. L’admin dépose les documents Thalie, suit les conflits de synchro, les rapprochements ambigus et les refus payés. L’admin ne valide pas les pièces familles.

### Services

Chaque service est une fonction de `server/`, appelée par les routes. Les pages ne parlent pas à MariaDB.

| Service | Responsabilité |
| --- | --- |
| Catalogue | Centres, séjours, sessions, catégories, disciplines, contenus éditables, médias, URL stables, redirections |
| Comptes | Familles, adultes, enfants, session cookie |
| Réservation | Commande, inscription, capacité, contingent, historique |
| Tarifs | Grille et copie figée des composantes |
| Transports | Aller et retour séparés |
| Paiements | Échéances, transaction bancaire, mouvement, ventilation |
| Documents | Dépôt famille, copie FileMaker, pièces publiées, factures |
| Synchro | Journal, identifiants externes, conflits, reprise |
| Import | Tables d’import Oxatis, PrestaShop, FileMaker |

Polymnie : le service Synchro parle à un connecteur. Les pages ne connaissent ni les rubriques FileMaker ni le futur logiciel. Le connecteur FileMaker n’est pas écrit dans ce lot, et aucune connexion n’est tentée.

Le catalogue public (textes, médias, catégories, disciplines, slugs, métadonnées, redirections Oxatis) est modifiable par l’équipe dans l’admin. La direction graphique n’est pas une donnée métier : elle reste dans les feuilles de style.

## 4. Système qui fait foi

| Donnée | Fait foi |
| --- | --- |
| Identité et coordonnées de la famille | Les deux. Divergence concurrente = conflit, sans écrasement |
| Adultes et comptes de connexion | Le site, tant que FileMaker n’a pas d’adulte autonome |
| Enfant déjà présent dans FileMaker | FileMaker pour l’identité importée |
| Enfant créé par une nouvelle famille sur le site | Le site, jusqu’à obtention de l’identifiant FileMaker |
| Textes et photos du catalogue | **À vérifier** |
| Dates et capacité d’une session | **À vérifier** |
| Création d’une inscription sur le site | Le site, puis les deux pour modification et transfert, avec historique |
| Confirmation manuelle du bureau | **À vérifier** : FileMaker ou admin |
| Prix vendu | Le site (figé). FileMaker en est informé |
| Transaction bancaire Axepta | Le site |
| Mouvement et ventilation | Les deux, sans doublon |
| Remboursement CB | Le site initie, FileMaker reçoit |
| Fichier déposé par la famille | Le site, jusqu’à copie acquittée |
| Validation de ce fichier | FileMaker |
| Document publié par Thalie | L’admin du site |
| Facture | FileMaker pour le document comptable, qu’il corresponde ou non à une commande web. Le site pour l’affichage, après rapprochement sûr |
| Données sanitaires | Aucun. Traitement non activé |

## 5. Réservation et places

Une inscription active a le statut administratif `place_bloquee` ou `confirmee`. `refusee`, `annulee` et `transferee` ne tiennent pas de place.

Hors contingent, la session tient trois compteurs, plus le journal `suivi_places` :

- `places_bloquees` ;
- `places_confirmees` ;
- `places_liberees`, cumul des places rendues, qui ne reviennent pas dans le stock par un simple ajout.

Ces trois compteurs ne contiennent que les inscriptions qui ne sont pas rattachées à un contingent. Confirmer déplace une place du premier vers le second. Le total hors contingent ne change pas. Libérer retire la place du compteur où elle se trouve et l’ajoute aux libérées.

**Validé.** Un contingent partenaire est compris dans la capacité totale. Il porte trois valeurs saisies, distinctes du blocage :

- `options_posees`, le nombre d’options posées au départ par le partenaire, conservé pour le suivi commercial, sans effet sur les places ;
- `reel_estime`, le nombre de participants que Thalie estime devoir attendre ;
- `realise`, le nombre d’inscriptions actives rattachées à ce partenaire et à cette session.

Les places bloquées par ce contingent sont `MAX(reel_estime, realise)`. Le réalisé est déjà dedans. Il n’est pas ajouté en plus, ni dans les compteurs hors contingent.

Exemple validé. Capacité 30, options posées 12, réel estimé 7, réalisé 5, aucune autre réservation : le CSE bloque 7 places, il en reste 23 hors CSE.

La disponibilité commerciale est la capacité, moins les places hors contingent encore tenues, moins la somme des blocages de contingents.

Baisser le réel estimé peut libérer des places, dans la limite du réalisé : si cinq enfants sont déjà inscrits, descendre l’estimation de 7 à 4 laisse le blocage à 5. Monter le réel estimé, ou laisser le réalisé dépasser l’estimation, ne s’accepte que si la disponibilité couvre l’augmentation, dans la même transaction. Chaque changement d’options, d’estimation ou de réalisé est historisé, avec le blocage qui en résulte.

Une inscription nominative FileMaker est rapprochée du contingent du partenaire. Avant ce rapprochement, elle tient une place hors contingent. Le rapprochement la retire de ce décompte et l’ajoute au réalisé, dans le même geste. Le nom de la rubrique FileMaker qui désigne le partenaire reste **à vérifier**.

La prise de place, la baisse de capacité et la hausse du réel estimé sont atomiques. Rejouer le même événement ne compte pas deux fois.

**À vérifier, et non appliqué :** faut-il interdire deux sessions actives dont les dates se chevauchent pour le même enfant ? Ce n’est pas une règle posée.

Transfert FileMaker, deux formes possibles parce que le geste exact dans FileMaker n’est pas connu :

1. la même inscription change de session, l’historique enregistre l’ancienne et la nouvelle, l’ancienne session libère une place et la nouvelle en bloque une ;
2. FileMaker crée une nouvelle inscription : l’ancienne passe à `transferee` et libère sa place, la nouvelle en prend une sur la session cible.

**À vérifier :** laquelle de ces deux formes FileMaker utilise. Le modèle les accepte toutes les deux.

L’enfant, la famille et la commande sont liés par des clés étrangères : l’enfant de l’inscription est un enfant de la famille de la commande. La session enregistrée est une session du séjour enregistré. Le transport choisi est un transport de cette session. Le sens aller ou retour est contrôlé dans la transaction. Une inscription annulée reste en base. Une nouvelle inscription active du même enfant sur la même session est possible. Deux inscriptions actives identiques ne le sont pas.

## 6. Prix

Au moment de l’inscription, chaque composante est copiée : séjour, aller, retour, et toute autre ligne alors appliquée. Cette copie ne suit plus le catalogue.

**Hypothèse de résolution, à confirmer avant le tunnel d’achat :** tarif de session pour ce client, sinon tarif de session, sinon tarif de séjour pour ce client, sinon tarif de séjour.

## 7. Paiements

Cinq objets, jamais confondus :

| Objet | Rôle |
| --- | --- |
| Commande | Regroupe les inscriptions |
| Inscription | Enfant × session, porte les trois statuts |
| Échéance | Somme prévue à une date, portée par la commande ou par une inscription |
| Transaction bancaire | Échange technique avec Axepta (ou un autre prestataire électronique) |
| Mouvement financier | Encaissement ou remboursement métier |
| Ventilation | Part du mouvement affectée à une inscription, puis écriture FileMaker distincte |

Invariant : la somme des ventilations d’un mouvement égale le montant du mouvement.

Un paiement carte né sur le site est une transaction bancaire, un mouvement, N ventilations, puis N règlements FileMaker (un par inscription). Un règlement né dans FileMaker devient un mouvement à une seule ventilation. On ne fusionne pas des règlements FileMaker par montant.

Chèque, virement et ANCV papier n’ont pas de transaction bancaire. ANCV Connect : **à vérifier** si un prestataire électronique renvoie une référence.

Le trois fois à J, J+30 et J+60 est un souhait métier. Il n’est pas traité comme une capacité déjà ouverte chez Axepta. Aucune échéance de ce type n’est créée tant que le contrat ne l’a pas confirmé. **Bloquant pour l’appel prestataire**, pas pour la forme des tables.

Un refus de réservation payée ne déclenche pas de remboursement automatique. Le bureau décide. S’il décide un remboursement CB, le site l’initie via Axepta, puis transmet les écritures à FileMaker.

## 8. Documents et fichiers

Les fichiers déposés par les familles et les PDF remplis ne vont pas dans `public/`. Le modèle vierge de la fiche et le logo peuvent y rester : ils ne contiennent pas de dossier famille.

**Hypothèse :** fichiers sur un disque du VPS, hors de la racine web, ou sur un stockage compatible S3 situé en France. MariaDB ne contient que la clé de stockage. Le téléchargement passe par une route authentifiée.

Copie FileMaker : le site envoie le fichier, attend un identifiant externe, puis seulement passe la pièce en `en_validation`. Sans identifiant, la pièce reste en `copie_en_echec` et peut être rejouée. La validation qui revient de FileMaker pose `verrouille_le` et une ligne d’historique. L’admin ne valide pas ces pièces.

Les versions de fichiers et les déclarations de substitution restent en base. Déclarations conservées : pas de PAI, aucun traitement y compris hors ordonnance, refus d’un justificatif sécu ou mutuelle avec la phrase d’avance de frais déjà écrite dans la maquette. Le pass nautique n’est exigé que si une exigence de séjour ou de session le dit. Quels séjours sont nautiques est **à vérifier**.

`inscriptions.statut_documentaire` résume les pièces de cette inscription selon les exigences applicables à son séjour et à sa session. Il ne se met pas à jour à la main à côté d’elles. L’état `valide` signifie que chaque exigence applicable qui bloque la convocation est validée. Le détail de priorité, si plusieurs pièces divergent, est **à vérifier** quand les statuts renvoyés par FileMaker seront connus.

**À vérifier, bloquant pour le connecteur documents :** pour chaque type de pièce, l’enregistrement dédié, la rubrique Conteneur, ou les deux. Les noms de rubriques ne sont pas connus.

Les documents publiés par Thalie ont une référence de fichier. Selon leur nature, ils se rattachent au centre, au séjour, à la session ou à l’inscription. Trousseau, lettre et convocation sont, dans la maquette, des documents de séjour. La portée des autres natures est **à vérifier**.

Factures : une facture FileMaker peut être historique ou institutionnelle, sans commande web. Elle porte une référence de facturation FileMaker. Elle peut viser une ou plusieurs inscriptions. Un fichier OneDrive sans clé de rapprochement sûre reste en file d’attente. Aucun rapprochement par nom de famille seul.

Données sanitaires : le questionnaire de la maquette continue de produire un PDF dans le navigateur, sans stockage serveur. Aucune table sanitaire n’est créée. Le PDF généré écrit aujourd’hui un nom et une date en dur : ceci est un défaut de maquette, signalé, non corrigé ici.

## 9. Synchro et reprise

Journal append-only. Chaque envoi a une clé d’idempotence unique. Les statuts d’une ligne de journal : `en_attente`, `envoye`, `acquitte`, `erreur`, `a_rejouer`.

FileMaker indisponible laisse la réservation déjà commitée dans MariaDB et la ligne de journal en `a_rejouer`. L’indisponibilité n’annule pas la place.

Une passe de réconciliation compare les identifiants externes connus et une liste issue de FileMaker, le jour où cette liste existera. Elle ne crée pas de deuxième enfant ni de deuxième règlement si l’identifiant externe est déjà là.

Conflit de coordonnées : les deux valeurs sont conservées dans `conflits`, le bureau tranche dans l’admin, aucune des deux n’écrase l’autre.

## 10. Hébergement et sécurité

**Validé :** MariaDB sur un VPS en France.

**À vérifier, bloquant pour la production :**

- la version exacte de MariaDB (cible envisagée : 10.11 ou 11.4) ;
- qui administre le VPS ;
- où tourne le processus Next.js. Le dépôt ne le décide pas. Un Next.js hors de France qui lirait des dossiers familles, puis des données sanitaires, pose une question de lieu de traitement à trancher avant la mise en production ;
- sauvegarde de la base et des fichiers hors du VPS, et un essai de restauration.

MariaDB n’est pas exposée sur Internet. Deux comptes SQL : un pour les migrations, un pour l’application. L’application n’a aucun droit sur de futures tables sanitaires.

Mots de passe : Argon2id, cookie de session `HttpOnly`, `Secure`, `SameSite`. Les secrets restent dans l’environnement du serveur, jamais dans le dépôt ni dans ces documents.

Rôles : adulte famille, responsable administratif (seul à payer et à inviter), personnel admin (catalogue, conflits, documents Thalie, décisions de refus payé). Le personnel admin ne valide pas les pièces familles.

**Validé comme forme d’hébergement :** une base MariaDB `thalie` sur le VPS. InnoDB peut, sur la même instance, poser une clé étrangère vers une autre base. L’ancienne formulation qui le niait est retirée. Aucune base sanitaire n’est créée. Le cloisonnement futur, avec ou sans clé étrangère inter-bases, sera décidé avec le cadre de conservation, pas avant.

## 11. Hors de ce document

Ces fichiers ne contiennent aucun secret et aucune donnée personnelle réelle. La famille fictive déjà présente dans la maquette n’est pas une source à importer.

Aucune connexion FileMaker, Oxatis, PrestaShop, Axepta ou OneDrive n’est décrite comme disponible. Les noms de rubriques, de modèles et de scripts FileMaker sont inconnus.
