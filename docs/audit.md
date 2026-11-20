# Audit JAPPO avant refonte (étape 1)

Date : 20/11/2026. Périmètre : `jappo-backend-v2` (commit `635c71b`), `jappo-frontend-v2`
(`8f83ad4`), `jappo-ai-v2` (`1526050`), `jappo-voice-v2` (`1547abd`).
Aucun code n'a été modifié pour cet audit.

## Échelle de gravité

| Niveau | Signification |
|---|---|
| **Critique** | Faille exploitable ou fuite de données entre organisations. À corriger en premier. |
| **Élevée** | Incohérence structurante, ou obstacle direct à la phase 1. Impose une réécriture. |
| **Moyenne** | Dette qui ralentit le développement ou dégrade la qualité perçue. |
| **Faible** | Cosmétique ou ponctuel. |

## Chiffres clés

| | Back-end | Front-end |
|---|---|---|
| Volume | 37 tables, 35 entités, 45 services, 110 DTO, 36 contrôleurs, 201 routes | 56 routes, 40 services, 30 composants partagés |
| Tests | 162 tests (25 fichiers), tous verts | 61 tests (36 fichiers), tous verts, build OK |
| Signaux | 95 `@PreAuthorize` pour 201 routes ; `@Valid` sur 23 routes ; pagination dans 4 fichiers | 560 valeurs Tailwind arbitraires, 334 couleurs de palette brute, 28 `confirm()` natifs |

---

## 1. Ce qui marche et qu'on garde

**Back-end**
- Les 4 services démarrent en local, le schéma est créé par Flyway (V1) et validé par Hibernate.
- **Rôles par structure** : le rôle (ADMIN_STRUCTURE, COACH, ENTREPRENEUR) dépend de la structure
  active (`X-Structure-Id`) et d'une adhésion acceptée. Un admin de A n'a aucun droit dans B.
  C'est la bonne base pour le multi-organisation.
- `TenantFilter` refuse (403) un utilisateur qui n'est pas membre de la structure demandée, et
  protège les fichiers `/fichiers/{dossier}/{structureId}/...`.
- Des tests de sécurité existent déjà : matrice des rôles (`RoleMatrixSecurityTest`), filtre
  de structure, isolation des fichiers, accès aux projets, propriété des conversations.
- **Quotas IA par plan d'abonnement** (`QuotaService`, table `ia_usage`) et paiement PayDunya
  (sandbox), avec job d'expiration des abonnements.
- Mots de passe hachés en BCrypt, JWT signé, CORS restreint au front-end, application sans session.
- Premier modèle de document : Business Model Canvas (9 champs) via `TemplateFieldCodec`, et
  livrables attendus de type `TEMPLATE`.
- Historique des versions de livrables (`livrable_versions`).

**Front-end**
- Angular 21 avec signaux, Tailwind 4, tokens déclarés dans `@theme` (155 variables) et mode sombre.
- Des briques SaaS existent déjà : palette **⌘K** fonctionnelle, composant d'état vide (utilisé
  dans 32 fichiers), états de chargement et squelettes (12), état d'erreur (5), service de toasts,
  fil d'Ariane, cloche de notifications.
- Composant `bmc-canvas` pour remplir un Business Model Canvas.

**Services Python**
- `jappo-ai` : appel réel OpenRouter validé de bout en bout (back-end → IA → LLM), clé interne
  vérifiée, sources et actions proposées. 22 tests sur 23.
- `jappo-voice` : fonctionne (synthèse et transcription), hors périmètre.

---

## 2. Sécurité

