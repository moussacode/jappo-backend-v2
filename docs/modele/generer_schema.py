"""Generateur du schema JAPPO v2 (etape 3). Produit un fichier SQL MySQL 8.4.

Conventions appliquees automatiquement :
- id BINARY(16) (UUID v7 genere par l'application) ;
- organization_id + UNIQUE (id, organization_id) sur chaque table d'une organisation ;
- cles etrangeres composites (x_id, organization_id) vers les tables d'une organisation ;
- created_at, updated_at, created_by partout ;
- aucune action ON DELETE / ON UPDATE (RESTRICT) : rien ne se supprime en cascade.
"""
import sys

T = []  # (name, sql)


def table(name, cols, cons=(), tenant=True, pk="id", comment=""):
    lines = []
    if pk == "id":
        lines.append("    id                 BINARY(16)   NOT NULL")
    if tenant:
        lines.append("    organization_id    BINARY(16)   NOT NULL")
    lines += ["    " + c for c in cols]
    lines += [
        "    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6)",
        "    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)",
        "    created_by         BINARY(16)   NULL",
    ]
    c2 = []
    c2.append("    CONSTRAINT pk_%s PRIMARY KEY (%s)" % (name, pk))
    if tenant and pk == "id":
        c2.append("    CONSTRAINT uk_%s_id_org UNIQUE (id, organization_id)" % name)
    if tenant:
        c2.append("    CONSTRAINT fk_%s_organization FOREIGN KEY (organization_id) REFERENCES organization (id)" % name)
    c2 += ["    " + c for c in cons]
    c2.append("    CONSTRAINT fk_%s_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)" % name)
    body = ",\n".join(lines + c2)
    head = "-- %s\n" % comment if comment else ""
    T.append((name, "%sCREATE TABLE %s (\n%s\n) ENGINE = InnoDB;" % (head, name, body)))


def fk(t, col, parent, name=None):
    """Cle etrangere composite liee a l'organisation."""
    return "CONSTRAINT fk_%s_%s FOREIGN KEY (%s, organization_id) REFERENCES %s (id, organization_id)" % (
        t, name or col.replace("_id", ""), col, parent)


def fk1(t, col, parent, name=None):
    """Cle etrangere simple (table globale)."""
    return "CONSTRAINT fk_%s_%s FOREIGN KEY (%s) REFERENCES %s (id)" % (t, name or col.replace("_id", ""), col, parent)


def ck(t, name, expr):
    return "CONSTRAINT ck_%s_%s CHECK (%s)" % (t, name, expr)


def uk(t, name, cols):
    return "CONSTRAINT uk_%s_%s UNIQUE (%s)" % (t, name, cols)


def ix(t, name, cols):
    return "INDEX ix_%s_%s (%s)" % (t, name, cols)


# ---------------------------------------------------------------- comptes (global)
t = "user_account"
table(t, [
    "email              VARCHAR(254) NOT NULL",
    "password_hash      VARCHAR(100) NULL",
    "google_subject     VARCHAR(255) NULL",
    "first_name         VARCHAR(100) NOT NULL",
    "last_name          VARCHAR(100) NOT NULL",
    "email_verified_at  DATETIME(6)  NULL",
    "platform_role      ENUM('USER','SUPER_ADMIN') NOT NULL DEFAULT 'USER'",
    "locale             VARCHAR(10)  NOT NULL DEFAULT 'fr'",
    "token_version      INT          NOT NULL DEFAULT 0",
    "last_login_at      DATETIME(6)  NULL",
    "disabled_at        DATETIME(6)  NULL",
], [
    uk(t, "email", "email"),
    uk(t, "google_subject", "google_subject"),
    ck(t, "email_lowercase", "CAST(email AS BINARY) = CAST(LOWER(email) AS BINARY)"),
    ck(t, "credentials", "password_hash IS NOT NULL OR google_subject IS NOT NULL"),
], tenant=False, comment="Compte de connexion d'une personne (global, une personne = un compte).")

t = "refresh_token"
table(t, [
    "user_id            BINARY(16)   NOT NULL",
    "family_id          BINARY(16)   NOT NULL",
    "token_hash         CHAR(64)     NOT NULL",
    "expires_at         DATETIME(6)  NOT NULL",
    "revoked_at         DATETIME(6)  NULL",
    "replaced_by_id     BINARY(16)   NULL",
    "user_agent         VARCHAR(255) NULL",
    "ip_address         VARCHAR(45)  NULL",
], [
    uk(t, "token_hash", "token_hash"),
    fk1(t, "user_id", "user_account", "user"),
    fk1(t, "replaced_by_id", "refresh_token", "replaced_by"),
    ix(t, "family", "family_id"),
], tenant=False, comment="Jeton de renouvellement (cookie httpOnly), rotation et detection de reutilisation par famille.")

