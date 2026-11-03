# Sources de migration

Référence Lot 1.0 — précisée le 3 novembre 2026.

Stratégie d’import. Aucune extraction n’est faite pour ce document. Aucune connexion à FileMaker, Oxatis ou PrestaShop. Aucune donnée réelle n’est citée.

Le modèle vivant est dans `database-model-v0.3.md`. Les tables d’import n’ont pas de clé étrangère vers lui. Elles ne deviennent des fiches vivantes qu’après un rapprochement sûr.

## 1. Règles communes validées

- Trois sources : FileMaker (fichier unique servi sur `webdirect.thalie.org`), Oxatis (boutique actuelle), PrestaShop 1.7.5.1 sur `thalie.org`.
- PrestaShop sert aux comptes et à certains documents, pas aux réservations.
- Les identifiants PrestaShop ne sont présents que dans une partie des dossiers FileMaker.
- Un rapprochement ambigu n’est jamais automatique. La ligne d’import reste `ambigu` jusqu’à une décision humaine dans l’admin.
- L’historique reste dans les tables d’import même après rapprochement. On ne le réécrit pas pour « nettoyer ».
- Promouvoir une ligne écrit la fiche vivante, puis `identifiants_externes`, puis `id_cible` sur la ligne d’import. `id_cible` n’est pas une clé étrangère : une ligne d’import ne doit pas pouvoir supprimer une famille.
- Aucun secret d’accès n’est stocké dans le dépôt.

Statuts d’une ligne d’import : `importe`, `en_attente`, `rapproche`, `ambigu`, `rejete`.

## 2. FileMaker

### Connu

- Un seul fichier.
- Des familles, des enfants, des séjours, des sessions, des inscriptions, des règlements individuels, des documents.
- Identifiants stables pour les familles, les enfants et les inscriptions.
- Chaque inscription a des dates de début et de fin et un identifiant de session.
- Chaque règlement est relié à une inscription et possède un identifiant unique, un montant, une date, un mode et une référence. Les noms de rubriques de ces informations ne sont pas connus.
- Les documents existent sous deux formes à la fois : enregistrements dédiés et rubriques Conteneur. La répartition par type de pièce n’est pas connue.
- Les adultes ne sont pas des entités autonomes de façon systématique.
- Une partie seulement des dossiers contient un identifiant PrestaShop.

### Tables d’import

`import_filemaker_familles`, `import_filemaker_enfants`, `import_filemaker_inscriptions`, `import_filemaker_reglements`, `import_filemaker_documents`.

Chaque ligne garde `payload_json` brut. `id_externe` n’est rempli que lorsque le mapping a désigné la rubrique d’identifiant. On ne devine pas cette rubrique à partir d’un export non lu.

### Rapprochement

- Même identifiant FileMaker déjà présent dans `identifiants_externes` : la ligne se rattache à cette fiche. Pas de deuxième création.
- Identifiant FileMaker nouveau et fiche locale unique déjà liée : mise à jour seulement si les champs comparés n’ont pas divergé. Sinon `conflits`.
- Deux fiches locales possibles pour une fiche FileMaker : `ambigu`, arrêt.
- Enfant FileMaker sans famille déjà rapprochée : on n’invente pas la famille. La ligne reste `en_attente`.
- Une inscription active hors contingent, sur une session encore en vente, alimente `places_bloquees` ou `places_confirmees`, avec une ligne `suivi_places`. Si elle appartient à un partenaire, elle est rapprochée du contingent de cette session et compte dans `realise` seulement. Rejouer l’import ne double pas. Une inscription dont la session est passée peut rester `confirmee` sans rouvrir la session. La rubrique qui désigne le partenaire est **à vérifier**.

### À récupérer avant tout import réel

- Nom du fichier et des modèles concernés.
- Rubrique d’identifiant stable pour famille, enfant, inscription, règlement.
- Rubriques d’identité enfant, de dates d’inscription, d’identifiant de session.
- Rubriques du règlement : montant, date, mode, référence, lien vers l’inscription.
- Pour chaque type de document : enregistrement dédié, conteneur, ou les deux, et le nom de la rubrique.
- Où se trouve l’identifiant PrestaShop quand il existe, et comment sont marqués les dossiers qui ne l’ont pas.
- Où sont rangées les personnes adultes qui ne sont pas des fiches.
- Présence ou absence d’un horodatage de modification.
- Volume approximatif, sans export de données personnelles dans le dépôt.
- Rubrique de référence de facturation, distincte de l’identifiant de fiche, et les inscriptions qu’une facture vise. Une facture sans commande web (historique ou institutionnelle) reste une facture.

## 3. Oxatis

### Connu

Oxatis porte aujourd’hui le catalogue, les descriptions, les photographies, les commandes historiques, les anciennes URL, et des tarifs et transports construits en attributs et options. Le nouveau modèle ne reprend pas ces matrices d’attributs : un transport est une ligne `session_transports` (`aller` ou `retour`), un prix vendu est une ligne `inscription_prix_lignes`.

### Tables d’import

- `import_oxatis_produits` — fiches séjour ou session telles qu’Oxatis les modélise. Le découpage produit Oxatis = séjour ou produit = session est **à vérifier**. On ne le tranche pas sans export.
- `import_oxatis_commandes` — en-têtes historiques.
- `import_oxatis_lignes` — lignes de commande historiques.
- `import_oxatis_urls` — ancienne URL, type de page, identifiant produit si l’export le donne.

