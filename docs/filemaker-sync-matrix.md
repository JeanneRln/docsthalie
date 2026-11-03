# Matrice de synchronisation FileMaker

Référence Lot 1.0 — précisée le 3 novembre 2026.

FileMaker reste sur `webdirect.thalie.org`, dans un seul fichier. Aucune connexion n’est tentée pour écrire ce document. Aucun nom de rubrique, de modèle, de script ou de conteneur n’est inventé. Quand le nom manque, la cellule dit **à vérifier**.

Les objets MariaDB sont ceux de `database-model-v0.3.md`.

## 1. Règles communes

**Validé**

- Les identifiants FileMaker des familles, des enfants et des inscriptions sont stables. Ils vivent dans `identifiants_externes` (`systeme = filemaker`), pas dans une colonne dupliquée.
- La synchro est bidirectionnelle seulement là où ce document le dit. Ailleurs, une seule direction.
- Une modification concurrente des coordonnées ne s’écrase pas. Elle crée une ligne `conflits`. Le bureau tranche.
- Chaque envoi a une `cle_idempotence` unique dans `journal_sync`. Rejouer un acquittement ne crée pas un deuxième enregistrement.
- FileMaker indisponible laisse la donnée métier déjà commitée et passe le journal en `a_rejouer`.
- Les adultes ne sont pas poussés comme fiches FileMaker tant que FileMaker ne les distingue pas comme entités. **Validé :** ce n’est pas systématique aujourd’hui.

**À vérifier, commun**

- Noms des modèles et des rubriques, y compris la rubrique qui porte l’identifiant stable.
- Existence d’un horodatage de modification fiable par entité. Sans lui, la détection de conflit est plus faible : il faudra une comparaison de valeurs, pas de versions.
- Compte Data API, en lecture puis en écriture, hébergé sur le serveur Next.js. Les secrets ne sont pas demandés dans le dépôt.
- La forme du transfert d’inscription : mise à jour de la même fiche, ou nouvelle fiche. Les deux sont prévues côté MariaDB.

**Réconciliation**

Une passe ultérieure compare `identifiants_externes` à une liste FileMaker. Elle rattache si l’identifiant externe existe déjà. Elle ne crée rien si deux fiches locales pourraient correspondre. L’export qui alimentera cette passe n’existe pas encore.

## 2. Matrice

### Famille — identité et coordonnées

| | |
| --- | --- |
| Direction | Bidirectionnelle |
| Fait foi | Les deux. Le dernier écrit gagne seulement s’il part de la valeur déjà acquittée |
| Déclencheur | Import initial ; modification sur le site ; modification vue dans FileMaker |
| Identifiant | Stable, connu comme existant, nom de rubrique **à vérifier** |
| Doublons | Unique `(filemaker, famille, id_externe)`. Un second import avec le même identifiant met à jour la file de réconciliation, il ne crée pas une deuxième famille |
| Conflit | Champ modifié des deux côtés depuis le dernier acquittement : ligne `conflits`, aucune écriture |
| Reprise | Journal `a_rejouer`. L’identifiant externe déjà reçu interdit une deuxième création |
| À vérifier | Liste des champs qui sont des coordonnées (adresse, téléphones, email de facturation). Les adultes du foyer ne sont pas des champs inventoriés |

### Adultes et comptes

| | |
| --- | --- |
| Direction | Aucune vers FileMaker tant que l’entité n’existe pas |
| Fait foi | Le site |
| Déclencheur | Invitation, première connexion, confirmation d’email |
| Doublons | `comptes.email` unique, `comptes.adulte_id` unique |
| À vérifier | Où FileMaker range aujourd’hui le deuxième parent (rubriques de la fiche famille, ou autre). Ne pas créer de fiches adultes FileMaker par hypothèse |

### Enfant