t = "one_time_token"
table(t, [
    "user_id            BINARY(16)   NOT NULL",
    "purpose            ENUM('EMAIL_VERIFICATION','PASSWORD_RESET') NOT NULL",
    "token_hash         CHAR(64)     NOT NULL",
    "expires_at         DATETIME(6)  NOT NULL",
    "consumed_at        DATETIME(6)  NULL",
], [
    uk(t, "token_hash", "token_hash"),
    fk1(t, "user_id", "user_account", "user"),
    ix(t, "user_purpose", "user_id, purpose"),
], tenant=False, comment="Jeton a usage unique : verification d'email, reinitialisation du mot de passe.")

t = "notification_preference"
table(t, [
    "user_id            BINARY(16)   NOT NULL",
    "notification_type  VARCHAR(60)  NOT NULL",
    "email_enabled      BOOLEAN      NOT NULL DEFAULT TRUE",
    "in_app_enabled     BOOLEAN      NOT NULL DEFAULT TRUE",
], [
    fk1(t, "user_id", "user_account", "user"),
], tenant=False, pk="user_id, notification_type", comment="Preferences de notification d'une personne.")

# ---------------------------------------------------------------- organisation
t = "organization"
table(t, [
    "name               VARCHAR(150) NOT NULL",
    "slug               VARCHAR(80)  NOT NULL",
    "description        VARCHAR(1000) NULL",
    "email              VARCHAR(254) NULL",
    "phone              VARCHAR(30)  NULL",
    "website            VARCHAR(255) NULL",
    "country_code       CHAR(2)      NULL",
    "city               VARCHAR(100) NULL",
    "logo_file_id       BINARY(16)   NULL",
    "timezone           VARCHAR(64)  NOT NULL DEFAULT 'Africa/Dakar'",
    "stalled_threshold_days SMALLINT NOT NULL DEFAULT 21",
    "review_delay_days  SMALLINT     NOT NULL DEFAULT 5",
    "suspended_at       DATETIME(6)  NULL",
], [
    uk(t, "slug", "slug"),
    ck(t, "stalled_threshold", "stalled_threshold_days BETWEEN 3 AND 180"),
    ck(t, "review_delay", "review_delay_days BETWEEN 1 AND 30"),
], tenant=False, comment="Structure (incubateur, accelerateur...) : la frontiere d'isolation des donnees.")

t = "stored_file"
table(t, [
    "storage_key        VARCHAR(255) NOT NULL",
    "original_name      VARCHAR(255) NOT NULL",
    "content_type       VARCHAR(127) NOT NULL",
    "size_bytes         BIGINT       NOT NULL",
    "sha256             CHAR(64)     NOT NULL",
], [
    uk(t, "storage_key", "storage_key"),
    ck(t, "size", "size_bytes > 0"),
], comment="Fichier televerse ; content_type est le type detecte sur le contenu reel.")

t = "member"
table(t, [
    "user_id            BINARY(16)   NOT NULL",
    "role               ENUM('ADMIN','FACILITATOR','PARTICIPANT') NOT NULL",
    "joined_at          DATETIME(6)  NOT NULL",
    "removed_at         DATETIME(6)  NULL",
], [
    uk(t, "org_user", "organization_id, user_id"),
    fk1(t, "user_id", "user_account", "user"),
], comment="Une personne dans une structure, avec un role. Seule reference a une personne dans les modules.")

# ---------------------------------------------------------------- programmes (modele)
t = "document_template"
table(t, [
    "code               VARCHAR(50)  NOT NULL",
    "name               VARCHAR(100) NOT NULL",
    "description        VARCHAR(1000) NULL",
    "definition         JSON         NOT NULL",
    "definition_version INT          NOT NULL DEFAULT 1",
], [
    uk(t, "code", "code"),
], tenant=False, comment="Modele de document (BMC, business plan, pitch deck) : sections et champs, global a la plateforme.")

t = "program"
table(t, [
    "title              VARCHAR(150) NOT NULL",
    "description        TEXT         NULL",
    "next_program_id    BINARY(16)   NULL",
    "archived_at        DATETIME(6)  NULL",
    "version            INT          NOT NULL DEFAULT 0",
], [
    fk(t, "next_program_id", "program", "next_program"),
    ck(t, "next_not_self", "next_program_id IS NULL OR next_program_id <> id"),
], comment="Programme : le modele d'accompagnement sur lequel on lance des cohortes.")

