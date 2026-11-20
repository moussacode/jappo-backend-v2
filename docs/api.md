# JAPPO : architecture de l'API v1 (étape 4)

Statut : proposition, à valider avant le design system (étape 5).
Sources : `docs/produit.md` (rôles, parcours, droits) et `docs/modele-donnees.md` (schéma).

---

## 1. Conventions

| Sujet | Règle |
|---|---|
| Base | `/api/v1`. Le numéro de version ne change que pour une rupture de contrat. |
| Structure active | **Dans le chemin** : `/api/v1/orgs/{orgId}/…`. Plus d'en-tête `X-Structure-Id`. Le chemin est explicite, visible dans les journaux, utilisable dans un lien (export CSV, fichier) ; un même utilisateur peut avoir deux onglets sur deux structures. |
| Ressources | Noms au pluriel, en anglais, en `kebab-case` : `/programs`, `/cohort-activities`. |
| Actions | Une transition d'état est un `POST` sur un sous-chemin verbal : `/approve`, `/promote`, `/close`. Jamais un `PATCH` du champ `status`. |
| JSON | `camelCase`. Les propriétés inconnues sont **refusées** (400), pour qu'une faute de frappe ne passe pas en silence. |
| Identifiants | UUID en texte (`"0193f6c2-…"`). |
| Dates | Instants en ISO 8601 UTC (`2026-11-20T10:00:00Z`) ; dates sans heure en `YYYY-MM-DD`, dans le fuseau de la structure. |
| Valeurs calculées | Renvoyées dans les réponses (`status`, `progress`, `currentStep`…), jamais acceptées en entrée. |
| Méthodes | `GET` lit ; `POST` crée ou déclenche une action ; `PATCH` modifie partiellement ; `PUT` remplace un ensemble (liste de coachs, brouillon) ; `DELETE` retire. |
| Verrou optimiste | Les objets édités à plusieurs (programme, cohorte, livrable) renvoient `version` ; un `PATCH` doit la renvoyer. Si elle a changé entre-temps : 409 `VERSION_CONFLICT`. |

---

## 2. Authentification et sessions

- **Jeton d'accès** : JWT signé, durée **15 minutes**, dans l'en-tête `Authorization: Bearer …`.
  Le front-end le garde **en mémoire seulement** (pas de `localStorage`). Contenu : identifiant
  du compte et `tokenVersion`, rien d'autre (les rôles dépendent de la structure, vérifiés à
  chaque requête).
- **Jeton de renouvellement** : cookie `httpOnly`, `Secure`, `SameSite=Strict`, limité au chemin
  `/api/v1/auth`, durée 14 jours. **Rotation** à chaque usage ; réutilisation d'un jeton déjà
  remplacé : toute la famille est révoquée et la personne doit se reconnecter.
- **Révocation** : « Se déconnecter » révoque la famille du jeton ; « Se déconnecter partout » et
  le changement de mot de passe incrémentent `tokenVersion`, ce qui invalide tous les jetons
  d'accès en moins de 15 minutes et tous les jetons de renouvellement immédiatement.
- **Protection CSRF** : seul `/auth/refresh` lit un cookie. Il exige `SameSite=Strict`, un
  en-tête `Origin` égal à l'URL du front-end et l'en-tête `X-Requested-With: jappo`.
- **Mots de passe** : 10 caractères minimum, refus des mots de passe trop courants (liste
  embarquée), BCrypt. Pas d'autres règles de composition.
- **Connexion Google** : jeton Google vérifié côté serveur, rattaché à `google_subject`.

---

## 3. Droits

### 3.1 Notation utilisée dans les tableaux

| Code | Qui |
|---|---|
| **P** | Public, sans connexion |
| **U** | Toute personne connectée |
| **A** | Admin de la structure |
| **C** | Coach de la structure (toutes ses cohortes) |
| **C·c** | Coach **de la cohorte concernée** |
| **C·é** | Coach **éditeur du programme concerné** |
| **E·p** | Entrepreneur **porteur du projet concerné** |
| **E·c** | Entrepreneur ayant une participation dans la **cohorte concernée** |
| **M** | Tout membre actif de la structure |
| **SA** | Super-admin de la plateforme |

L'admin peut tout ce que peut un coach : partout où figure **C·c**, l'admin est aussi autorisé.

### 3.2 Comment c'est appliqué