| # | Gravité | Constat | Où |
|---|---|---|---|
| S1 | **Critique** | **WebSocket sans authentification.** `/ws/**` est en `permitAll` et aucun intercepteur STOMP ne vérifie le JWT à la connexion ni à l'abonnement. N'importe quel client, même non connecté, peut s'abonner à `/topic/structure/{id}`, `/topic/structure/{id}/cohorte/{id}` ou `/topic/user/{id}` et recevoir les événements d'une autre structure. | `SecurityConfig`, `WebSocketConfig`, `WebSocketEventService` |
| S2 | Élevée | **Isolation des données manuelle.** Chaque service relit l'objet puis compare `getStructure().getId()` à la structure active, à la main (61 `findById` suivis d'une vérification ; 103 requêtes `...AndStructureId`). Aucun mécanisme central (filtre Hibernate, dépôt « scopé »). Un oubli suffit à créer une fuite. Sans en-tête `X-Structure-Id`, aucune structure n'est fixée et c'est au service de le détecter. | tous les services |
| S3 | Élevée | **Téléversements** : seule la taille est contrôlée (50 Mo). Pas de liste blanche d'extensions ni de vérification du type réel (Tika n'est utilisé que par l'IA). Fichiers servis par le même domaine que l'API. | `FileStorageService` |
| S4 | Élevée | **Aucune limitation de débit** : connexion, mot de passe oublié, inscription, IA. Force brute possible. | absent |
| S5 | Élevée | **JWT** : durée 24 h, stocké dans `localStorage` (exposé à tout XSS), pas de jeton de rafraîchissement, pas de révocation (un changement de mot de passe n'invalide pas les jetons). | `JwtService`, `token-storage.service.ts` |
| S6 | Élevée | **Validation des entrées partielle** : `@Valid` sur 23 routes sur 201 ; 18 DTO sur 110 portent des contraintes. Politique de mot de passe : 8 caractères minimum, rien d'autre. | contrôleurs, DTO |
| S7 | Moyenne | **Routes de test en production** : `/api/test`, `/api/websocket/status`, STOMP `/app/test`. | `TestController`, `WebSocketTestController` |
| S8 | Moyenne | **Journaux bavards** : chaque requête journalise l'identifiant utilisateur et l'en-tête de structure en INFO ; `spring.jpa.show-sql=true` ; 11 `System.out.println`. | `JwtAuthenticationFilter`, `application.properties` |
| S9 | Moyenne | **Droits non homogènes** : 4 syntaxes (`hasRole`, `hasAuthority`, `hasAnyAuthority`, `hasRole or hasRole`), d'où l'astuce qui émet chaque rôle en double (`X` et `ROLE_X`). Plusieurs contrôleurs n'ont aucune annotation et reposent sur des contrôles dans le service : conversations (11 routes), réunions (7), actions IA (2), mon parcours (3), suivi (1). | contrôleurs |
| S10 | Moyenne | `jappo-ai` et `jappo-voice` acceptent toutes les origines (CORS `*`) ; `jappo-voice` n'a aucune authentification. À ne pas exposer tel quel sur le VPS. | `main.py` |

---

## 3. Modèle de données (back-end)

| # | Gravité | Constat |
|---|---|---|
| M1 | Élevée | **Quatre niveaux pour décrire un programme**, avec une table de liaison : `programmes` → `parcours` → `parcours_phases` → `phases` → `etapes`. Une phase peut être partagée entre plusieurs parcours, ce qui complique tout (ordre, droits, duplication). La cible phase 1 est plus simple : programme → étapes → activités → livrables attendus. |
| M2 | Élevée | **Redondance dans `cohortes`** : la table référence à la fois `programme_id`, `parcours_id` et `phase_id`, alors que le programme se déduit du parcours (violation de la 3NF, risque d'incohérence). |
| M3 | Élevée | **Missions éclatées sur quatre tables** : `missions_modeles`, `missions_etape`, `missions_cohorte`, `missions_projet`, chacune avec ses propres colonnes (titre, description, ordre, obligatoire, priorité…). |
| M4 | Élevée | **Clés étrangères « l'une ou l'autre »** sans contrainte `CHECK` : `missions_projet` a `mission_cohorte_id` **ou** `mission_etape_id` ; `livrables_attendus` a `mission_cohorte_id` **ou** `mission_etape_id`. Rien n'empêche les deux à la fois, ni aucune des deux. |
| M5 | Élevée | **Progression suivie de quatre façons** : `progressions` (+ `historique_progression`), `participations_cohorte`, `transitions_phase`, et en plus `projets.cohorte_id` qui duplique la participation en cours. |
| M6 | Élevée | **Livrables dupliqués** : `livrables` reprend presque toutes les colonnes de `livrable_versions` (copie de la dernière version). `url` est obligatoire même pour un livrable texte ou modèle. Le retour du coach tient en un seul champ (`commentaire_coach`) : pas de fil de commentaires. |
| M7 | Élevée | **Ressources polymorphes** : `ressources` a une colonne `portee` et quatre clés étrangères optionnelles (`cohorte_id`, `etape_id`, `parcours_id`, `phase_id`), plus une table `mission_cohorte_ressources`. |
| M8 | Élevée | **Deux façons de désigner une personne** : certaines tables pointent vers `users` (`cohortes_coachs`, `missions_projet.assigne_a_id`, `effectue_par_id`), d'autres vers `membres_structures` (`meetings.coach_id`, `meeting_participants.user_id`). Le même coach n'a pas le même identifiant selon le module. |
| M9 | Élevée | **Deux mécanismes d'invitation** : des colonnes de jeton dans `membres_structures` et une table `invitation_links`. `membres_structures.cohorte_id` mélange l'adhésion à la structure et l'affectation à une cohorte. |
| M10 | Moyenne | **Identifiants** : `conversations.id` (et ses références) en `varchar(36)`, toutes les autres tables en `binary(16)`. |
| M11 | Moyenne | **Horodatage** : `date_creation` dans la plupart des tables, `created_at` dans d'autres, aucun champ de création dans 15 tables ; `updated_at` presque absent ; `created_by` absent partout. |
| M12 | Moyenne | **Nommage mélangé** : français presque partout, mais `meetings` est en anglais (`title`, `scheduled_at`, `status`, enum `CANCELLED/PLANNED`). Trois conventions d'archivage (`archive`, `archivee`, statut `ARCHIVEE`). `effectue_par` à côté de `effectue_par_id`. Colonne `pointsacorriger`. |
| M13 | Moyenne | **Contraintes manquantes** : pas de clé étrangère sur `actions_ia_en_attente.message_id` ; pas d'index sur les statuts et dates souvent filtrés (seuls les index de clés étrangères existent, plus quelques-uns sur les conversations et `ia_usage`). |
| M14 | Moyenne | **Un projet = une seule personne** (`projets.entrepreneur_id`) : impossible d'avoir une équipe, alors que la cible veut des « personnes accompagnées » génériques. |
| M15 | Moyenne | **`structures`** : toutes les colonnes en `varchar(255)`, `type` en texte libre, pas de `updated_at`. |
| M16 | Faible | **Entité morte** : `TransitionPhase` (table `transitions_phase`) n'est jamais écrite. Note des livrables en `float`. |

---

## 4. Code et API (back-end)

| # | Gravité | Constat |
|---|---|---|
| C1 | Élevée | **Services géants** qui mélangent plusieurs responsabilités : `ProgressionService` (1 146 lignes), `MissionService` (912), `CohorteService` (803), `ParticipationService` (798), `LivrableService` (768). |
| C2 | Moyenne | **Logique dans les contrôleurs** : `MeetingController` accède directement au dépôt (9 références) et gère ses erreurs par `try/catch` ; idem `StructureController`, `StructureEquipeController`, `AiActionController`, `InvitationController`. |
| C3 | Moyenne | **Pas de format d'erreur unique** : 145 `ResponseStatusException`, 62 `IllegalArgumentException`, 34 `IllegalStateException`, 10 `RuntimeException`, plus plusieurs exceptions maison. Le gestionnaire global attrape `RuntimeException` et `Exception` en vrac. `TenantFilter` écrit un autre format JSON. |
| C4 | Moyenne | **Routes incohérentes** : `/api/mon-parcours`, `/api/suivi`, `/api/progression` (singulier), `/api/entrepreneur/ressources`, `/api/structures/equipe` ; la structure vient tantôt de l'en-tête, tantôt du chemin (`/api/structures/{id}/abonnement`) ; trois contrôleurs se partagent `/api/etapes`. |
| C5 | Moyenne | **Pas de pagination, de filtres ni de tris homogènes** : pagination dans 4 fichiers seulement, les listes renvoient tout. |
| C6 | Moyenne | **OpenAPI** : Swagger est en place, mais un seul fichier porte des annotations ; les droits et erreurs ne sont pas documentés. |
| C7 | Faible | 4 `TODO` / « A SUPPRIMER », code commenté, `AuthController` qui gère aussi l'acceptation d'invitations (13 routes). |

---

## 5. Front-end : ce qui « ne fait pas SaaS »

| # | Gravité | Constat |
|---|---|---|
| F1 | Élevée | **Design system contourné** : 560 valeurs Tailwind arbitraires (`w-[...]`, `text-[...]`), 334 couleurs de palette brute (`gray-500`, `blue-600`…) au lieu des tokens, 59 couleurs hexadécimales dans 7 fichiers. Les tokens existent mais ne sont pas la règle. |
| F2 | Élevée | **Effets « IA »** à retirer : 19 dégradés, 58 flous, effets verre et lueurs (`backdrop-blur`, `glass`, `glow`), tokens nommés `glass-*` et `ambient-*`. |
| F3 | Élevée | **Composants géants** : `parametres-modal` (2 604 lignes), `assistant-ia` (1 682), `mission-detail` entrepreneur (1 487), `cohortes-list` (1 409), `cohorte-detail` (1 317), `projet-detail` (1 159), `parcours-detail` (1 132), `etape-detail` (1 078). Difficiles à maintenir et à rendre accessibles. |
| F4 | Élevée | **Actions destructrices** : 28 `confirm()` natifs du navigateur, pas de composant de confirmation, aucun « Annuler » après suppression ou archivage. |
| F5 | Élevée | **Navigation qui reflète le modèle confus** : « Parcours » et « Programmes » sont deux entrées distinctes, avec des routes comme `programmes/:programmeId/parcours/:parcoursId` et `programmes/etapes/:id`. |
| F6 | Moyenne | **Accessibilité** : `aria-label` présent dans 36 fichiers seulement ; seuls 3 fichiers déclarent `role="dialog"` ou un piège à focus, alors que les modales sont nombreuses ; contraste AA non mesuré à ce stade. |
| F7 | Moyenne | **Clavier** : à part ⌘K, peu de raccourcis (17 gestionnaires `keydown`) ; aucun glisser-déposer (Angular CDK est installé mais inutilisé pour ça). |
| F8 | Moyenne | **Code mort** : 7 composants partagés jamais utilisés (`app-header`, `entity-card`, `etape-timeline`, `structure-switcher`, `tab-filter`, `view-switcher`, `voice-modal`), 3 modèles/services jamais importés (`auth-response.model`, `models/index`, `diagnostic.service`). |
| F9 | Moyenne | **Gestion d'état** : 253 `.subscribe()` manuels (risque de fuites et d'états incohérents), 2 rechargements complets de page. |
| F10 | Moyenne | **Premier usage** : des écrans `bienvenue` et `onboarding/projet` existent, mais pas de parcours guidé par rôle ni de liste « premiers pas ». |
| F11 | Faible | Deux familles de polices (Plus Jakarta Sans chargée depuis Google Fonts, Clash Display en local), budget du bundle initial dépassé de 22 Ko, import `Icon` inutilisé. |

---

## 6. Services Python

| # | Gravité | Constat |
|---|---|---|
| P1 | Moyenne | `jappo-ai` : un test en échec (les citations de sources reviennent vides), CORS `*`. Le service est sain par ailleurs ; on le garde. |
| P2 | Faible | `jappo-ai` : `.env` lu relativement au dossier de lancement (à documenter dans le déploiement). |
| P3 | — | `jappo-voice` : hors périmètre (remplacé plus tard). Ne pas l'exposer publiquement sur le VPS sans protection (voir S10). |

---

## 7. Ce qui manque par rapport à la phase 1

| # | Gravité | Manque |
|---|---|---|
| G1 | Élevée | **Créateur de programme** : pas de structure programme → étapes → activités → livrables attendus ; pas de duplication (aucune route) ; réorganisation limitée à l'ordre des phases d'un parcours (`PUT /api/parcours/{id}/phases/ordre`) ; pas de glisser-déposer ni d'équivalent clavier. |
| G2 | Élevée | **Parcours de l'entrepreneur** : un écran « mon parcours » existe, mais il s'appuie sur les quatre mécanismes de progression (M5). Pas de vue claire « où j'en suis / quoi faire maintenant ». |
| G3 | Élevée | **Retours du coach** : un seul champ texte par livrable, pas de fil de discussion ni de notification dédiée. |
| G4 | Élevée | **Modèles de documents** : seul le Business Model Canvas existe. Le business plan et le pitch deck n'existent pas côté back-end (le front-end a un type `business_plan` / `pitch_deck` dans `document-genere.model.ts`, sans implémentation derrière). |
| G5 | Élevée | **Socle API** : format d'erreur unique, pagination, filtres et tris, documentation OpenAPI complète (voir C3 à C6). |
| G6 | Moyenne | **SaaS** : confirmations et « Annuler », onboarding par rôle, raccourcis clavier, paramètres et notifications cohérents (voir F4, F7, F10). |
| G7 | Moyenne | **Déploiement VPS** : aucune configuration de production (profil `prod`, reverse proxy, HTTPS, sauvegardes MySQL, journaux). |
| G8 | — | Hors phase 1, à prévoir dans le modèle sans le construire : coachs indépendants (organisation d'une seule personne), catalogue public (programme « publiable »), bailleurs (lien organisation ↔ structures financées), équipe projet (M14). |

---

## 8. Conséquences pour la suite

- **Le modèle de données doit être réécrit** (M1 à M9) : c'est la cause principale des
  « choses bizarres » et des écrans confus. Comme il n'y a pas de données réelles, une nouvelle
  migration V1 est la voie la plus simple (étape 3).
- **Le socle de sécurité se garde mais se durcit** : rôles par structure, filtre d'adhésion et
  tests existants sont une bonne base. À ajouter : authentification du WebSocket (S1),
  isolation centralisée (S2), limitation de débit (S4), liste blanche des fichiers (S3), JWT plus
  court avec rafraîchissement (S5), validation systématique (S6).
- **Modules à garder sur le fond** : authentification, abonnements et quotas IA, PayDunya, réunions
  LiveKit, assistant IA. **À réécrire** : programmes, parcours, missions, progression, livrables,
  ressources.
- **Front-end** : repartir d'un design system strict (tokens seuls, sans effets) et de composants
  partagés, puis refaire les écrans module par module. Les briques ⌘K, état vide, squelettes et
  toasts sont à reprendre dans le nouveau design system.