t = "program_editor"
table(t, [
    "program_id         BINARY(16)   NOT NULL",
    "member_id          BINARY(16)   NOT NULL",
], [
    fk(t, "program_id", "program"),
    fk(t, "member_id", "member"),
], pk="program_id, member_id", comment="Coachs autorises a editer le contenu d'un programme.")

t = "step"
table(t, [
    "program_id         BINARY(16)   NOT NULL",
    "title              VARCHAR(150) NOT NULL",
    "description        TEXT         NULL",
    "position           SMALLINT     NOT NULL",
    "deleted_at         DATETIME(6)  NULL",
    "live_position      SMALLINT     AS (IF(deleted_at IS NULL, position, NULL)) VIRTUAL",
], [
    fk(t, "program_id", "program"),
    uk(t, "program_position", "program_id, live_position"),
    ck(t, "position", "position >= 0"),
], comment="Etape d'un programme. deleted_at : suppression annulable, et trace pour les cohortes.")

t = "resource"
table(t, [
    "title              VARCHAR(200) NOT NULL",
    "description        TEXT         NULL",
    "kind               ENUM('FILE','LINK') NOT NULL",
    "file_id            BINARY(16)   NULL",
    "url                VARCHAR(2048) NULL",
    "archived_at        DATETIME(6)  NULL",
], [
    fk(t, "file_id", "stored_file", "file"),
    ck(t, "content", "(kind = 'FILE' AND file_id IS NOT NULL AND url IS NULL) OR (kind = 'LINK' AND url IS NOT NULL AND file_id IS NULL)"),
], comment="Ressource de la bibliotheque de la structure.")

ACTIVITY_COLS = [
    "title              VARCHAR(200) NOT NULL",
    "description        MEDIUMTEXT   NULL",
    "kind               ENUM('TASK','WORKSHOP','RESOURCE','SESSION') NOT NULL",
    "required           BOOLEAN      NOT NULL DEFAULT TRUE",
    "due_offset_days    SMALLINT     NULL",
    "deliverable_format ENUM('FILE','LINK','TEXT','DOCUMENT') NULL",
    "document_template_id BINARY(16) NULL",
    "position           SMALLINT     NOT NULL",
    "deleted_at         DATETIME(6)  NULL",
    "live_position      SMALLINT     AS (IF(deleted_at IS NULL, position, NULL)) VIRTUAL",
]


def activity_checks(t):
    return [
        ck(t, "due_offset", "due_offset_days IS NULL OR due_offset_days BETWEEN 0 AND 730"),
        ck(t, "template_needs_document", "document_template_id IS NULL OR COALESCE(deliverable_format, '') = 'DOCUMENT'"),
        ck(t, "document_needs_template", "COALESCE(deliverable_format, '') <> 'DOCUMENT' OR document_template_id IS NOT NULL"),
        ck(t, "position", "position >= 0"),
        fk1(t, "document_template_id", "document_template", "document_template"),
    ]


t = "activity"
table(t, ["step_id            BINARY(16)   NOT NULL"] + ACTIVITY_COLS, [
    fk(t, "step_id", "step"),
    uk(t, "step_position", "step_id, live_position"),
] + activity_checks(t), comment="Activite d'une etape ; le livrable attendu (au plus un) est porte par deliverable_format.")

t = "activity_resource"
table(t, [
    "activity_id        BINARY(16)   NOT NULL",
    "resource_id        BINARY(16)   NOT NULL",
], [
    fk(t, "activity_id", "activity"),
    fk(t, "resource_id", "resource"),
], pk="activity_id, resource_id", comment="Ressources jointes a une activite du programme.")

# ---------------------------------------------------------------- cohortes (copie)
t = "cohort"
table(t, [
    "program_id         BINARY(16)   NOT NULL",
    "name               VARCHAR(150) NOT NULL",
    "start_date         DATE         NOT NULL",
    "planned_end_date   DATE         NOT NULL",
    "closed_at          DATETIME(6)  NULL",
    "closed_by_member_id BINARY(16)  NULL",
    "version            INT          NOT NULL DEFAULT 0",
], [
    fk(t, "program_id", "program"),
    fk(t, "closed_by_member_id", "member", "closed_by"),
    uk(t, "program_name", "program_id, name"),
    ck(t, "dates", "planned_end_date >= start_date"),
    ck(t, "closed_by", "(closed_at IS NULL) = (closed_by_member_id IS NULL)"),
], comment="Cohorte. Statut calcule : a venir (avant start_date), en cours, terminee (closed_at).")