| | |
| --- | --- |
| Direction | FileMaker vers le site pour l’existant. Site vers FileMaker pour un enfant créé par une nouvelle famille, afin d’obtenir l’identifiant stable |
| Fait foi | FileMaker pour un enfant importé. Le site pour un enfant né sur le site, jusqu’à l’acquittement |
| Déclencheur | Import ; création sur le site ; modification d’identité |
| Identifiant | Stable. Nom de rubrique **à vérifier** |
| Doublons | Un `id_externe` = un enfant local |
| Conflit | Même règle que la famille si les deux côtés modifient prénom, nom ou date de naissance |
| À vérifier | Un enfant peut-il changer de famille dans FileMaker (séparation, tutelle) ? Le modèle accepte un changement de `famille_id` journalisé. La fréquence réelle n’est pas connue |

### Centre, séjour, session, catalogue

| | |
| --- | --- |
| Direction | **À vérifier** |
| Fait foi | **À vérifier.** Hypothèse non retenue comme décision : le site porterait les textes et les photos, FileMaker resterait le reflet opérationnel des sessions déjà vendues |
| Déclencheur | Non défini |
| Identifiant | Des fiches séjour et session existent dans FileMaker. Leurs identifiants stables au même titre que les familles ne sont pas affirmés |
| Doublons | Pas de synchro tant que le sens n’est pas choisi. Un import initial peut remplir les tables d’import sans écrire le catalogue vivant |
| À vérifier | Qui a le droit de modifier une date, une capacité, un programme. Bloquant pour la mission « connecteur catalogue », pas pour le modèle |

### Inscription

| | |
| --- | --- |
| Direction | Bidirectionnelle, contrôlée |
| Fait foi | Le site pour une réservation née sur le site (la place est déjà bloquée). Ensuite les deux, avec historique |
| Déclencheur | Réservation ; confirmation bureau ; refus ; annulation ; modification ou transfert FileMaker |
| Identifiant | Stable une fois la fiche FileMaker créée. Nom de rubrique **à vérifier**. Une inscription site peut exister sans identifiant FileMaker tant que la synchro n’est pas acquittée |
| Place | Hors contingent : bloquer ajoute 1 à `places_bloquees` et une ligne `suivi_places`. Confirmer déplace cette place vers `places_confirmees` sans deuxième prise. Libérer retire 1 du compteur concerné et ajoute 1 à `places_liberees`. Un transfert de session libère l’ancienne et bloque la nouvelle, une seule fois |
| FileMaker déjà rempli | Une inscription nominative dont le partenaire est reconnu alimente `realise` du contingent, pas les compteurs hors contingent. Avant ce rapprochement, elle tient une place hors contingent. Le rattachement retire cette place et augmente `realise` sans double compte. Rejouer ne double pas |
| Contingent | **Validé.** Compris dans la capacité. Options initiales conservées sans bloquer. Blocage = le plus grand entre le réel estimé et le réalisé. Hausse d’estimation contrôlée atomiquement. Baisse susceptible de libérer des places, sans descendre sous le réalisé. Historique de chaque modification |
| Doublons | La clé d’idempotence de création. L’identifiant externe une fois connu. L’unicité métier locale est `active_enfant_session`, pas une unicité permanente enfant-session |
| Conflit | Deux modifications de session ou de statut en même temps : événement des deux côtés conservé, ligne `conflits`, compteurs non rejoués tant que le bureau n’a pas tranché |
| Reprise | La place MariaDB reste. Le journal repart. On ne crée pas une deuxième inscription si l’événement de création est déjà `acquitte` ou si l’identifiant externe est déjà lié |
| À vérifier | Où le bureau confirme (écran FileMaker ou admin). Le motif de refus, et qui le saisit. La forme du transfert (même fiche ou nouvelle fiche) |

### Prix vendu

| | |
| --- | --- |
| Direction | Site vers FileMaker, en information |
| Fait foi | Le site. `inscription_prix_lignes` ne change pas si le catalogue ou FileMaker change |
| Déclencheur | Création de l’inscription, une fois les composantes figées |
| Doublons | Un envoi par inscription et par empreinte des lignes. Rejouer ne réécrit pas le prix |
| À vérifier | Quelles rubriques FileMaker reçoivent le séjour, l’aller, le retour. Noms inconnus. Un prix FileMaker différent du prix figé devient un conflit, pas une mise à jour du site |