1. **Authentification** : filtre JWT (jeton valide, `tokenVersion` à jour, compte non désactivé).
2. **Adhésion** : pour toute route `/orgs/{orgId}/…`, un filtre vérifie que le compte a un membre
   **actif** dans cette structure, puis fixe la structure active pour Hibernate (`@TenantId`).
   Sinon : **404** (on ne révèle pas l'existence d'une structure).
3. **Rôle et périmètre** : **une seule syntaxe**, une annotation par route,
   `@Authorize(Action.X)`. Elle délègue à une **politique d'accès par module**
   (`ProgramPolicy`, `CohortPolicy`, `DeliverablePolicy`…) qui sait répondre aux questions
   « est-il coach de cette cohorte ? », « est-il porteur de ce projet ? ». Plus aucun
   `hasRole` / `hasAuthority` mélangés, plus aucune vérification écrite dans un contrôleur.
4. **Objet d'une autre structure** ou **non visible** pour ce rôle : **404**, jamais 403. Le 403
   est réservé au cas où la personne voit l'objet mais n'a pas le droit d'agir dessus (un coach
   qui tente de promouvoir, par exemple).
5. **Test** : les tableaux de droits du § 8 sont recopiés dans un test de matrice qui appelle
   chaque route avec chaque rôle et vérifie le code attendu.

---

## 4. Format des réponses

### 4.1 Objet seul

L'objet est renvoyé directement, sans enveloppe.

```json
{
  "id": "0193f6c2-7a10-7c4e-9b1a-2f0c5d3e8a11",
  "name": "AgriFresh",
  "sector": "Agriculture",
  "holders": [{ "memberId": "…", "firstName": "Fatou", "lastName": "Ndiaye" }],
  "currentEnrollment": {
    "id": "…", "cohortId": "…", "cohortName": "Cohorte 2026-B", "programName": "Pré-incubation",
    "status": "IN_PROGRESS", "progress": 64, "currentStep": { "id": "…", "title": "Proposition de valeur" },
    "lateCount": 1, "pendingReviewCount": 0, "daysInStep": 12, "stalled": false
  },
  "createdAt": "2026-03-02T09:14:00Z"
}
```

### 4.2 Liste paginée

```json
{
  "items": [ … ],
  "page": { "number": 0, "size": 50, "totalElements": 213, "totalPages": 5 }
}
```

- Paramètres : `page` (à partir de 0), `size` (défaut 50, maximum 100), `sort` répétable
  (`sort=progress,desc&sort=name,asc`). Seuls les champs listés pour chaque route sont triables ;
  un autre champ donne 400.
- Filtres : paramètres nommés (`status=IN_PROGRESS&cohortId=…&late=true&q=agri`).
- Les petites listes bornées par nature (étapes d'un programme, coachs d'une cohorte) sont
  renvoyées sans pagination, sous `items`.

### 4.3 Codes de succès

| Code | Quand |
|---|---|
| 200 | Lecture, modification, action qui renvoie l'objet modifié |
| 201 | Création, avec l'en-tête `Location` et l'objet créé |
| 204 | Suppression, action sans contenu à renvoyer |

---

## 5. Erreurs : un seul format

Toutes les erreurs, y compris celles des filtres de sécurité, utilisent le format **Problem
Details** (RFC 9457), type `application/problem+json` :

```json
{
  "type": "https://jappo.app/errors/validation-failed",
  "title": "Certaines informations sont invalides.",
  "status": 422,
  "code": "VALIDATION_FAILED",
  "detail": "Corrigez les champs indiqués.",
  "errors": [
    { "field": "plannedEndDate", "code": "DATE_BEFORE_START", "message": "La date de fin doit suivre la date de début." }
  ],
  "traceId": "4bf92f3577b34da6"
}
```

- `title` et `message` sont en français, prêts à afficher ; `code` est stable, pour le
  front-end ; `traceId` relie l'erreur aux journaux. Jamais de trace technique ni de message SQL.