t = "cohort_facilitator"
table(t, [
    "cohort_id          BINARY(16)   NOT NULL",
    "member_id          BINARY(16)   NOT NULL",
], [
    fk(t, "cohort_id", "cohort"),
    fk(t, "member_id", "member"),
], pk="cohort_id, member_id", comment="Coachs d'une cohorte.")

t = "cohort_step"
table(t, [
    "cohort_id          BINARY(16)   NOT NULL",
    "source_step_id     BINARY(16)   NOT NULL",
    "title              VARCHAR(150) NOT NULL",
    "description        TEXT         NULL",
    "position           SMALLINT     NOT NULL",
    "detached_at        DATETIME(6)  NULL",
], [
    fk(t, "cohort_id", "cohort"),
    fk(t, "source_step_id", "step", "source_step"),
    uk(t, "cohort_id_pair", "id, cohort_id"),
    uk(t, "cohort_position", "cohort_id, position"),
    uk(t, "cohort_source", "cohort_id, source_step_id"),
    ck(t, "position", "position >= 0"),
], comment="Copie d'une etape du programme pour une cohorte. detached_at : retiree du programme mais conservee.")

t = "project"
table(t, [
    "name               VARCHAR(150) NOT NULL",
    "description        TEXT         NULL",
    "sector             VARCHAR(100) NULL",
], [
    ix(t, "org_name", "organization_id, name"),
], comment="Projet accompagne ; son statut se deduit de sa derniere participation.")

t = "project_holder"
table(t, [
    "project_id         BINARY(16)   NOT NULL",
    "member_id          BINARY(16)   NOT NULL",
], [
    fk(t, "project_id", "project"),
    fk(t, "member_id", "member"),
], pk="project_id, member_id", comment="Porteurs d'un projet (un ou plusieurs entrepreneurs).")

t = "enrollment"
table(t, [
    "project_id         BINARY(16)   NOT NULL",
    "cohort_id          BINARY(16)   NOT NULL",
    "started_at         DATETIME(6)  NOT NULL",
    "ended_at           DATETIME(6)  NULL",
    "outcome            ENUM('COMPLETED','ON_HOLD','DROPPED') NULL",
    "outcome_reason     TEXT         NULL",
    "ended_by_member_id BINARY(16)   NULL",
    "promoted_to_enrollment_id BINARY(16) NULL",
    "active_project_id  BINARY(16)   AS (IF(ended_at IS NULL, project_id, NULL)) VIRTUAL",
], [
    fk(t, "project_id", "project"),
    fk(t, "cohort_id", "cohort"),
    fk(t, "ended_by_member_id", "member", "ended_by"),
    fk(t, "promoted_to_enrollment_id", "enrollment", "promoted_to"),
    uk(t, "cohort_id_pair", "id, cohort_id"),
    uk(t, "one_active_per_project", "active_project_id"),
    uk(t, "promoted_to", "promoted_to_enrollment_id"),
    ix(t, "cohort_ended", "cohort_id, ended_at"),
    ck(t, "end", "(ended_at IS NULL) = (outcome IS NULL) AND (ended_at IS NULL) = (ended_by_member_id IS NULL)"),
    ck(t, "promotion", "promoted_to_enrollment_id IS NULL OR outcome = 'COMPLETED'"),
], comment="Participation d'un projet a une cohorte. En cours tant que ended_at est nul ; une seule en cours par projet.")

t = "cohort_activity"
table(t, [
    "cohort_id          BINARY(16)   NOT NULL",
    "cohort_step_id     BINARY(16)   NOT NULL",
    "origin             ENUM('PROGRAM','COHORT','ENROLLMENT') NOT NULL",
    "source_activity_id BINARY(16)   NULL",
    "enrollment_id      BINARY(16)   NULL",
] + ACTIVITY_COLS[:4] + [
    "due_offset_days    SMALLINT     NULL",
    "due_date_override  DATE         NULL",
] + ACTIVITY_COLS[5:8] + [
    "detached_at        DATETIME(6)  NULL",
    "deleted_at         DATETIME(6)  NULL",
    "live_position      SMALLINT     AS (IF(deleted_at IS NULL, position, NULL)) VIRTUAL",
], [
    fk(t, "cohort_id", "cohort"),
    "CONSTRAINT fk_%s_cohort_step FOREIGN KEY (cohort_step_id, cohort_id) REFERENCES cohort_step (id, cohort_id)" % t,
    fk(t, "source_activity_id", "activity", "source_activity"),
    "CONSTRAINT fk_%s_enrollment FOREIGN KEY (enrollment_id, cohort_id) REFERENCES enrollment (id, cohort_id)" % t,
    uk(t, "cohort_id_pair", "id, cohort_id"),
    uk(t, "step_position", "cohort_step_id, live_position"),
    uk(t, "cohort_source", "cohort_id, source_activity_id"),
    ix(t, "enrollment", "enrollment_id"),
    ck(t, "origin_program", "(origin = 'PROGRAM') = (source_activity_id IS NOT NULL)"),
    ck(t, "origin_enrollment", "(origin = 'ENROLLMENT') = (enrollment_id IS NOT NULL)"),
    ck(t, "detached_only_program", "detached_at IS NULL OR origin = 'PROGRAM'"),
] + activity_checks(t), comment="Activite du contenu d'une cohorte : copiee du programme, propre a la cohorte, ou ponctuelle pour une participation.")