### Transaction bancaire

| | |
| --- | --- |
| Direction | Aucune. Elle reste sur le site |
| Fait foi | Le site et Axepta |
| Contenu | Référence prestataire, type, montant, statut. Pas de numéro de carte |
| Doublons | Unique `(prestataire, reference_prestataire, type)` |

FileMaker reçoit le mouvement et les ventilations, pas le journal technique Axepta.

### Mouvement financier et ventilation

| | |
| --- | --- |
| Direction | Bidirectionnelle |
| Fait foi | Les deux, avec l’invariant : somme des ventilations = montant du mouvement |
| Déclencheur | Encaissement site ; règlement saisi dans FileMaker ; remboursement |
| Correspondance | **Validé :** FileMaker a un règlement par inscription. Donc une ventilation = un règlement FileMaker. L’identifiant externe est porté par l’entité `ventilation` |
| Cas site → FileMaker | Une transaction carte, un mouvement, N ventilations, N écritures FileMaker distinctes |
| Cas FileMaker → site | Un règlement devient un mouvement à une seule ventilation. On ne regroupe pas plusieurs règlements FileMaker parce que les montants se ressemblent |
| Échéances | Elles peuvent porter sur la commande ou sur une inscription. Le niveau applicable est **à vérifier**. Le trois fois J / J+30 / J+60 n’est pas supposé ouvert dans le contrat Axepta |
| Doublons | `mouvements.cle_idempotence` unique. `identifiants_externes` unique sur l’identifiant de règlement. Un webhook Axepta rejoué s’arrête sur la transaction bancaire et ne recrée pas le mouvement |
| Conflit | Si FileMaker modifie un montant et que la somme des ventilations ne pourrait plus égaler le mouvement, on n’écrit pas. Ligne `conflits` |
| Reprise | Même clé = même ventilation. Une création FileMaker déjà identifiée n’est pas relancée |
| À vérifier | Nom de la rubrique d’identifiant du règlement, et les rubriques montant, date, mode, référence. Leur existence métier est connue ; leur nom ne l’est pas |

### Remboursement CB

| | |
| --- | --- |
| Direction | Site vers Axepta, puis site vers FileMaker |
| Fait foi | Le site pour l’initiation. FileMaker reçoit le mouvement de sens `remboursement` |
| Déclencheur | Décision du bureau. Le site appelle alors Axepta, puis envoie les écritures à FileMaker. Pas de déclencheur automatique |
| Doublons | Référence de remboursement prestataire unique. Ventilation de remboursement identifiée à part de l’encaissement |
| À vérifier | Quels motifs obligent un remboursement, un avoir, ou aucun des deux. **Bloquant** pour coder le bouton de remboursement, pas pour la forme des tables |

### Pièce déposée par la famille

| | |
| --- | --- |
| Direction | Fichier : site vers FileMaker. Statut de validation : FileMaker vers le site |
| Fait foi | Le site pour le fichier jusqu’à copie acquittée. FileMaker pour la validation |
| Déclencheur | Dépôt famille ; échec de copie ; retour de statut |
| Stockage FileMaker | Enregistrements dédiés et rubriques Conteneur coexistent. **À vérifier** pour chaque type de pièce lequel reçoit le fichier. Bloquant pour le connecteur, pas pour les tables `pieces` et `fichiers` |
| Doublons | La clé d’idempotence de copie. Un fichier déjà lié à un identifiant externe n’est pas renvoyé comme une nouvelle pièce |
| Verrou | Quand le statut qui revient est validé, `verrouille_le` est posé et `decisions_pieces` garde la décision. Le site refuse alors tout ajout. Les versions de fichiers déjà là restent |
| Déclarations | Pas de PAI, aucun traitement, refus de justificatif sécu ou mutuelle : elles remplacent un fichier seulement si l’exigence applicable l’autorise. Elles sont historisées |
| Exigences | Par séjour ou par session. Le pass nautique n’est pas une exigence globale |
| Reprise | `copie_en_echec` retourne au journal. L’absence d’identifiant externe signifie que FileMaker n’a pas acquitté |
| À vérifier | Les valeurs exactes de statut renvoyées par FileMaker. Le vocabulaire `depose`, `copie_en_echec`, `en_validation`, `a_corriger`, `valide` est celui du site en attendant cette liste |

