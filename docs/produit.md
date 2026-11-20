# JAPPO : modèle produit, phase 1

Statut : validé (étape 2 de la refonte), avec les décisions du § 10.
Périmètre : structures, coachs, entrepreneurs. Ce document remplace tout ce que le code actuel
laisse supposer (parcours, phases, missions à quatre niveaux, progression multiple).

---

## 1. Principes

1. **La simplicité d'un Lucidchart.** Le moins d'écrans possible ; chacun a une raison d'exister.
   On édite sur place (dans la page, dans un panneau latéral) plutôt que d'ouvrir un nouvel écran.
2. **Une seule façon de faire chaque chose**, au même endroit, avec les mêmes gestes partout :
   glisser-déposer, édition directe, menu « … », raccourcis clavier.
3. **Rien n'est stocké deux fois.** Ce qui peut se déduire (progression, étape en cours, statut
   d'une cohorte, retards) est calculé, jamais recopié.
4. **On ne perd jamais l'historique d'un projet.** Les livrables, versions, commentaires et
   participations passées restent consultables, même après une promotion ou un abandon.
5. **Les panneaux ont une adresse.** Un panneau ouvert (cohorte, projet, livrable…) se reflète
   dans l'URL : on peut partager un lien ou revenir en arrière sans écran dédié.

---

## 2. Vocabulaire

L'interface parle d'entrepreneuriat ; le modèle de données utilise des termes neutres, en anglais
(voir `docs/modele-donnees.md`, décision N1), pour pouvoir servir plus tard à d'autres formes
d'accompagnement (formation par projets, etc.).

| Terme de l'interface | Terme du modèle | Définition |
|---|---|---|
| **Structure** | `organization` | L'incubateur, l'accélérateur ou l'organisme qui accompagne ; toutes les données lui appartiennent et ne sont jamais visibles d'une autre structure. |
| **Membre** | `member` | Une personne dans une structure, avec un rôle unique dans cette structure ; c'est la seule façon de désigner une personne dans tous les modules. |
| **Admin** | rôle `ADMIN` | Le membre qui pilote la structure : programmes, cohortes, membres, paramètres. |
| **Coach** | rôle `FACILITATOR` | Le membre qui accompagne les projets de ses cohortes et relit leurs livrables. |
| **Entrepreneur** | rôle `PARTICIPANT` | Le membre accompagné, porteur d'un ou plusieurs projets. |
| **Programme** | `program` | Le modèle d'accompagnement (ex. Pré-incubation), organisé en étapes, sur lequel on lance des cohortes. |
| **Programme suivant** | `program.next_program_id` | Le programme vers lequel on promeut les projets à la fin de celui-ci (ex. Pré-incubation → Incubation). |
| **Étape** | `step` | Une grande partie ordonnée d'un programme (ex. Validation de l'idée). |
| **Activité** | `activity` | Ce qu'on fait concrètement dans une étape : une tâche, un atelier, une ressource à consulter ou une séance avec le coach. |
| **Livrable attendu** | `activity.deliverable_format` | Ce qu'une activité demande de rendre, facultatif, avec son format : fichier, lien, texte ou document modèle. |
| **Document modèle** | `document_template` | Un document structuré prêt à remplir dans la plateforme : Business Model Canvas, business plan, pitch deck. |
| **Cohorte** | `cohort` | Un groupe de projets qui suivent un programme ensemble, avec ses dates, ses coachs et sa propre copie du contenu du programme. |
| **Contenu de la cohorte** | `cohort_step`, `cohort_activity` | La copie des étapes, activités et livrables attendus faite au lancement de la cohorte (voir § 6.3), plus les activités propres à la cohorte. |
| **Activité de cohorte** | `cohort_activity` (origine `COHORT`) | Une activité ajoutée par un coach pour toute une cohorte, sans modifier le programme. |
| **Activité ponctuelle** | `cohort_activity` (origine `ENROLLMENT`) | Une activité ajoutée par un coach pour un seul projet de sa cohorte. |
| **Planning** | `due_offset_days`, `due_date_override` | Les dates limites des activités pour une cohorte, calculées au lancement puis ajustables. |
| **Porteur** | `project_holder` | Un entrepreneur membre de la structure qui porte un projet ; un projet peut en avoir plusieurs. |
| **Projet** | `project` | L'entreprise ou l'idée accompagnée, portée par un ou plusieurs entrepreneurs ; il traverse les programmes et garde tout son historique. |
| **Participation** | `enrollment` | Le passage d'un projet dans une cohorte, du début à sa fin (terminé, abandonné, à revoir). |
| **Livrable** | `deliverable` | Ce qu'un projet rend pour un livrable attendu ; il a un statut, des versions et un fil de commentaires. |
| **Version** | `deliverable_version` | Un état figé de ce qui a été rendu, à un instant donné ; une version rendue n'est jamais modifiée. |
| **Commentaire** | `deliverable_comment` | Un message dans le fil d'un livrable, échangé entre les porteurs du projet et les coachs. |
| **Promotion** | `enrollment.promoted_to_enrollment_id` | Le passage d'un projet vers une cohorte du programme suivant, qui clôt sa participation actuelle. |
| **Chemin du projet** | (affichage) | La suite des programmes traversés par un projet, déduite de ses participations ; ce n'est pas une donnée stockée. |
| **Ressource** | `resource` | Un fichier ou un lien de la bibliothèque de la structure, joint à des activités. |
| **Séance** | `meeting` | Un rendez-vous en visio (LiveKit) ou en présentiel entre un coach et un ou plusieurs projets. |
| **Invitation** | `invitation` | La seule façon de faire entrer une personne dans une structure : un email, un rôle, et pour un entrepreneur, la cohorte et le projet visés. |