t = "cohort_activity_resource"
table(t, [
    "cohort_activity_id BINARY(16)   NOT NULL",
    "resource_id        BINARY(16)   NOT NULL",
], [
    fk(t, "cohort_activity_id", "cohort_activity"),
    fk(t, "resource_id", "resource"),
], pk="cohort_activity_id, resource_id", comment="Ressources jointes a une activite de cohorte.")

t = "activity_completion"
table(t, [
    "cohort_id          BINARY(16)   NOT NULL",
    "enrollment_id      BINARY(16)   NOT NULL",
    "cohort_activity_id BINARY(16)   NOT NULL",
    "completed_by_member_id BINARY(16) NOT NULL",
    "completed_at       DATETIME(6)  NOT NULL",
], [
    "CONSTRAINT fk_%s_enrollment FOREIGN KEY (enrollment_id, cohort_id) REFERENCES enrollment (id, cohort_id)" % t,
    "CONSTRAINT fk_%s_cohort_activity FOREIGN KEY (cohort_activity_id, cohort_id) REFERENCES cohort_activity (id, cohort_id)" % t,
    fk(t, "cohort_id", "cohort"),
    fk(t, "completed_by_member_id", "member", "completed_by"),
], pk="enrollment_id, cohort_activity_id", comment="Activite sans livrable marquee faite pour une participation.")

# ---------------------------------------------------------------- livrables
t = "deliverable"
table(t, [
    "cohort_id          BINARY(16)   NOT NULL",
    "enrollment_id      BINARY(16)   NOT NULL",
    "cohort_activity_id BINARY(16)   NOT NULL",
    "status             ENUM('TO_SUBMIT','SUBMITTED','CHANGES_REQUESTED','APPROVED') NOT NULL DEFAULT 'TO_SUBMIT'",
    "version            INT          NOT NULL DEFAULT 0",
], [
    "CONSTRAINT fk_%s_enrollment FOREIGN KEY (enrollment_id, cohort_id) REFERENCES enrollment (id, cohort_id)" % t,
    "CONSTRAINT fk_%s_cohort_activity FOREIGN KEY (cohort_activity_id, cohort_id) REFERENCES cohort_activity (id, cohort_id)" % t,
    fk(t, "cohort_id", "cohort"),
    uk(t, "enrollment_activity", "enrollment_id, cohort_activity_id"),
    ix(t, "cohort_status", "cohort_id, status"),
], comment="Livrable d'une participation pour une activite. Seul le statut courant est stocke ici.")