| Statut | Code | Quand |
|---|---|---|
| 400 | `MALFORMED_REQUEST` | JSON invalide, propriété inconnue, paramètre de tri ou de filtre inconnu |
| 401 | `UNAUTHENTICATED` | Jeton absent, expiré ou révoqué |
| 403 | `FORBIDDEN` | L'objet est visible mais l'action n'est pas permise à ce rôle |
| 403 | `PLAN_LIMIT_REACHED` | Limite du plan atteinte (ex. cohortes non closes) |
| 404 | `NOT_FOUND` | Objet inexistant, d'une autre structure, ou non visible pour ce rôle |
| 409 | `VERSION_CONFLICT` | Quelqu'un a modifié l'objet entre-temps |
| 409 | `INVALID_TRANSITION` | Transition d'état impossible (ex. valider un livrable « à rendre ») |
| 409 | `HAS_HISTORY` | Suppression refusée : l'objet a un historique (§ 12 du modèle) ; la réponse indique l'alternative (archiver, détacher, rendre facultative) |
| 409 | `DUPLICATE` | Doublon (invitation en attente pour cet email, nom de cohorte déjà pris) |
| 413 | `FILE_TOO_LARGE` | Fichier de plus de 25 Mo |
| 415 | `UNSUPPORTED_FILE_TYPE` | Type de fichier hors de la liste autorisée (type détecté sur le contenu) |
| 422 | `VALIDATION_FAILED` | Données bien formées mais invalides, avec la liste `errors` |
| 429 | `RATE_LIMITED` | Trop de requêtes ; en-tête `Retry-After` |
| 429 | `AI_QUOTA_EXHAUSTED` | Quota mensuel de l'assistant atteint |
| 500 | `INTERNAL_ERROR` | Erreur inattendue (message générique, `traceId`) |

---

## 6. Sécurité transverse