Les concepts **Parcours**, **Phase** et **Mission** disparaissent (voir § 10, décision D1).

---

## 3. Rôles

Une personne peut appartenir à plusieurs structures, avec un rôle par structure. Elle change de
structure depuis la barre latérale. L'**admin** peut faire tout ce que fait un coach.

### 3.1 Admin de structure

**Peut faire**
- Créer, dupliquer, archiver un programme ; définir son programme suivant ; désigner les coachs
  autorisés à éditer son contenu.
- Éditer le contenu de n'importe quel programme (étapes, activités, livrables attendus).
- Lancer une cohorte, choisir ses coachs, ajuster son planning, appliquer les modifications du
  programme, clore la cohorte.
- Inviter des coachs et des entrepreneurs, changer un rôle, retirer un membre.
- Promouvoir un projet, le marquer terminé, abandonné ou à revoir, le réintégrer.
- Tout ce que fait un coach, sur toutes les cohortes.
- Régler les paramètres de la structure : profil, seuils d'alerte, abonnement.

**Voit** : tous les programmes, toutes les cohortes, tous les projets et livrables de la structure,
les membres, l'abonnement et la consommation de l'assistant IA.

### 3.2 Coach

**Peut faire**
- Éditer le contenu des programmes dont il est éditeur.
- Sur les cohortes dont il est coach : inviter des entrepreneurs, ajuster le planning, relire,
  commenter, demander une correction, valider un livrable, marquer une activité comme faite ou
  non faite, planifier des séances, ajouter des activités de cohorte et des activités ponctuelles (§ 6.5).
- Utiliser l'assistant IA (selon l'abonnement).

**Voit** : tous les programmes de la structure en lecture (pour connaître le contenu) ; seulement
les cohortes dont il est coach, avec leurs projets, livrables et séances. Le tableau de bord d'un
programme ne lui montre que ses cohortes.

### 3.3 Entrepreneur

**Peut faire**
- Compléter la fiche de son projet.
- Marquer une activité sans livrable comme faite.
- Rendre un livrable (fichier, lien, texte, document modèle), en rendre une nouvelle version,
  commenter.