t = "deliverable_version"
table(t, [
    "deliverable_id     BINARY(16)   NOT NULL",
    "number             SMALLINT     NULL",
    "submitted_at       DATETIME(6)  NULL",
    "submitted_by_member_id BINARY(16) NULL",
    "content_type       ENUM('FILE','LINK','TEXT','DOCUMENT') NOT NULL",
    "text_body          MEDIUMTEXT   NULL",
    "link_url           VARCHAR(2048) NULL",
    "file_id            BINARY(16)   NULL",
    "document_template_id BINARY(16) NULL",
    "document_definition_version INT NULL",
    "document_data      JSON         NULL",
    "draft_of_deliverable_id BINARY(16) AS (IF(number IS NULL, deliverable_id, NULL)) VIRTUAL",
], [
    fk(t, "deliverable_id", "deliverable"),
    fk(t, "submitted_by_member_id", "member", "submitted_by"),
    fk(t, "file_id", "stored_file", "file"),
    fk1(t, "document_template_id", "document_template", "document_template"),
    uk(t, "id_deliverable_pair", "id, deliverable_id"),
    uk(t, "number", "deliverable_id, number"),
    uk(t, "one_draft", "draft_of_deliverable_id"),
    ix(t, "submitted", "deliverable_id, submitted_at"),
    ck(t, "submission", "(number IS NULL) = (submitted_at IS NULL) AND (submitted_at IS NULL) = (submitted_by_member_id IS NULL)"),
    ck(t, "number", "number IS NULL OR number >= 1"),
    ck(t, "draft_kinds", "submitted_at IS NOT NULL OR content_type IN ('TEXT','DOCUMENT')"),
    ck(t, "file", "content_type <> 'FILE' OR file_id IS NOT NULL"),
    ck(t, "link", "content_type <> 'LINK' OR link_url IS NOT NULL"),
    ck(t, "text", "content_type <> 'TEXT' OR text_body IS NOT NULL"),
    ck(t, "document", "content_type <> 'DOCUMENT' OR (document_template_id IS NOT NULL AND document_data IS NOT NULL AND document_definition_version IS NOT NULL)"),
], comment="Version d'un livrable. number nul = brouillon (un seul) ; une version rendue n'est plus modifiee.")

t = "deliverable_comment"
table(t, [
    "deliverable_id     BINARY(16)   NOT NULL",
    "author_member_id   BINARY(16)   NOT NULL",
    "kind               ENUM('COMMENT','CHANGES_REQUESTED','APPROVED','REOPENED') NOT NULL DEFAULT 'COMMENT'",
    "body               TEXT         NULL",
    "version_id         BINARY(16)   NULL",
    "correction_due_date DATE        NULL",
    "edited_at          DATETIME(6)  NULL",
    "deleted_at         DATETIME(6)  NULL",
], [
    fk(t, "deliverable_id", "deliverable"),
    fk(t, "author_member_id", "member", "author"),
    "CONSTRAINT fk_%s_version FOREIGN KEY (version_id, deliverable_id) REFERENCES deliverable_version (id, deliverable_id)" % t,
    ix(t, "deliverable_created", "deliverable_id, created_at"),
    ck(t, "body", "kind = 'APPROVED' OR body IS NOT NULL OR deleted_at IS NOT NULL"),
    ck(t, "correction_due", "correction_due_date IS NULL OR kind = 'CHANGES_REQUESTED'"),
], comment="Fil de commentaires d'un livrable ; les actions de relecture y laissent leur trace.")

# ---------------------------------------------------------------- invitations
t = "invitation"
table(t, [
    "email              VARCHAR(254) NOT NULL",
    "role               ENUM('ADMIN','FACILITATOR','PARTICIPANT') NOT NULL",
    "cohort_id          BINARY(16)   NULL",
    "project_id         BINARY(16)   NULL",
    "proposed_project_name VARCHAR(150) NULL",
    "token_hash         CHAR(64)     NOT NULL",
    "expires_at         DATETIME(6)  NOT NULL",
    "invited_by_member_id BINARY(16) NOT NULL",
    "accepted_at        DATETIME(6)  NULL",
    "accepted_member_id BINARY(16)   NULL",
    "revoked_at         DATETIME(6)  NULL",
    "pending_email      VARCHAR(254) AS (IF(accepted_at IS NULL AND revoked_at IS NULL, email, NULL)) VIRTUAL",
], [
    uk(t, "token_hash", "token_hash"),
    uk(t, "one_pending", "organization_id, pending_email"),
    fk(t, "cohort_id", "cohort"),
    fk(t, "project_id", "project"),
    fk(t, "invited_by_member_id", "member", "invited_by"),
    fk(t, "accepted_member_id", "member", "accepted_member"),
    ck(t, "email_lowercase", "CAST(email AS BINARY) = CAST(LOWER(email) AS BINARY)"),
    ck(t, "participant_only", "role = 'PARTICIPANT' OR (cohort_id IS NULL AND project_id IS NULL AND proposed_project_name IS NULL)"),
    ck(t, "acceptance", "(accepted_at IS NULL) = (accepted_member_id IS NULL)"),
    ck(t, "final_state", "accepted_at IS NULL OR revoked_at IS NULL"),
], comment="Seul mecanisme d'entree dans une structure. Expiree = en attente et expires_at depasse.")