Les commandes Oxatis ne deviennent pas des `commandes` vivantes tant qu’on ne sait pas les relier à une famille sans ambiguïté. Elles restent consultables comme historique d’import. **Hypothèse :** l’historique d’achat Oxatis n’alimente pas le tunnel de réservation 2027. Il sert au SEO, au service client et à la preuve d’un achat passé. À confirmer.

### Référencement

Les redirections ne s’écrivent dans `redirections` qu’à partir de `import_oxatis_urls`, et seulement quand l’ancienne URL vise une fiche sans ambiguïté. Une URL absente de l’export n’est pas devinée. La mission SEO est bloquée sans cet export. Les textes, médias et catégories importés deviennent des contenus éditables. Ils ne transportent pas la direction graphique d’Oxatis.

### À récupérer

- Export des URL indexées (fiche produit, catégories, pages de contenu).
- Identifiant produit Oxatis, titre, description, photos, rattachement à un centre si le centre est dans la fiche.
- Structure réelle des attributs de tarif et de transport, pour écrire une fois le traducteur vers `tarifs` et `session_transports`.
- Export des commandes : identifiant, date, email, montants, statut. L’email seul ne rapproche pas si plusieurs familles peuvent le partager : ce cas part en `ambigu`.
- Où sont les photos (URL Oxatis à recopier, ou fichiers). Le téléchargement des médias n’est pas autorisé par ce document.

## 4. PrestaShop 1.7.5.1

### Connu

- Version 1.7.5.1, sur `thalie.org`.
- Rôle actuel : comptes et documents des familles. Pas de réservation.
- Les enfants sont notamment représentés dans des champs textuels.
- Les groupes clients mélangent des informations de séjour, de session, de type de clientèle et d’assurance.
- PrestaShop sera arrêté après la migration.
- L’identifiant PrestaShop n’est dans FileMaker que pour une partie des dossiers.

### Tables d’import

- `import_prestashop_clients` — une ligne par compte, `payload_json` incluant les groupes et les champs texte des enfants, sans les découper.
- `import_prestashop_documents` — une ligne par fichier connu, avec l’identifiant client PrestaShop s’il est dans l’export.

On ne crée pas d’enfant vivant en découpant un champ texte. On ne traduit pas un groupe client en session tant que la liste réelle des groupes n’a pas été lue et écrite dans une table de correspondance validée à la main.

### Rapprochement avec FileMaker et le site

Ordre proposé, **hypothèse :**

1. Si l’identifiant PrestaShop est déjà dans une fiche FileMaker rapprochée, et que cet identifiant vise un seul compte PrestaShop, le compte se rattache à cette famille. C’est le seul rapprochement automatique autorisé, parce que la clé a été posée par Thalie dans FileMaker.
2. Si l’identifiant PrestaShop vise plusieurs comptes, ou si plusieurs fiches FileMaker portent le même identifiant : `ambigu`.
3. Si le dossier FileMaker n’a pas d’identifiant PrestaShop : on ne rapproche pas par nom, prénom ou email. La ligne reste `en_attente` pour une décision humaine.
4. Les documents PrestaShop suivent le compte. Sans compte rapproché, le fichier reste dans l’import.

Le mot de passe PrestaShop n’est pas repris. L’adulte reçoit un parcours de première connexion sur le site. Le hash PrestaShop 1.7 n’est pas traité comme un hash du nouveau système.

### À récupérer

- Liste des groupes et de leur signification, établie par Thalie, pas déduite.
- Emplacement des champs texte « enfants ».
- Quels documents sont dans PrestaShop et lesquels sont seulement dans FileMaker.
- Nombre de comptes sans identifiant FileMaker, en chiffre, sans fichier clients dans le dépôt.

## 5. Ordre d’ensemble

**Hypothèse de séquence, à confirmer quand les exports existent.**

1. Cartographier les rubriques FileMaker (pas d’import).
2. Importer les identifiants FileMaker des familles, enfants et inscriptions dans les tables d’import, puis promouvoir seulement les fiches non ambiguës.
3. Rattacher PrestaShop uniquement par identifiant déjà présent dans FileMaker.
4. Laisser le reste des comptes PrestaShop en file humaine.
5. Importer Oxatis en historique et en URL, sans créer de réservation vivante.
6. Couper PrestaShop seulement quand les comptes rapprochés se connectent au site et que les documents rapprochés sont lisibles.
7. Laisser Oxatis vendre tant que le tunnel 2027 n’est pas le canal réel. La date de bascule n’est pas décidée par ce document. Le souhait de lancement commercial fin novembre 2026 ne constitue pas, à lui seul, cette bascule : le périmètre tenable reste à écrire.

## 6. Ce que l’import ne fait pas

- Il ne crée pas la base sanitaire.
- Il ne recopie pas les matrices d’attributs Oxatis dans des centaines de colonnes.
- Il ne remet pas en vente une session passée. Une inscription historique peut rester `confirmee` : elle a eu lieu. Sa session n’est pas laissée `ouverte`. Les compteurs de places des sessions encore ouvertes intègrent les inscriptions actives FileMaker déjà rapprochées, sans les compter deux fois. Le statut exact lu dans FileMaker pour une inscription passée est **à vérifier**.
- Il applique la règle de contingent validée : le blocage est le plus grand entre le réel estimé et le réalisé, et l’inscription nominative du partenaire n’est pas comptée en plus. Il n’ajoute pas d’autre règle de disponibilité. Le chevauchement de dates entre sessions n’en est pas une.
- Il ne dépose pas de mot de passe, de jeton ou de fichier client dans `docs/` ni dans `public/`.
- Il ne crée aucune table sanitaire.