- Remplir les documents modèles (brouillon enregistré automatiquement, privé jusqu'au rendu).
- Rejoindre les séances auxquelles il est invité.

**Voit** : son ou ses projets, le contenu de sa cohorte, ses livrables avec leurs versions et
commentaires, les ressources jointes à ses activités, ses séances, les coachs de sa cohorte, le
chemin de son projet. Il ne voit jamais les autres projets.

### 3.4 Super-admin de la plateforme (hors refonte)

Gère les structures (activer, suspendre) et les plans d'abonnement. **N'accède pas au contenu
d'accompagnement des structures** (programmes, projets, livrables). La console actuelle est
conservée et seulement adaptée au nouveau modèle.

---

## 4. Navigation

| Rôle | Barre latérale |
|---|---|
| Admin | Accueil · **Programmes** (la liste des programmes, dans l'ordre de leur chaîne, et « + Nouveau programme ») · Projets · Paramètres |
| Coach | Accueil · **Programmes** (idem, sans création) · Projets |
| Entrepreneur | Mon parcours |

Toujours présents : recherche **⌘K** (programmes, cohortes, projets, membres, activités, actions),
notifications, assistant IA (admin et coach), compte, changement de structure.

Il n'y a **qu'une seule entrée « Programmes »**. Il n'y a pas de page « liste des programmes » :
la barre latérale est cette liste (voir § 7).

---

## 5. Parcours clés

### 5.1 Une structure crée la Pré-incubation, lance une cohorte et invite ses entrepreneurs

1. L'admin clique sur « + Nouveau programme » dans la barre latérale, tape « Pré-incubation ».
   Le programme s'ouvre directement sur l'onglet **Contenu**, vide, avec un état vide qui propose :
   « Ajouter une première étape » ou « Dupliquer un programme existant ».
2. Il construit les étapes et activités (parcours 5.2), ou laisse un coach éditeur le faire.
3. Dans l'onglet **Vue d'ensemble**, il clique « Lancer une cohorte » : une fenêtre demande le nom,
   la date de début, la date de fin prévue et les coachs. À la validation, la cohorte reçoit sa
   copie du contenu et ses échéances (§ 6.3).
4. Le panneau de la cohorte s'ouvre, sur la section « Projets », vide : « Inviter des
   entrepreneurs ». Il colle une liste d'emails, avec pour chacun un nom de projet (facultatif).
5. Chaque entrepreneur reçoit un email. En suivant le lien, il crée son compte (ou se connecte),
   complète son projet en un seul formulaire (nom, description, secteur), et arrive sur
   **Mon parcours**. Sa participation à la cohorte démarre à ce moment.
6. Tant qu'une invitation n'est pas acceptée, elle apparaît dans le panneau de la cohorte, avec
   « Renvoyer » et « Annuler ».

### 5.2 Un coach construit les étapes et activités par glisser-déposer

1. Le coach ouvre Pré-incubation, onglet **Contenu**. Les étapes sont des blocs dépliables ; les
   activités sont des lignes à l'intérieur.
2. « + Étape » ajoute une étape en fin de liste, avec le titre en édition directe. Entrée valide,
   Échap annule.
3. Dans une étape, « + Activité » (ou la touche **N** quand une étape a le focus) ajoute une ligne :
   on tape le titre, puis on choisit le type (tâche, atelier, ressource, séance).
4. Un clic sur une activité ouvre son **panneau** à droite : description, obligatoire ou facultative,
   échéance relative (« J+14 après le début de la cohorte »), ressources jointes, livrable attendu
   (aucun, fichier, lien, texte ou document modèle). Tout s'enregistre au fil de la saisie.
5. **Réorganiser** : glisser une activité dans son étape ou vers une autre étape ; glisser une étape.
   Au clavier : focus sur l'élément, **Espace** pour le saisir, **↑ / ↓** pour le déplacer
   (y compris d'une étape à l'autre), **Espace** pour déposer, **Échap** pour annuler.
   Raccourci direct : **Alt + ↑ / ↓**. Chaque déplacement est annoncé aux lecteurs d'écran.
6. **Dupliquer** : menu « … » ou **⌘D** sur une étape (avec ses activités) ou une activité.
   **Déplacer vers…** : menu « … » d'une activité, pour l'envoyer dans une autre étape sans glisser.
7. **Supprimer** : menu « … » ou **Suppr**. L'élément disparaît, un message propose « Annuler »
   pendant 10 secondes. Les cohortes déjà lancées ne sont pas touchées (§ 6.3).
8. Si des cohortes en cours utilisent ce programme, un bandeau discret indique « 2 cohortes en
   cours utilisent une version antérieure du contenu » avec « Voir les différences ».

### 5.3 Un entrepreneur voit où il en est, quoi faire maintenant, et rend un livrable

1. Fatou se connecte : elle arrive sur **Mon parcours**.
2. En haut, le **chemin de son projet** : « Pré-incubation (en cours) → Incubation →
   Accélération », puis sa progression (« 9 activités sur 14 · 64 % ») et l'étape en cours
   (« Proposition de valeur »).
3. Bloc **À faire maintenant**, dans cet ordre :
   1. les livrables **à corriger** (avec le dernier commentaire du coach) ;
   2. les activités de l'étape en cours non terminées, par échéance ;
   3. les prochaines échéances des étapes suivantes (7 jours) ;
   4. la prochaine séance prévue.
   Une activité en retard est signalée par un libellé « En retard de 3 jours ».
4. En dessous, toutes les étapes avec leurs activités, cochées ou non, la suivante dépliée.
5. Elle ouvre l'activité « Business Model Canvas v1 » : le panneau montre la consigne, les
   ressources, l'échéance et le livrable attendu. Bouton « Remplir le document ».
6. L'écran **Document** s'ouvre sur le canevas : elle remplit les 9 blocs, l'enregistrement est
   automatique (brouillon visible d'elle seule et des autres porteurs du projet).
7. « Rendre » : une confirmation résume ce qui part au coach. Le livrable passe à **Rendu**, une
   version 1 est figée, le coach est notifié.

### 5.4 Le coach commente, demande une correction, puis valide

1. Ibrahima voit sur son **Accueil** : « 3 livrables rendus attendent votre retour », le plus
   ancien en premier. Un clic ouvre le **panneau du livrable** (la page ne change pas).
2. Le panneau montre la version rendue, l'historique des versions, et le fil de commentaires.
   Pour un document modèle, « Ouvrir le document » l'affiche en lecture seule, avec le fil de
   commentaires sur le côté.
3. Il écrit un commentaire, puis « Demander une correction » : un commentaire est obligatoire,
   une nouvelle échéance est facultative. Le livrable passe à **À corriger** ; Fatou est notifiée.
4. Fatou corrige le document et le rend à nouveau : version 2, statut **Rendu**.
5. Ibrahima compare les versions 1 et 2 (sélecteur de version), puis « Valider ». Le livrable
   passe à **Validé**, l'activité est terminée, la progression de Fatou augmente.

### 5.5 La structure promeut un projet vers l'Incubation

1. L'admin ouvre Pré-incubation. Dans le panneau de la cohorte 2026-A, le projet AgriFresh est à
   100 %.
2. Il coche AgriFresh (et d'autres projets), puis « Promouvoir vers Incubation ». La fenêtre
   propose les cohortes d'Incubation à venir ou en cours, et un motif facultatif.
3. À la confirmation : la participation en Pré-incubation se termine avec le statut **Terminé
   (promu)**, une nouvelle participation démarre dans la cohorte d'Incubation choisie.
4. Si un projet n'a pas terminé toutes ses activités obligatoires, la fenêtre l'indique
   (« 2 activités obligatoires non terminées ») et demande un motif ; la promotion reste possible.
5. La fiche du projet affiche son chemin : « Pré-incubation ✓ → Incubation (en cours) →
   Accélération ». Ses livrables de Pré-incubation restent consultables, rattachés à leur
   participation.

### 5.6 Clore une cohorte

1. À la fin de la cohorte, l'admin clique « Clore la cohorte » dans son panneau.
2. Pour chaque projet encore en cours, il choisit une issue : **promouvoir** (si le programme a un
   programme suivant), **terminé**, **à revoir** ou **abandonné**. Valeur proposée : « terminé » si
   le projet est à 100 %, « à revoir » sinon.
3. La cohorte passe à **Terminée**. Ses projets restent consultables avec leur statut final.

---

## 6. Règles métier

### 6.1 Programme

- Un programme a un nom, une description, des étapes ordonnées, un programme suivant facultatif
  et des coachs éditeurs.
- Le programme suivant appartient à la même structure ; la chaîne ne peut pas boucler
  (A → B → A est refusé).
- Un programme qui a des cohortes ne se supprime pas : il s'**archive** (il disparaît de la barre
  latérale, ses cohortes restent consultables). Un programme sans cohorte peut être supprimé,
  avec « Annuler ».
- « Dupliquer le programme » copie les étapes, activités et livrables attendus, sans les cohortes.

### 6.2 Étapes et activités

- Une étape contient des activités ordonnées. Une activité appartient à une seule étape.
- Une activité a : un titre, une description, un type (tâche, atelier, ressource, séance), un
  indicateur **obligatoire** (oui par défaut), une **échéance relative** facultative (nombre de
  jours après le début de la cohorte), des ressources jointes, et **au plus un** livrable attendu.
- Un livrable attendu a un format : fichier, lien, texte, ou document modèle (BMC, business plan,
  pitch deck).

### 6.3 Programme et cohorte : modèle et copie

**Règle** : au lancement, la cohorte prend **une copie** des étapes, activités et livrables
attendus du programme. Chaque élément copié garde un lien vers son élément d'origine. Ensuite,
modifier le programme ne change pas les cohortes déjà lancées, **sauf si on choisit d'appliquer
les modifications** à une cohorte.

**Pourquoi cette règle**
- Un entrepreneur en cours de programme ne voit pas ses activités changer sous ses pieds, ni un
  livrable déjà validé disparaître.
- L'historique reste juste : un livrable pointe toujours vers l'activité telle qu'elle était
  quand il a été rendu.
- C'est le modèle mental d'une formation : on améliore le modèle pour les prochaines sessions,
  sans perturber la session en cours, et on peut choisir de propager une correction.
- Le lien vers l'origine permet de calculer les différences et de les appliquer sans doublon.

**Appliquer les modifications à une cohorte** (admin, ou coach éditeur du programme)
- Le panneau de la cohorte montre les différences : activités ajoutées, modifiées, déplacées,
  supprimées. On applique tout ou rien, après confirmation.
- Ajouts, modifications de texte et réorganisations sont appliqués.
- Une activité supprimée du programme est retirée de la cohorte **seulement si aucun projet n'a
  commencé de livrable dessus ni ne l'a marquée faite**. Sinon, elle reste dans la cohorte avec
  la mention « Retirée du programme » et devient facultative : rien de ce qui a été rendu ne se
  perd.
- Les échéances déjà ajustées à la main dans la cohorte ne sont pas écrasées.
- Les activités de cohorte et les activités ponctuelles ne sont jamais touchées.

**Ce qu'on peut changer directement dans une cohorte** : son planning (les échéances), ses coachs,
ses dates, et des activités supplémentaires (§ 6.5) :
- des **activités de cohorte**, pour toute la cohorte, ajoutées dans une de ses étapes ;
- des **activités ponctuelles**, pour un seul projet.

Elles se créent, se modifient, se réorganisent et se suppriment dans la cohorte, avec les mêmes
gestes que dans le programme, et n'existent que là. Les étapes et les activités issues du
programme ne se modifient que dans le programme : une seule façon de changer le modèle.

### 6.4 Cohorte

- Une cohorte appartient à un programme. Un programme peut avoir plusieurs cohortes, en parallèle
  ou à la suite.
- Elle a : un nom, une date de début, une date de fin prévue, des coachs, et une date de clôture
  quand elle est close.
- **Statut, calculé** (jamais stocké) :
  - **À venir** : la date de début n'est pas encore atteinte ;
  - **En cours** : la date de début est atteinte et la cohorte n'est pas close ;
  - **Terminée** : la cohorte a été close (§ 5.6).
  Si la date de fin prévue est passée sans clôture, la cohorte reste « En cours » et une alerte
  « Fin prévue dépassée » est affichée à l'admin.
- **Échéances** : au lancement, chaque activité avec une échéance relative reçoit une date
  (début de la cohorte + N jours). Si la date de début change, les échéances non ajustées à la
  main sont recalculées.
- L'abonnement limite le nombre de cohortes **non closes** (plan Freemium : 1).

### 6.5 Projet et participation

- Un projet appartient à une structure. Il a un ou plusieurs **porteurs** (des entrepreneurs
  membres de la structure). La phase 1 propose un porteur à la création ; on peut en ajouter.
- Un projet a **au plus une participation en cours** à la fois.
- **Statuts d'une participation**
  - **En cours** ;
  - **Terminé** : le projet a fini le programme (avec la mention « promu » s'il a été promu) ;
  - **À revoir** : non retenu pour la suite, mais peut être réexaminé ;
  - **Abandonné** : le projet a quitté l'accompagnement.
- **Transitions** (admin) : En cours → Terminé, À revoir ou Abandonné ; À revoir → promotion vers
  le programme suivant, ou réintégration dans une cohorte en cours du même programme ;
  Abandonné → réintégration. Chaque transition garde la date, l'auteur et un motif facultatif.
- Le statut du projet n'est pas stocké : la fiche affiche celui de sa dernière participation.
- **Activités supplémentaires** : un coach peut ajouter, dans une étape de sa cohorte,
  - une **activité de cohorte**, pour tous les projets de la cohorte (ex. « Atelier fiscalité ») ;
  - une **activité ponctuelle**, pour un seul projet (ex. « Refaire l'étude de prix »).

  Elles se comportent comme des activités normales (livrable, échéance, progression).
  L'activité ponctuelle remplace les anciennes « missions assignées » (décision D1).

### 6.6 Promotion

- Seul l'admin promeut. On ne peut promouvoir que vers une cohorte **à venir ou en cours** du
  **programme suivant**.
- Effet : la participation actuelle passe à **Terminé (promu)** ; une nouvelle participation
  démarre dans la cohorte choisie.
- On peut promouvoir un projet qui n'a pas tout terminé : la fenêtre l'indique et demande un motif.
- On ne peut pas promouvoir un projet abandonné sans l'avoir réintégré.
- Rien n'est copié ni déplacé : les livrables restent rattachés à leur participation d'origine.

### 6.7 Livrable

- Il existe au plus **un livrable par projet et par livrable attendu de la cohorte**. Il est créé
  au premier enregistrement (brouillon ou rendu).
- **Statuts**
  - **À rendre** : rien n'a été rendu (un brouillon peut exister) ;
  - **Rendu** : une version attend le retour du coach ;
  - **À corriger** : le coach a demandé une correction ;
  - **Validé** : le coach a validé ; l'activité est terminée.
- **Transitions**
  | De | Vers | Qui | Condition |
  |---|---|---|---|
  | À rendre | Rendu | porteur | rendre crée la version 1 |
  | Rendu | À corriger | coach, admin | commentaire obligatoire, nouvelle échéance facultative |
  | Rendu | Validé | coach, admin | — |
  | À corriger | Rendu | porteur | rendre crée une nouvelle version |
  | Validé | À corriger | coach, admin | « Rouvrir », commentaire obligatoire |
- Une **version** est figée dès qu'elle est rendue : contenu (fichier, lien, texte ou document),
  date, auteur. Les colonnes du livrable ne recopient pas celles de la version : le livrable porte
  seulement son statut et pointe vers sa dernière version.
- **Brouillon** : pour un texte ou un document modèle, l'entrepreneur travaille sur un brouillon
  enregistré automatiquement, visible des porteurs du projet uniquement, jusqu'au rendu.
- **Fil de commentaires** : porteurs du projet et coachs de la cohorte (et admins) peuvent
  commenter à tout moment. Un commentaire peut citer une version. On peut modifier ou supprimer
  son propre commentaire pendant 15 minutes.
- Fichiers : liste blanche de formats (PDF, images, documents bureautiques, archives courantes),
  type vérifié sur le contenu réel, 25 Mo maximum par fichier.

### 6.8 Progression (un seul calcul)

La progression n'est jamais stockée : elle se calcule à partir des activités et des livrables.

- **Activité terminée pour un projet**
  - avec livrable attendu : le livrable est **Validé** ;
  - sans livrable attendu : un porteur ou un coach l'a **marquée faite**.
- **Progression d'une participation** = activités obligatoires terminées ÷ activités obligatoires
  du contenu de la cohorte (activités de cohorte et activités ponctuelles du projet incluses). Les activités facultatives
  ne comptent pas, sauf si elles sont terminées : elles apparaissent alors en bonus, sans changer
  le pourcentage.
- **Étape en cours** : la première étape (dans l'ordre) qui contient une activité obligatoire non
  terminée. Si tout est terminé : « Programme terminé ».
- **Date d'entrée dans l'étape en cours** : la date à laquelle la dernière activité obligatoire de
  l'étape précédente a été terminée ; pour la première étape, le début de la participation.
- **Progression moyenne d'une cohorte** : moyenne des participations en cours ; pour une cohorte
  terminée, moyenne au moment de la clôture, projets abandonnés exclus.
- **Répartition par étape** : nombre de projets en cours dont l'étape en cours est chaque étape,
  plus une colonne « Terminé ».

### 6.9 Retards, blocages et attentes (règles de calcul des alertes)

Les dates s'évaluent dans le fuseau horaire de la structure (Africa/Dakar par défaut). Une
échéance tombe à la **fin de la journée** indiquée. Les durées sont en jours calendaires.

| Alerte | Définition | Ordre d'affichage |
|---|---|---|
| **Livrable en retard** | Un livrable attendu a une échéance passée et le livrable est **À rendre** ou **À corriger**. Pour « À corriger », l'échéance de correction remplace l'échéance initiale si le coach en a fixé une. Une activité **sans** livrable dont l'échéance est passée et qui n'est pas marquée faite est aussi en retard. | du plus en retard au moins en retard |
| **Projet bloqué** | Une participation en cours dont le projet est dans la même étape depuis **plus de S jours** (date d'entrée dans l'étape, § 6.8). **S = seuil de blocage**, réglable par la structure (défaut 21 jours, de 3 à 180). | du plus ancien au plus récent |
| **Retour en attente** | Un livrable **Rendu** attend le retour du coach. Tous sont listés ; ceux qui attendent depuis **plus de R jours** sont marqués « en attente depuis N jours ». **R = délai de retour**, réglable par la structure (défaut 5 jours, de 1 à 30). | du plus ancien au plus récent |

- Un projet dont la participation n'est pas « En cours » ne génère aucune alerte.
- Une cohorte **à venir** ne génère aucune alerte.
- Les seuils se règlent dans **Paramètres → Accompagnement**. Ils s'appliquent à tous les
  programmes de la structure.
- Chaque alerte s'ouvre en un clic dans le panneau concerné (livrable ou projet).

### 6.10 Membres et invitations

- Une personne a **un rôle par structure** : Admin, Coach ou Entrepreneur. Toutes les références à
  une personne, dans tous les modules, passent par son **membre** dans la structure.
- **Un seul mécanisme d'invitation** : une invitation nominative par email, avec le rôle, et pour un
  entrepreneur la cohorte et le nom de projet proposé. Elle expire après 7 jours ; on peut la
  renvoyer ou l'annuler. Pas de lien d'invitation anonyme partageable en phase 1.
- Qui invite : l'admin invite tout le monde ; un coach invite des entrepreneurs dans ses cohortes.
- Retirer un membre ne supprime rien de ce qu'il a produit : ses commentaires et livrables restent,
  avec la mention « ancien membre ».
- Une structure a toujours au moins un admin.

### 6.11 Séances, ressources, assistant IA, abonnement

- **Séance** : planifiée depuis le panneau d'une cohorte ou d'un projet, ou depuis une activité de
  type « séance ». En ligne (salle LiveKit) ou en présentiel (lieu). Participants : des membres.
- **Ressources** : bibliothèque de la structure (fichiers et liens), jointes aux activités. Un
  entrepreneur ne voit que les ressources jointes à ses activités.
- **Assistant IA** : réservé aux admins et coachs en phase 1, dans un panneau latéral qui connaît
  le contexte ouvert (programme, cohorte, projet). Il propose des actions ; rien n'est exécuté sans
  confirmation. Consommation limitée par le plan d'abonnement.
- **Abonnement** : plans Freemium et Premium inchangés ; paiement PayDunya. Seul l'admin le gère.

### 6.12 Droits (résumé)

| Action | Admin | Coach | Entrepreneur |
|---|---|---|---|
| Créer, dupliquer, archiver un programme ; définir le programme suivant | ✓ | — | — |
| Éditer le contenu d'un programme | ✓ | si éditeur | — |
| Lancer, clore une cohorte ; choisir ses coachs | ✓ | — | — |
| Ajuster le planning, appliquer les modifications du programme | ✓ | ses cohortes (appliquer : si éditeur) | — |
| Inviter | tous rôles | entrepreneurs, ses cohortes | — |
| Promouvoir, changer le statut d'une participation | ✓ | — | — |
| Voir un projet et ses livrables | tous | ses cohortes | ses projets |
| Rendre un livrable, gérer ses brouillons | — | — | porteur |
| Demander une correction, valider, rouvrir | ✓ | ses cohortes | — |
| Commenter un livrable | ✓ | ses cohortes | porteur |
| Marquer une activité faite (sans livrable) | ✓ | ses cohortes | porteur |
| Ajouter une activité de cohorte ou une activité ponctuelle | ✓ | ses cohortes | — |
| Voir le tableau des projets, l'exporter en CSV | tous les projets | projets de ses cohortes | — |
| Planifier une séance | ✓ | ses cohortes | — |
| Gérer la bibliothèque de ressources | ✓ | ✓ | — |
| Assistant IA | ✓ | ✓ | — |
| Paramètres de la structure, abonnement | ✓ | — | — |

Toutes ces règles sont vérifiées côté serveur, sur chaque route.

---

## 7. Écrans

**Huit écrans en tout.** Tout le reste est un panneau latéral (adressable par l'URL) ou une
fenêtre de confirmation.

| # | Écran | Rôles | Ce qu'on y fait | Pourquoi ce n'est pas un panneau ou une section d'un autre écran |
|---|---|---|---|---|
| 1 | **Accès** | public | Se connecter, créer sa structure, accepter une invitation, réinitialiser son mot de passe. Ce sont des états d'un même écran. | Avant la connexion, il n'existe aucun écran autour dans lequel ouvrir un panneau. |
| 2 | **Accueil** | admin, coach | Voir ce qui demande une action dans **tous** ses programmes : alertes (§ 6.9), livrables à relire, prochaines séances, et la liste « premiers pas » au premier usage. | Il agrège plusieurs programmes : il ne peut pas appartenir à la page d'un seul programme. C'est le point d'entrée après connexion. |
| 3 | **Programme** | admin, coach | Onglet **Vue d'ensemble** (tableau de bord : alertes, cohortes, répartition par étape) et onglet **Contenu** (éditeur des étapes et activités). Cohortes, projets, livrables, activités s'ouvrent en panneaux. | C'est l'objet central ; le tableau de bord et l'éditeur par glisser-déposer ont besoin de toute la largeur. |
| 4 | **Mon parcours** | entrepreneur | Voir où il en est et quoi faire maintenant, ouvrir ses activités et livrables en panneaux. | C'est le point d'entrée de l'entrepreneur ; il n'a pas d'autre écran dans lequel le placer. |
| 5 | **Document** | entrepreneur (édition), coach et admin (lecture et commentaires) | Remplir un Business Model Canvas, un business plan ou un pitch deck ; enregistrement automatique ; rendre. | Un canevas à 9 blocs, un plan long ou des diapositives demandent tout l'écran et un mode concentré ; un panneau serait trop étroit. |
| 6 | **Séance** | participants | La salle de visio LiveKit. | La vidéo occupe tout l'écran et doit rester ouverte pendant la séance, indépendamment de la navigation. |
| 7 | **Projets** | admin, coach | Le tableau de tous les projets de la structure (le coach : ceux de ses cohortes), y compris terminés, à revoir et abandonnés. Filtres, tri, colonnes au choix, export CSV. Un clic ouvre le panneau du projet. | Il traverse tous les programmes et toutes les cohortes : aucun autre écran ne le contient. Un tableau filtrable de plusieurs dizaines de lignes, avec ses colonnes, a besoin de toute la largeur. |
| 8 | **Paramètres de la structure** | admin | Sections : Profil, Membres et invitations, Accompagnement (seuils § 6.9), Abonnement et consommation IA. | Plusieurs sections administratives avec des tableaux (membres) ; rarement visitées ; trop larges pour un panneau et sans lien avec un programme. |

La console du super-admin reste un écran à part, hors refonte.

### 7.1 L'écran Programme en détail

**Onglet Vue d'ensemble**, de haut en bas :

1. **Alertes** (en premier, repliées s'il n'y en a aucune) : livrables en retard, projets bloqués,
   retours en attente, avec leur nombre et les éléments les plus urgents. Filtrées sur les
   cohortes visibles par l'utilisateur.
2. **Cohortes**, groupées En cours, À venir, Terminées. Pour chacune : nom, dates, coachs, nombre
   de projets, progression moyenne. « Lancer une cohorte » en tête de groupe.
3. **Répartition des projets par étape** : une barre par étape (nombre de projets en cours),
   pour voir où ça bloque ; filtre par cohorte. Un clic sur une étape liste ses projets.

Un clic sur une cohorte, un projet ou une alerte ouvre le **panneau** correspondant ; l'écran ne
change pas.

**Onglet Contenu** : l'éditeur décrit au § 5.2. Le menu « … » du programme donne : Renommer,
Programme suivant, Coachs éditeurs, Dupliquer, Archiver.

### 7.2 L'écran Projets en détail

- **Colonnes disponibles** : projet, porteurs, programme, cohorte, étape en cours, progression,
  statut de la participation, livrables en retard, retours en attente, bloqué depuis (jours),
  dernière activité, coachs. Par défaut : projet, programme, cohorte, étape en cours, progression,
  statut. Le choix des colonnes est mémorisé pour chaque utilisateur.
- **Filtres** : programme, cohorte, statut (en cours, terminé, à revoir, abandonné), en retard,
  bloqué ; recherche par nom de projet ou de porteur. Les filtres se reflètent dans l'URL.
- **Tri** sur chaque colonne ; **pagination** côté serveur.
- **Export CSV** : toutes les lignes correspondant aux filtres en cours, avec les colonnes
  affichées, dans la limite des droits de l'utilisateur.
- Chaque projet apparaît avec sa participation la plus récente ; son historique complet est dans
  le panneau.

### 7.3 Panneaux

| Panneau | Ouvert depuis | Contenu |
|---|---|---|
| **Cohorte** | Programme, Accueil, ⌘K | Projets (avec progression et étape en cours), invitations en attente, planning, coachs, activités de cohorte, différences avec le programme, actions : inviter, promouvoir, clore. |
| **Projet** | Projets, programme, cohorte, alertes, ⌘K | Chemin du projet, porteurs, progression par étape, livrables, activités ponctuelles, historique des participations, statut. |
| **Activité** | Contenu du programme, Mon parcours | Consigne, ressources, échéance, livrable attendu ; côté entrepreneur : « Marquer comme fait » ou « Rendre ». |
| **Livrable** | Projet, Accueil, alertes, Mon parcours | Statut, versions, fil de commentaires, actions selon le rôle. |
| **Membre** | Paramètres, cohorte, ⌘K | Rôle, cohortes, projets, invitation. |
| **Bibliothèque de ressources** | Contenu du programme, ⌘K | Ajouter, rechercher, joindre une ressource. |
| **Assistant IA** | partout (admin, coach) | Conversation contextuelle, actions proposées à confirmer. |
| **Notifications** | cloche | Liste, tout marquer comme lu. |
| **Mon compte** | menu du compte | Profil, mot de passe, préférences de notification, structures. |

---

## 8. Premier usage, notifications, gestes communs

- **Premiers pas** (admin, sur l'Accueil, jusqu'à ce que tout soit fait) : créer un programme,
  ajouter des étapes, inviter un coach, lancer une cohorte, inviter des entrepreneurs.
  **Entrepreneur** : à la première connexion, Mon parcours affiche une courte présentation de
  l'écran, que l'on peut fermer.
- **Notifications** (dans l'application, et par email selon les préférences) : invitation reçue,
  livrable rendu (coachs), correction demandée et livrable validé (porteurs), nouveau commentaire,
  échéance dans 2 jours, séance planifiée ou modifiée.
- **Gestes communs** : ⌘K partout ; **N** nouvel élément dans la liste qui a le focus ; **⌘D**
  dupliquer ; **Suppr** supprimer ; **Échap** fermer un panneau ; menu « … » sur chaque élément.
  Toute action destructrice demande une confirmation, ou propose « Annuler » quand l'action est
  réversible (suppression d'une étape ou d'une activité du programme, archivage, retrait d'un
  membre). Jamais de `confirm()` du navigateur.
- **États vides** : chaque liste vide dit quoi faire, avec le bouton correspondant.
- **Chargement** : squelettes à la forme du contenu ; les actions s'affichent immédiatement et se
  corrigent en cas d'erreur.

---

## 9. Cas de référence : la Fabrique 360 (Simplon Sénégal)

Ce cas sert de fil rouge et sera reproduit à l'identique dans les données de démonstration
(profil `dev`).

### 9.1 Programmes, enchaînés par « programme suivant »

**Pré-incubation** → **Incubation** → **Post-incubation / Accélération**

| Programme | Étape | Activités (type · livrable attendu) |
|---|---|---|
| Pré-incubation | Validation de l'idée | Formuler le problème (tâche · texte) ; Mener 10 entretiens clients (tâche · fichier, J+14) ; Atelier idéation (atelier · aucun) |
| | Proposition de valeur | Atelier proposition de valeur (séance · aucun) ; Business Model Canvas v1 (tâche · document BMC, J+30) |
| | Prototype MVP | Définir le périmètre du MVP (tâche · texte) ; Construire le prototype (tâche · lien, J+60) |
| | Pitch initial | Pitch deck v1 (tâche · document pitch deck, J+80) ; Pitch devant le jury (séance · aucun) |
| Incubation | Développement produit | Feuille de route produit (tâche · fichier) ; Tests utilisateurs (tâche · fichier) |
| | Marché et clients | Étude de marché (tâche · fichier) ; Stratégie d'acquisition (tâche · texte) |
| | Business model avancé | Business plan (tâche · document business plan) ; Business Model Canvas v2 (tâche · document BMC) |
| | Mentorat stratégique | Séances de mentorat (séance · aucun) ; Plan d'action à 6 mois (tâche · texte) |
| Post-incubation / Accélération | Croissance | Indicateurs de traction (tâche · fichier) ; Plan de croissance (tâche · texte) |
| | Gouvernance | Statuts et pacte d'associés (tâche · fichier) ; Constitution d'un comité consultatif (atelier · aucun) |
| | Financements | Pitch deck investisseurs (tâche · document pitch deck) ; Plan de financement (tâche · fichier) |
| | Stratégie de partenariats et d'expansion | Cartographie des partenaires (tâche · texte) ; Plan d'expansion (tâche · fichier) |

### 9.2 Membres

- 1 admin (la responsable du programme), 3 coachs (dont un éditeur des trois programmes), environ
  14 entrepreneurs. Mot de passe de démonstration commun, affiché au démarrage en profil `dev`.

### 9.3 Cohortes et projets

| Programme | Cohorte | Statut | Projets |
|---|---|---|---|
| Pré-incubation | Cohorte 2026-A | Terminée | 6 projets : 3 **promus** vers Incubation, 1 **terminé**, 1 **à revoir**, 1 **abandonné** |
| Pré-incubation | Cohorte 2026-B | En cours | 5 projets à différentes étapes, avec : 2 livrables en retard, 1 projet bloqué, 3 livrables rendus en attente de retour (dont 1 au-delà du délai), 1 livrable à corriger ; 1 activité de cohorte (« Atelier fiscalité ») et 1 activité ponctuelle pour un projet |
| Pré-incubation | Cohorte 2027-A | À venir | 2 invitations en attente |
| Incubation | Cohorte 2026 | En cours | Les 3 projets promus depuis la 2026-A (leur chemin affiche « Pré-incubation ✓ → Incubation (en cours) ») et 1 projet entré directement |
| Post-incubation / Accélération | Cohorte 2027 | À venir | aucun projet |

Les livrables de démonstration incluent au moins un Business Model Canvas, un business plan et un
pitch deck remplis, avec plusieurs versions et un fil de commentaires.

---

## 10. Décisions

Ces points découlaient des consignes sans y être tranchés. État après relecture (20/11/2026).

| # | Décision | État | Raison |
|---|---|---|---|
| D1 | **Les « missions » disparaissent** comme notion : ce qu'on fait est une **activité**. Les anciennes missions assignées à un projet deviennent des **activités ponctuelles** (§ 6.5). | Validée | Une seule façon de décrire le travail à faire ; le module « missions » est conservé dans son usage, pas comme concept séparé. |
| D2 | **Le contenu issu du programme ne se modifie pas dans la cohorte** : seulement via le programme et « appliquer les modifications ». Dans la cohorte, on ajuste le planning et les coachs, et on ajoute des **activités de cohorte** (pour toute la cohorte) et des **activités ponctuelles** (pour un projet). | Validée, avec l'ajout des activités de cohorte | Une seule façon de modifier le modèle, tout en laissant le coach adapter sa cohorte. |
| D3 | **Pas d'écran « liste des programmes »** : la barre latérale est la liste. | Validée | Moins d'écrans ; le nombre de programmes par structure reste faible. |
| D4 | **Écran Projets** : tableau de tous les projets (le coach : ceux de ses cohortes), filtres, tri, colonnes au choix, export CSV ; détail en panneau. | Proposition initiale refusée, remplacée par l'écran Projets (§ 7) | Retrouver et suivre les projets à travers tous les programmes ; c'est le 8ᵉ écran. |
| D5 | **Ressources** : une bibliothèque en panneau, pas d'écran dédié. | Validée | Les ressources servent dans les activités ; on les gère là où on les utilise. |
| D6 | **Coachs éditeurs** : un coach n'édite le contenu d'un programme que si l'admin l'a désigné éditeur. | Validée | Évite que tous les coachs modifient le modèle commun. |
| D7 | **Le coach peut inviter des entrepreneurs** dans ses cohortes, pas des coachs ni des admins. | Validée | Correspond à la pratique ; reste un seul mécanisme d'invitation. |
| D8 | **Invitations nominatives uniquement** (pas de lien anonyme partageable). | Validée | Plus sûr ; un seul mécanisme. |
| D9 | **Le super-admin n'accède pas au contenu** d'accompagnement des structures. | Validée | Confidentialité des données des structures. |
| D10 | **Hors phase 1** : export PDF des documents, notes internes des coachs sur un projet, durée prévue par étape (seuil de blocage par étape), visibilité entre projets d'une même cohorte. | Validée | Garder la phase 1 resserrée. |

**Prévu dans le modèle de données sans être construit** (étape 3) : coach indépendant (une
structure d'une seule personne), catalogue public (un programme « publiable »), bailleurs (une
organisation qui suit des structures financées), équipe projet (plusieurs porteurs, déjà inclus).