# ---------------------------------------------------------------- seances
t = "meeting"
table(t, [
    "title              VARCHAR(200) NOT NULL",
    "description        TEXT         NULL",
    "starts_at          DATETIME(6)  NOT NULL",
    "duration_minutes   SMALLINT     NOT NULL",
    "mode               ENUM('ONLINE','IN_PERSON') NOT NULL",
    "location           VARCHAR(255) NULL",
    "room_name          VARCHAR(100) NULL",
    "host_member_id     BINARY(16)   NOT NULL",
    "cohort_id          BINARY(16)   NULL",
    "enrollment_id      BINARY(16)   NULL",
    "cohort_activity_id BINARY(16)   NULL",
    "summary            TEXT         NULL",
    "cancelled_at       DATETIME(6)  NULL",
], [
    fk(t, "host_member_id", "member", "host"),
    fk(t, "cohort_id", "cohort"),
    fk(t, "enrollment_id", "enrollment"),
    fk(t, "cohort_activity_id", "cohort_activity"),
    uk(t, "room_name", "room_name"),
    ix(t, "org_starts", "organization_id, starts_at"),
    ck(t, "duration", "duration_minutes BETWEEN 5 AND 480"),
    ck(t, "online_room", "(mode = 'ONLINE') = (room_name IS NOT NULL)"),
    ck(t, "in_person_location", "mode <> 'IN_PERSON' OR location IS NOT NULL"),
], comment="Seance (LiveKit ou presentiel). Statut calcule : prevue, en cours, terminee (horaires), annulee (cancelled_at).")

t = "meeting_participant"
table(t, [
    "meeting_id         BINARY(16)   NOT NULL",
    "member_id          BINARY(16)   NOT NULL",
], [
    fk(t, "meeting_id", "meeting"),
    fk(t, "member_id", "member"),
    ix(t, "member", "member_id"),
], pk="meeting_id, member_id", comment="Participants d'une seance.")

# ---------------------------------------------------------------- assistant IA
t = "ai_conversation"
table(t, [
    "member_id          BINARY(16)   NOT NULL",
    "title              VARCHAR(200) NULL",
    "program_id         BINARY(16)   NULL",
    "cohort_id          BINARY(16)   NULL",
    "project_id         BINARY(16)   NULL",
    "archived_at        DATETIME(6)  NULL",
], [
    fk(t, "member_id", "member"),
    fk(t, "program_id", "program"),
    fk(t, "cohort_id", "cohort"),
    fk(t, "project_id", "project"),
], comment="Conversation avec l'assistant IA, rattachee au contexte ouvert (programme, cohorte, projet).")

t = "ai_message"
table(t, [
    "conversation_id    BINARY(16)   NOT NULL",
    "role               ENUM('USER','ASSISTANT') NOT NULL",
    "content            MEDIUMTEXT   NOT NULL",
    "model              VARCHAR(150) NULL",
    "sources            JSON         NULL",
], [
    fk(t, "conversation_id", "ai_conversation", "conversation"),
    ix(t, "conversation_created", "conversation_id, created_at"),
], comment="Message d'une conversation IA. sources : citations renvoyees par le service IA.")

t = "ai_pending_action"
table(t, [
    "message_id         BINARY(16)   NOT NULL",
    "action_type        VARCHAR(50)  NOT NULL",
    "payload            JSON         NOT NULL",
    "status             ENUM('PENDING','CONFIRMED','REJECTED','FAILED') NOT NULL DEFAULT 'PENDING'",
    "expires_at         DATETIME(6)  NOT NULL",
    "resolved_at        DATETIME(6)  NULL",
    "resolved_by_member_id BINARY(16) NULL",
    "error_message      TEXT         NULL",
], [
    fk(t, "message_id", "ai_message", "message"),
    fk(t, "resolved_by_member_id", "member", "resolved_by"),
    ck(t, "resolution", "(status = 'PENDING') = (resolved_at IS NULL)"),
], comment="Action proposee par l'IA, executee seulement apres confirmation. Expiree = PENDING et expires_at depasse.")

t = "ai_usage"
table(t, [
    "member_id          BINARY(16)   NOT NULL",
    "model              VARCHAR(150) NULL",
    "input_tokens       INT          NOT NULL",
    "output_tokens      INT          NOT NULL",
], [
    fk(t, "member_id", "member"),
    ix(t, "org_created", "organization_id, created_at"),
    ck(t, "tokens", "input_tokens >= 0 AND output_tokens >= 0"),
], comment="Journal de consommation IA (quotas). Independant des conversations : archiver une conversation ne remet pas le compteur a zero.")

