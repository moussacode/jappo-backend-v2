# jappo-backend

API REST et WebSocket de JAPPO (Spring Boot 4, Java 21, MySQL 8.4, Flyway).

Port : **8080**

## Prérequis

| Outil | Version | Vérification |
|---|---|---|
| Java (JDK) | 21 | `java -version` |
| MySQL | 8.4, installé sur la machine (service Windows `MySQL84`) | `mysql --version` |

Maven n'est pas nécessaire : le wrapper `mvnw` / `mvnw.cmd` est fourni.

## Base de données

Le serveur MySQL84 de la machine écoute sur le port **3307** (le 3306 est occupé par
un autre serveur, MySQL80). Création de la base et de l'utilisateur, une seule fois :

```powershell
& "C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe" -u root -p -h 127.0.0.1 -P 3307
```

```sql
CREATE DATABASE IF NOT EXISTS jappo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'jappo'@'localhost' IDENTIFIED BY '<mot de passe>';
CREATE USER IF NOT EXISTS 'jappo'@'127.0.0.1' IDENTIFIED BY '<mot de passe>';
GRANT ALL PRIVILEGES ON jappo.* TO 'jappo'@'localhost';
GRANT ALL PRIVILEGES ON jappo.* TO 'jappo'@'127.0.0.1';
FLUSH PRIVILEGES;
```

Le schéma est créé **uniquement par Flyway** au démarrage
(`src/main/resources/db/migration/V1__schema_initial.sql`, qui contient aussi les plans
d'abonnement FREEMIUM et PREMIUM). Hibernate est en `ddl-auto=validate` : il vérifie le
schéma mais ne le modifie jamais. Toute évolution du schéma passe par une nouvelle
migration `V2__...sql`, `V3__...sql`, etc.

Repartir d'une base vide : `DROP DATABASE jappo; CREATE DATABASE jappo CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;` puis relancer l'application.

## Variables d'environnement

Copier `.env.example` en `.env` (jamais versionné) et le remplir. Le fichier est chargé au
démarrage par `dotenv-java` depuis le dossier courant : lancer l'application depuis
`jappo-backend/`.

| Variable | Obligatoire | Rôle |
|---|---|---|
| `SPRING_PROFILES_ACTIVE` | non | `dev` lance le `DataSeeder` (comptes de démo). **Jamais `dev` en production.** |
| `DB_HOST`, `DB_PORT`, `DB_NAME` | non | défauts `localhost`, `3306`, `jappo` ; ici `DB_PORT=3307` |
| `DB_USERNAME`, `DB_PASSWORD` | oui | utilisateur MySQL `jappo` |
| `SUPER_ADMIN_PASSWORD` | **oui** | sans lui, l'application refuse de démarrer |
| `SUPER_ADMIN_EMAIL` | non | défaut `admin@jappo.sn` |
| `JWT_SECRET`, `JWT_EXPIRATION` | oui | secret Base64 (256 bits min.), durée en ms |
| `APP_FRONTEND_URL` | non | défaut `http://localhost:4200` (liens des emails, CORS, retours PayDunya) |
| `APP_BACKEND_PUBLIC_URL` | non | défaut `http://localhost:8080` (notification IPN PayDunya) |
| `MAIL_USERNAME`, `MAIL_PASSWORD` | oui | SMTP Gmail (mot de passe d'application) |
| `GOOGLE_CLIENT_ID` | oui | connexion Google |
| `AI_ORCHESTRATOR_URL`, `AI_API_KEY`, `AI_TIMEOUT` | oui | service `jappo-ai` ; `AI_API_KEY` identique des deux côtés |
| `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `LIVEKIT_HOST` | oui | visio (LiveKit Cloud) |
| `PAYDUNYA_MASTER_KEY`, `PAYDUNYA_PRIVATE_KEY`, `PAYDUNYA_TOKEN` | oui | paiement (sandbox) |
| `N8N_ENABLED`, `N8N_BASE_URL` | non | assistance via n8n, désactivée par défaut |
| `FLYWAY_ENABLED` | non | défaut `true` |

## Lancement

```powershell
cd jappo-backend
.\mvnw.cmd spring-boot:run
```

Démarrage réussi : `Successfully applied 1 migration` (premier lancement) puis
`Started JappoBackendApplication`. En profil `dev`, le seeder affiche les comptes de démo :

| Email | Rôle | Mot de passe |
|---|---|---|
| `awa@teranga.sn` | ADMIN_STRUCTURE | `Demo2024!` |
| `ibrahima@teranga.sn` | COACH | `Demo2024!` |
| `fatou@teranga.sn`, `cheikh@teranga.sn`, `ndeye@teranga.sn` | ENTREPRENEUR | `Demo2024!` |
| `SUPER_ADMIN_EMAIL` | SUPER_ADMIN | `SUPER_ADMIN_PASSWORD` |

Documentation de l'API (Swagger) : http://localhost:8080/swagger-ui.html

## Tests

```powershell
.\mvnw.cmd test
```

Les tests utilisent H2 en mémoire (`src/test/resources/application-test.properties`),
sans MySQL ni Flyway.

## Communication avec les autres services

```
jappo-frontend (4200) ──REST /api/**──────────► jappo-backend (8080) ──JDBC──► MySQL84 (3307)
                      ──WebSocket SockJS /ws──►        │
                                                       ├─ POST /api/v1/chat ──► jappo-ai (8000)
                                                       │    en-tête X-Internal-Api-Key = AI_API_KEY
                                                       ├─ API LiveKit Cloud (jetons de visio)
                                                       ├─ API PayDunya (sandbox)
                                                       └─ SMTP Gmail
jappo-frontend ──/api/voice/**──► jappo-voice (8001)   (ne passe pas par le back-end)
```

- **WebSocket** : endpoint `/ws` (SockJS + STOMP), abonnements sur `/topic/**`, envois sur `/app/**`.
- **Fichiers déposés** : stockés dans `uploads/` (non versionné).

## Ce qui ne tourne pas entièrement en local

| Élément | État en local |
|---|---|
| n8n (page Assistance) | désactivé (`N8N_ENABLED=false`) : la page affiche « service indisponible ». Pour le réactiver : `N8N_ENABLED=true`, `N8N_BASE_URL`, et réimporter le workflow archivé hors dépôt. |
| PayDunya | le paiement sandbox fonctionne, mais la notification IPN ne peut pas atteindre `localhost` : utiliser un tunnel (ngrok, Cloudflare Tunnel) et `APP_BACKEND_PUBLIC_URL` pour tester le paiement de bout en bout. |
| LiveKit | service cloud : fonctionne avec les clés renseignées. |
| Google Sign-In | ajouter `http://localhost:4200` aux origines JavaScript autorisées du client OAuth. |