| Sujet | Règle |
|---|---|
| Validation | Chaque corps de requête est un DTO validé (`@Valid` obligatoire, vérifié par un test d'architecture) ; longueurs maximales alignées sur le schéma ; texte riche nettoyé (OWASP Java HTML Sanitizer, liste blanche de balises). |
| Limitation de débit | Par IP et par compte (Bucket4j, en mémoire : une seule instance sur le VPS). Connexion : 5 par minute par IP et par email. Mot de passe oublié : 3 par heure par email. Inscription : 5 par heure par IP. Assistant IA : 20 messages par minute par compte. Téléversement : 30 par minute par compte. Global : 300 requêtes par minute par compte. |
| Fichiers | Liste blanche (PDF, images PNG/JPEG/WebP, documents Office et OpenDocument, CSV, ZIP) ; type **détecté sur le contenu** (Tika), pas sur l'extension ; 25 Mo maximum ; nom de stockage aléatoire ; servis avec `Content-Disposition: attachment` et `X-Content-Type-Options: nosniff`. |
| CORS | Une seule origine : `APP_FRONTEND_URL`. `credentials` autorisés (cookie de renouvellement). |
| En-têtes | `Strict-Transport-Security`, `X-Content-Type-Options`, `Referrer-Policy: same-origin`, `Content-Security-Policy` stricte côté front-end. |
| Journaux | Jamais de jeton, de mot de passe ni de contenu de livrable. Identifiant de trace sur chaque requête. Pas de SQL affiché en production. |
| Énumération | Mot de passe oublié et inscription répondent de la même façon que l'email existe ou non. |
| Paiement | Le retour PayDunya est vérifié (signature et appel de confirmation au fournisseur) avant de modifier l'abonnement ; idempotent sur la référence. |
| Idempotence | En-tête `Idempotency-Key` accepté sur les créations sensibles au double clic : rendu de livrable, invitations groupées, paiement. |

---

## 7. Temps réel (WebSocket)

- Point d'entrée `/ws` (STOMP). La connexion exige le jeton d'accès dans l'en-tête STOMP
  `Authorization` ; sinon elle est refusée.
- Abonnement autorisé à **une seule destination** : `/user/queue/events`, propre à l'utilisateur
  connecté. Tout autre abonnement est refusé.
- Chaque événement porte `orgId`, `type` et un objet minimal ; le front-end ne recharge que ce qui
  le concerne.

| Type | Destinataires |
|---|---|
| `notification.created` | Le membre notifié |
| `deliverable.submitted` | Coachs de la cohorte et admins |
| `deliverable.changes_requested`, `deliverable.approved`, `deliverable.reopened` | Porteurs du projet |
| `deliverable.comment_created` | Porteurs et coachs de la cohorte, sauf l'auteur |
| `meeting.scheduled`, `meeting.updated`, `meeting.cancelled` | Participants |
| `invitation.accepted` | La personne qui a invité |

---

## 8. Routes par module

Sauf indication, les chemins commencent par `/api/v1/orgs/{orgId}`. Dans la colonne Droits,
« A, C·c » signifie : admin, ou coach de la cohorte concernée.

### 8.1 Authentification et compte (hors structure, préfixe `/api/v1`)

| Méthode | Chemin | Droits | Rôle |
|---|---|---|---|
| POST | `/auth/signup` | P | Créer son compte **et** sa structure (devient admin) |
| POST | `/auth/login` | P | Connexion email + mot de passe ; renvoie le jeton d'accès, pose le cookie |
| POST | `/auth/google` | P | Connexion ou inscription Google |
| POST | `/auth/refresh` | P (cookie) | Nouveau jeton d'accès, rotation du cookie |
| POST | `/auth/logout` | U | Révoque la famille du jeton de renouvellement |
| POST | `/auth/logout-everywhere` | U | Incrémente `tokenVersion` |
| POST | `/auth/password/forgot` | P | Envoie un lien de réinitialisation (réponse identique dans tous les cas) |
| POST | `/auth/password/reset` | P | Nouveau mot de passe avec le jeton reçu |
| POST | `/auth/email/verify` | P | Valide l'adresse avec le jeton reçu |
| POST | `/auth/email/resend` | U | Renvoie l'email de vérification |
| GET | `/invitations/{token}` | P | Informations de l'invitation (structure, rôle, cohorte) |
| POST | `/invitations/{token}/accept` | P ou U | Crée le compte si besoin, crée le membre, et pour un entrepreneur le projet et sa participation |
| GET | `/me` | U | Profil et liste des structures (rôle dans chacune) |
| PATCH | `/me` | U | Nom, prénom, langue |
| POST | `/me/password` | U | Changer de mot de passe (ancien requis) ; révoque les autres sessions |
| GET, PUT | `/me/notification-preferences` | U | Préférences par type d'événement |
| GET | `/document-templates` | U | Modèles de documents (BMC, business plan, pitch deck) et leur définition |
| GET | `/plans` | P | Plans d'abonnement publics |
| POST | `/webhooks/paydunya` | P (signé) | Retour de paiement PayDunya |

### 8.2 Structure, membres, invitations

| Méthode | Chemin | Droits | Rôle |
|---|---|---|---|
| GET | `` (la structure) | M | Profil, fuseau, seuils d'alerte |
| PATCH | `` | A | Profil, fuseau, `stalledThresholdDays`, `reviewDelayDays` |
| PUT | `/logo` | A | Remplacer le logo (fichier déjà téléversé) |
| GET | `/members` | A ; C (coachs, et entrepreneurs de ses cohortes) | Liste paginée, filtres `role`, `q`, `cohortId` ; tri `name`, `joinedAt` |
| GET | `/members/{id}` | A ; C (même périmètre) | Membre, ses cohortes et projets |
| PATCH | `/members/{id}` | A | Changer le rôle (refusé si c'est le dernier admin) |
| DELETE | `/members/{id}` | A | Retirer (`removed_at`), ou supprimer s'il n'a aucun historique |
| GET | `/invitations` | A ; C·c | Invitations, filtres `status`, `cohortId` |
| POST | `/invitations` | A (tout rôle) ; C·c (entrepreneurs de ses cohortes) | Créer une ou plusieurs invitations (`items[]`) ; réponse ligne par ligne |
| POST | `/invitations/{id}/resend` | A ; auteur | Nouveau jeton, nouvelle date d'expiration |
| DELETE | `/invitations/{id}` | A ; auteur | Annuler (`revoked_at`) |

### 8.3 Programmes et contenu

| Méthode | Chemin | Droits | Rôle |
|---|---|---|---|
| GET | `/programs` | A, C | Programmes dans l'ordre de leur chaîne (barre latérale) ; `archived=true` pour les archivés |
| POST | `/programs` | A | Créer |
| GET | `/programs/{id}` | A, C | Détails, programme suivant, éditeurs, nombre de cohortes |
| PATCH | `/programs/{id}` | A | Titre, description, programme suivant (refus si boucle) |
| PUT | `/programs/{id}/editors` | A | Liste des coachs éditeurs |
| POST | `/programs/{id}/duplicate` | A | Copie du contenu, sans cohortes |
| POST | `/programs/{id}/archive`, `/unarchive` | A | Archiver, désarchiver |
| DELETE | `/programs/{id}` | A | Corbeille si aucune cohorte, sinon 409 `HAS_HISTORY` |
| POST | `/programs/{id}/restore` | A | Annuler la suppression |
| GET | `/programs/{id}/dashboard` | A, C (ses cohortes seulement) | **Tableau de bord** en une réponse : alertes, cohortes par statut, répartition par étape ; filtre `cohortId` |
| GET | `/programs/{id}/content` | A, C | Étapes et activités, dans l'ordre |
| POST | `/programs/{id}/steps` | A, C·é | Ajouter une étape (position facultative, sinon en fin) |
| PATCH | `/steps/{id}` | A, C·é | Titre, description |
| POST | `/steps/{id}/move` | A, C·é | `{ "position": 2 }` ; renvoie le nouvel ordre |
| POST | `/steps/{id}/duplicate` | A, C·é | Copie de l'étape et de ses activités, juste après |
| DELETE | `/steps/{id}` | A, C·é | Corbeille (avec ses activités) |
| POST | `/steps/{id}/restore` | A, C·é | Annuler |
| POST | `/steps/{id}/activities` | A, C·é | Ajouter une activité |
| PATCH | `/activities/{id}` | A, C·é | Titre, description, type, obligatoire, échéance relative, livrable attendu |
| POST | `/activities/{id}/move` | A, C·é | `{ "stepId": "…", "position": 0 }` : réordonner ou changer d'étape |
| POST | `/activities/{id}/duplicate` | A, C·é | Copie juste après |
| DELETE | `/activities/{id}` | A, C·é | Corbeille |
| POST | `/activities/{id}/restore` | A, C·é | Annuler |
| PUT | `/activities/{id}/resources` | A, C·é | Ressources jointes |

### 8.4 Cohortes

| Méthode | Chemin | Droits | Rôle |
|---|---|---|---|
| GET | `/cohorts` | A ; C (les siennes) | Filtres `programId`, `status` (`UPCOMING`, `IN_PROGRESS`, `CLOSED`) |
| POST | `/programs/{id}/cohorts` | A | **Lancer** : nom, dates, coachs ; copie le contenu (403 `PLAN_LIMIT_REACHED` si la limite est atteinte) |
| GET | `/cohorts/{id}` | A, C·c | Cohorte, coachs, compteurs |
| PATCH | `/cohorts/{id}` | A | Nom, date de début (recalcule les échéances non ajustées), date de fin prévue |
| PUT | `/cohorts/{id}/facilitators` | A | Coachs de la cohorte |
| GET | `/cohorts/{id}/content` | A, C·c, E·c | Contenu de la cohorte avec échéances effectives ; pour un entrepreneur, sans les activités ponctuelles des autres projets |
| GET | `/cohorts/{id}/enrollments` | A, C·c | Projets de la cohorte, progression, étape en cours, retards |
| GET | `/cohorts/{id}/program-diff` | A, C·c | Différences avec le programme |
| POST | `/cohorts/{id}/apply-program-changes` | A ; C·c qui est aussi C·é | Appliquer toutes les différences |
| POST | `/cohorts/{id}/close` | A | Clore : une issue par participation en cours (`COMPLETED`, `ON_HOLD`, `DROPPED`, ou `PROMOTE` avec `targetCohortId`) |
| DELETE | `/cohorts/{id}` | A | Seulement sans historique, sinon 409 `HAS_HISTORY` |
| POST | `/cohort-steps/{id}/activities` | A, C·c | Ajouter une activité de cohorte (`origin: COHORT`) ou ponctuelle (`origin: ENROLLMENT` + `enrollmentId`) |
| PATCH | `/cohort-activities/{id}` | A, C·c | Origine PROGRAM : seulement `dueDateOverride` ; autres origines : tous les champs |
| POST | `/cohort-activities/{id}/move` | A, C·c | Origines COHORT et ENROLLMENT seulement |
| DELETE | `/cohort-activities/{id}` | A, C·c | Origines COHORT et ENROLLMENT, sans historique ; sinon 409 `HAS_HISTORY` |
| POST | `/cohort-activities/{id}/restore` | A, C·c | Annuler |

### 8.5 Projets et participations

| Méthode | Chemin | Droits | Rôle |
|---|---|---|---|
| GET | `/projects` | A ; C (projets de ses cohortes) | **Écran Projets**. Filtres `programId`, `cohortId`, `status` (`IN_PROGRESS`, `COMPLETED`, `ON_HOLD`, `DROPPED`), `late`, `stalled`, `q` ; tri `name`, `program`, `cohort`, `progress`, `currentStep`, `status`, `lateCount`, `pendingReviewCount`, `daysInStep`, `lastActivityAt` |
| GET | `/projects/export.csv` | A ; C (même périmètre) | Mêmes filtres et tri ; `columns` = colonnes affichées ; CSV UTF-8 en flux |
| GET | `/projects/{id}` | A, C·c, E·p | Projet, porteurs, **chemin**, participations |
| PATCH | `/projects/{id}` | A, E·p | Nom, description, secteur |
| PUT | `/projects/{id}/holders` | A | Porteurs (membres entrepreneurs) |
| POST | `/projects/{id}/enrollments` | A | Réintégrer dans une cohorte (projet sans participation en cours) |
| GET | `/enrollments/{id}` | A, C·c, E·p | Participation : progression par étape, état de chaque activité, échéances |
| POST | `/enrollments/{id}/end` | A | Mettre fin : `COMPLETED`, `ON_HOLD` ou `DROPPED`, motif facultatif |
| POST | `/enrollments/{id}/promote` | A | Vers une cohorte à venir ou en cours du programme suivant ; motif obligatoire si des activités obligatoires ne sont pas terminées |
| PUT | `/enrollments/{id}/completions/{cohortActivityId}` | A, C·c, E·p | Marquer faite une activité sans livrable |
| DELETE | `/enrollments/{id}/completions/{cohortActivityId}` | A, C·c, E·p | Marquer non faite |
| GET | `/my-journey` | E | **Mon parcours** : ses projets, chemin, progression, « à faire maintenant », étapes et activités, prochaine séance |
| GET | `/home` | A, C | **Accueil** : alertes de tous ses programmes, livrables à relire, prochaines séances, premiers pas |
| GET | `/search?q=` | M | Recherche ⌘K, limitée à ce que la personne peut voir |

### 8.6 Livrables

Un livrable est désigné par sa participation et son activité :
`/enrollments/{enrollmentId}/deliverables/{cohortActivityId}`. Cette adresse existe avant même le
premier enregistrement (statut `TO_SUBMIT`) : il n'y a qu'une seule façon de désigner un
livrable, qu'il ait déjà été commencé ou non.

| Méthode | Chemin (`…/enrollments/{eid}/deliverables`) | Droits | Rôle |
|---|---|---|---|
| GET | `` | A, C·c, E·p | Tous les livrables attendus de la participation, avec statut et échéance |
| GET | `/{caid}` | A, C·c, E·p | Statut, échéance effective, versions (sans contenu), droits de l'utilisateur sur ce livrable |
| GET | `/{caid}/draft` | E·p | Brouillon (texte ou document) |
| PUT | `/{caid}/draft` | E·p | Enregistrer le brouillon (enregistrement automatique) |
| DELETE | `/{caid}/draft` | E·p | Abandonner le brouillon |
| POST | `/{caid}/submissions` | E·p | **Rendre** : à partir du brouillon, ou avec `fileId` / `url` ; crée la version suivante ; 409 si le statut ne le permet pas |
| GET | `/{caid}/versions/{number}` | A, C·c, E·p | Contenu d'une version |
| GET | `/{caid}/versions/{number}/file` | A, C·c, E·p | Fichier de la version |
| GET | `/{caid}/comments` | A, C·c, E·p | Fil, dans l'ordre |
| POST | `/{caid}/comments` | A, C·c, E·p | Commenter (avec `versionNumber` facultatif) |
| PATCH | `/{caid}/comments/{commentId}` | auteur, 15 minutes | Modifier son commentaire |
| DELETE | `/{caid}/comments/{commentId}` | auteur, 15 minutes | Supprimer son commentaire (« message supprimé ») |
| POST | `/{caid}/request-changes` | A, C·c | Texte obligatoire, `correctionDueDate` facultative |
| POST | `/{caid}/approve` | A, C·c | Valider (texte facultatif) |
| POST | `/{caid}/reopen` | A, C·c | Rouvrir un livrable validé (texte obligatoire) |

L'écran **Document** utilise ces mêmes routes : la définition du modèle vient de
`/document-templates`, le contenu du brouillon ou de la version.

### 8.7 Ressources et fichiers

| Méthode | Chemin | Droits | Rôle |
|---|---|---|---|
| POST | `/files` | M | Téléverser (multipart) ; renvoie `id`, nom, type détecté, taille. Le fichier reste privé à son auteur tant qu'il n'est rattaché à rien ; purgé s'il reste orphelin |
| GET | `/resources` | A, C | Bibliothèque, filtres `q`, `kind`, `archived` ; tri `title`, `createdAt` |
| POST | `/resources` | A, C | Créer (lien, ou fichier déjà téléversé) |
| PATCH | `/resources/{id}` | A, C | Titre, description |
| POST | `/resources/{id}/archive`, `/unarchive` | A, C | Archiver, désarchiver |
| DELETE | `/resources/{id}` | A, C | Seulement si jamais jointe, sinon 409 `HAS_HISTORY` |
| GET | `/resources/{id}/file` | A, C ; E (si jointe à une activité de sa cohorte) | Télécharger |
| GET | `/logo` | M | Logo de la structure |

Un fichier ne se télécharge que **par l'objet qui le contient** (version de livrable, ressource,
logo), avec les droits de cet objet. Il n'y a pas de route générique de téléchargement.

### 8.8 Séances

| Méthode | Chemin | Droits | Rôle |
|---|---|---|---|
| GET | `/meetings` | A (toutes) ; C, E (les siennes) | Filtres `from`, `to`, `cohortId`, `enrollmentId` |
| POST | `/meetings` | A, C·c | Planifier (en ligne ou en présentiel, participants, rattachement facultatif) |
| GET | `/meetings/{id}` | A, participants | Détails |
| PATCH | `/meetings/{id}` | A, animateur | Modifier, compte rendu |
| PUT | `/meetings/{id}/participants` | A, animateur | Participants |
| POST | `/meetings/{id}/cancel` | A, animateur | Annuler |
| POST | `/meetings/{id}/join` | participants | Jeton LiveKit et adresse de la salle (refusé hors de la plage horaire élargie de 15 minutes) |

### 8.9 Assistant IA

| Méthode | Chemin | Droits | Rôle |
|---|---|---|---|
| GET | `/ai/conversations` | A, C (les siennes) | Conversations, `archived=true` pour les archivées |
| POST | `/ai/conversations` | A, C | Créer, avec le contexte (`programId`, `cohortId`, `projectId`) |
| GET | `/ai/conversations/{id}` | propriétaire | Conversation et messages |
| POST | `/ai/conversations/{id}/messages` | propriétaire | Envoyer un message ; renvoie la réponse et les actions proposées (429 si quota ou débit) |
| POST | `/ai/conversations/{id}/archive` | propriétaire | Archiver |
| DELETE | `/ai/conversations/{id}` | propriétaire | Supprimer (le journal de consommation reste) |
| POST | `/ai/pending-actions/{id}/confirm` | propriétaire | Exécuter l'action, **avec les droits normaux** de la personne |
| POST | `/ai/pending-actions/{id}/reject` | propriétaire | Refuser |
| GET | `/ai/usage` | A | Consommation du mois par rapport au quota |

Une action proposée par l'IA passe par les mêmes services et les mêmes vérifications de droits que
si la personne l'avait faite à la main.

### 8.10 Abonnement, notifications

| Méthode | Chemin | Droits | Rôle |
|---|---|---|---|
| GET | `/subscription` | A | Période courante, plan, limites, historique des périodes et paiements |
| POST | `/subscription/checkout` | A | Démarrer un paiement pour un plan ; renvoie l'adresse PayDunya |
| GET | `/notifications` | M | Ses notifications, `unread=true` ; tri `createdAt` |
| POST | `/notifications/{id}/read` | destinataire | Marquer comme lue |
| POST | `/notifications/read-all` | M | Tout marquer comme lu |

### 8.11 Super-admin (préfixe `/api/v1/admin`)

| Méthode | Chemin | Droits | Rôle |
|---|---|---|---|
| GET | `/organizations` | SA | Structures, filtres `q`, `suspended` ; tri `name`, `createdAt` |
| GET | `/organizations/{id}` | SA | Fiche : plan, nombre de membres, de cohortes, consommation IA (**aucun contenu d'accompagnement**) |
| POST | `/organizations/{id}/suspend`, `/reactivate` | SA | Suspendre, réactiver |
| GET, POST | `/plans` | SA | Plans |
| PATCH | `/plans/{id}` | SA | Modifier un plan |
| POST | `/plans/{id}/archive` | SA | Archiver un plan |
| PUT | `/organizations/{id}/subscription` | SA | Attribuer un plan à la main (`source = ADMINISTRATION`) |

### 8.12 Hors API métier

| Chemin | Rôle |
|---|---|
| `GET /actuator/health` | Santé (public, sans détail) |
| `/api/v1/openapi.json` | Description OpenAPI |
| `/swagger-ui` | Documentation interactive, **en profil `dev` uniquement** |
| `/ws` | WebSocket (§ 7) |

---

## 9. Correspondance écrans ↔ routes

Chaque écran charge l'essentiel en **une** requête ; les panneaux en chargent une de plus.

| Écran ou panneau | Requête principale |
|---|---|
| Accueil | `GET /home` |
| Programme, Vue d'ensemble | `GET /programs/{id}/dashboard` |
| Programme, Contenu | `GET /programs/{id}/content` |
| Mon parcours | `GET /my-journey` |
| Projets | `GET /projects?…` |
| Document | `GET /enrollments/{eid}/deliverables/{caid}/draft` + `GET /document-templates` (en cache) |
| Paramètres | `GET ''`, `GET /members`, `GET /invitations`, `GET /subscription` (une par section) |
| Panneau Cohorte | `GET /cohorts/{id}` + `GET /cohorts/{id}/enrollments` |
| Panneau Projet | `GET /projects/{id}` |
| Panneau Livrable | `GET …/deliverables/{caid}` + `GET …/comments` |
| Barre latérale | `GET /programs`, `GET /me` |

---

## 10. OpenAPI et contrat

- Documentation générée par springdoc à partir du code, servie en `/api/v1/openapi.json`.
- Chaque route documente : ses droits (dans la description, avec la notation du § 3.1), ses
  paramètres de filtre et de tri, ses réponses d'erreur possibles avec leur `code`.
- Le front-end **génère ses types TypeScript** depuis ce fichier (`openapi-typescript`) : un
  changement de contrat casse la compilation du front-end au lieu de casser l'écran.
- Un test vérifie que le fichier OpenAPI généré ne change que volontairement (comparaison avec la
  version enregistrée dans le dépôt).

---

## 11. Organisation du code back-end

Un paquet par module, chacun découpé de la même façon :

```
sn.jappo.<module>/
  api/        contrôleurs (aucune logique : validation, appel du service, réponse)
  api/dto/    requêtes et réponses (records Java, validés)
  app/        services (règles métier, transactions) et politique d'accès
  domain/     entités et dépôts Spring Data
  read/       requêtes de lecture calculées (SQL natif autorisé ici seulement, § 15.1 du modèle)
```

Modules : `auth`, `organization` (structure, membres, invitations), `program`, `cohort`,
`project` (projets, participations, progression), `deliverable`, `resource` (ressources,
fichiers), `meeting`, `ai`, `billing` (plans, abonnements, paiements), `notification`, `admin`,
et `shared` (classe de base des entités, erreurs, sécurité, pagination).

Des tests d'architecture (ArchUnit) vérifient : contrôleurs sans dépôt ni logique, SQL natif
seulement dans `read/`, entités héritant de la classe de base, `@Valid` sur chaque corps de
requête, `@Authorize` sur chaque route.

---

## 12. Changements par rapport à l'API actuelle

| Avant | Après |
|---|---|
| ~200 routes, 36 contrôleurs, nommage mélangé (`/mon-parcours`, `/suivi`, `/progression`) | ~140 routes, un nommage unique |
| Structure active dans l'en-tête `X-Structure-Id` | Dans le chemin `/orgs/{orgId}` |
| 4 syntaxes de droits, contrôles dans certains contrôleurs | `@Authorize(Action)` + une politique par module, testées par une matrice |
| Erreurs de 6 formes différentes | Problem Details partout, codes stables |
| Pagination dans 4 fichiers | Pagination, filtres et tris homogènes sur toutes les listes |
| JWT 24 h dans `localStorage` | Jeton d'accès 15 min en mémoire + renouvellement en cookie httpOnly, révocable |
| WebSocket sans authentification, canaux devinables | Connexion authentifiée, destination personnelle uniquement |
| Fichiers servis par chemin | Téléchargement par l'objet qui les contient, avec ses droits |
| Routes de test en production | Supprimées |

---

## 13. Questions ouvertes

| # | Question | Proposition |
|---|---|---|
| Q1 | Le service `jappo-voice` est appelé directement par le front-end, sans authentification. | Hors refonte ; en production, le placer derrière le reverse proxy avec la même vérification de jeton, ou le désactiver jusqu'à son remplacement. |
| Q2 | Faut-il un domaine pour les URL `type` des erreurs ? | Utiliser le domaine final dès qu'il est connu ; `https://jappo.app/errors/…` en attendant. |
| Q3 | Durées des jetons (15 minutes, 14 jours). | Valeurs proposées ; réglables par variables d'environnement. |