# ---------------------------------------------------------------- abonnement
t = "plan"
table(t, [
    "code               VARCHAR(50)  NOT NULL",
    "name               VARCHAR(100) NOT NULL",
    "description        VARCHAR(1000) NULL",
    "price_amount       BIGINT       NOT NULL DEFAULT 0",
    "currency           CHAR(3)      NOT NULL DEFAULT 'XOF'",
    "duration_days      SMALLINT     NULL",
    "max_open_cohorts   SMALLINT     NULL",
    "ai_for_facilitators BOOLEAN     NOT NULL DEFAULT FALSE",
    "ai_for_participants BOOLEAN     NOT NULL DEFAULT FALSE",
    "ai_monthly_tokens  BIGINT       NULL",
    "is_default         BOOLEAN      NOT NULL DEFAULT FALSE",
    "position           SMALLINT     NOT NULL DEFAULT 0",
    "archived_at        DATETIME(6)  NULL",
    "default_flag       TINYINT      AS (IF(is_default, 1, NULL)) VIRTUAL",
], [
    uk(t, "code", "code"),
    uk(t, "one_default", "default_flag"),
    ck(t, "price", "price_amount >= 0"),
], tenant=False, comment="Plan d'abonnement (global). Un seul plan par defaut.")

t = "subscription"
table(t, [
    "plan_id            BINARY(16)   NOT NULL",
    "status             ENUM('PENDING_PAYMENT','ACTIVE','EXPIRED','CANCELLED') NOT NULL",
    "source             ENUM('DEFAULT','PAYMENT','ADMINISTRATION') NOT NULL",
    "starts_at          DATETIME(6)  NULL",
    "ends_at            DATETIME(6)  NULL",
    "auto_renew         BOOLEAN      NOT NULL DEFAULT FALSE",
    "current_org_id     BINARY(16)   AS (IF(status IN ('PENDING_PAYMENT','ACTIVE'), organization_id, NULL)) VIRTUAL",
], [
    fk1(t, "plan_id", "plan", "plan"),
    uk(t, "one_current", "current_org_id"),
    ck(t, "period", "ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at"),
], comment="Periode d'abonnement d'une structure ; l'historique est l'ensemble des lignes, une seule courante.")

t = "payment"
table(t, [
    "plan_id            BINARY(16)   NOT NULL",
    "subscription_id    BINARY(16)   NULL",
    "provider           ENUM('PAYDUNYA') NOT NULL",
    "provider_reference VARCHAR(100) NOT NULL",
    "provider_token     VARCHAR(255) NULL",
    "amount             BIGINT       NOT NULL",
    "currency           CHAR(3)      NOT NULL",
    "status             ENUM('PENDING','SUCCEEDED','FAILED','CANCELLED') NOT NULL DEFAULT 'PENDING'",
    "confirmed_at       DATETIME(6)  NULL",
    "payment_method     VARCHAR(50)  NULL",
    "payer_phone        VARCHAR(30)  NULL",
    "ipn_payload        JSON         NULL",
], [
    fk1(t, "plan_id", "plan", "plan"),
    fk(t, "subscription_id", "subscription"),
    uk(t, "provider_reference", "provider, provider_reference"),
    ck(t, "amount", "amount >= 0"),
], comment="Paiement d'un abonnement (PayDunya).")

# ---------------------------------------------------------------- notifications
t = "notification"
table(t, [
    "recipient_member_id BINARY(16)  NOT NULL",
    "notification_type  VARCHAR(60)  NOT NULL",
    "payload            JSON         NOT NULL",
    "read_at            DATETIME(6)  NULL",
], [
    fk(t, "recipient_member_id", "member", "recipient"),
    ix(t, "recipient_read", "recipient_member_id, read_at, created_at"),
], comment="Notification dans l'application.")

# ---------------------------------------------------------------- sortie
order = [n for n, _ in T]
out = ["-- =====================================================================",
       "-- JAPPO v2 : schema initial (V1), genere a l'etape 3 de la refonte.",
       "-- MySQL 8.4, InnoDB, utf8mb4. Voir docs/modele-donnees.md.",
       "-- =====================================================================",
       "",
       "SET FOREIGN_KEY_CHECKS = 0;",
       ""]
for n, sql in T:
    out.append(sql)
    out.append("")
out.append("ALTER TABLE organization ADD CONSTRAINT fk_organization_logo_file\n"
           "    FOREIGN KEY (logo_file_id, id) REFERENCES stored_file (id, organization_id);")
out.append("")
out.append("SET FOREIGN_KEY_CHECKS = 1;")
out.append("")
open(sys.argv[1], "w", encoding="utf-8", newline="\n").write("\n".join(out))
print(len(T), "tables :", ", ".join(order))