L’admin Thalie ne valide pas ces pièces. `inscriptions.statut_documentaire` est le résumé de ces pièces selon les exigences du séjour et de la session, pas un champ FileMaker séparé. `valide` quand chaque exigence applicable qui bloque la convocation est validée. La priorité entre paliers différents est **à vérifier**.

### Document publié par Thalie

| | |
| --- | --- |
| Direction | Aucune vers FileMaker tant qu’un besoin n’est pas établi |
| Fait foi | L’admin du site |
| Déclencheur | Dépôt sur `admin.thalie.org` |
| Fichier | Référence de stockage obligatoire. Les versions précédentes sont conservées |
| Portée | Un seul rattachement : centre, séjour, session ou inscription, selon la nature. Trousseau, lettre et convocation sont, dans la maquette, des documents de séjour |
| À vérifier | Faut-il aussi une copie dans FileMaker pour le directeur de séjour ? Non décidé. La portée de chaque nature au-delà de la maquette |

La convocation n’est visible pour une inscription que si elle a été déposée et si les exigences applicables qui bloquent la convocation sont validées dans FileMaker.

### Facture et OneDrive

| | |
| --- | --- |
| Direction | FileMaker produit la facture. OneDrive peut la déposer. Le site la lit |
| Fait foi | FileMaker pour le document comptable. Le site pour l’affichage, après rapprochement |
| Forme | Une facture n’est pas forcément une commande web. Origines prévues : `web`, `historique`, `institutionnelle`. Elle porte `reference_facturation` et, quand il est connu, un identifiant technique dans `identifiants_externes` |
| Rattachement | Zéro, une ou plusieurs inscriptions. `commande_id` seulement si le lien avec une commande du site est sûr |
| Rapprochement | Sinon `en_attente_rapprochement`. Jamais par le seul nom de famille |
| Doublons | `cle_onedrive` traitée une fois. Un second passage ne crée pas une deuxième facture |
| À vérifier | Emplacement OneDrive, forme du nom, métadonnée qui porte la clé, compte d’accès en lecture. Bloquant pour le connecteur factures. Unicité réelle de la référence de facturation |

### Questionnaire sanitaire

| | |
| --- | --- |
| Direction | Aucune |
| Fait foi | Aucun système |
| État | La maquette génère un PDF dans le navigateur et ne le stocke pas. Aucune synchro, aucune table, tant que le cadre de conservation et de sécurité n’est pas validé |

## 3. Ce qui n’est pas une synchro

- Le catalogue Oxatis et les comptes PrestaShop passent par les tables d’import (`migration-sources.md`), pas par ce journal, jusqu’à ce qu’un rapprochement sûr écrive `identifiants_externes`.
- Les transactions Axepta ne sont pas des enregistrements FileMaker.
- Les comptes adultes ne sont pas des fiches FileMaker par défaut.

## 4. Ordre minimal le jour où un connecteur sera autorisé

1. Lire les identifiants stables déjà connus (familles, enfants, inscriptions) et remplir `identifiants_externes` sans écraser les fiches ambiguës. Rapprocher chaque inscription nominative de son contingent quand le partenaire est reconnu, et n’initialiser les compteurs hors contingent que pour les autres. Une fois chacun, sans double compte.
2. Envoyer les nouvelles inscriptions site et leurs prix figés.
3. Envoyer les ventilations et recevoir les règlements FileMaker.
4. Copier les fichiers familles et recevoir les statuts.
5. Lire OneDrive pour les factures.

Chaque étape attend la précédente et les noms de rubriques de son périmètre. Le catalogue et le sanitaire ne sont pas dans cet ordre.
