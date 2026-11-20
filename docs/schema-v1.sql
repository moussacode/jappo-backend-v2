-- =====================================================================
-- JAPPO v2 : schema initial (V1), genere a l'etape 3 de la refonte.
-- MySQL 8.4, InnoDB, utf8mb4. Voir docs/modele-donnees.md.
-- =====================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- Compte de connexion d'une personne (global, une personne = un compte).
CREATE TABLE user_account (
    id                 BINARY(16)   NOT NULL,
    email              VARCHAR(254) NOT NULL,
    password_hash      VARCHAR(100) NULL,
    google_subject     VARCHAR(255) NULL,
    first_name         VARCHAR(100) NOT NULL,
    last_name          VARCHAR(100) NOT NULL,
    email_verified_at  DATETIME(6)  NULL,
    platform_role      ENUM('USER','SUPER_ADMIN') NOT NULL DEFAULT 'USER',
    locale             VARCHAR(10)  NOT NULL DEFAULT 'fr',
    token_version      INT          NOT NULL DEFAULT 0,
    last_login_at      DATETIME(6)  NULL,
    disabled_at        DATETIME(6)  NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_user_account PRIMARY KEY (id),
    CONSTRAINT uk_user_account_email UNIQUE (email),
    CONSTRAINT uk_user_account_google_subject UNIQUE (google_subject),
    CONSTRAINT ck_user_account_email_lowercase CHECK (CAST(email AS BINARY) = CAST(LOWER(email) AS BINARY)),
    CONSTRAINT ck_user_account_credentials CHECK (password_hash IS NOT NULL OR google_subject IS NOT NULL),
    CONSTRAINT fk_user_account_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Jeton de renouvellement (cookie httpOnly), rotation et detection de reutilisation par famille.
CREATE TABLE refresh_token (
    id                 BINARY(16)   NOT NULL,
    user_id            BINARY(16)   NOT NULL,
    family_id          BINARY(16)   NOT NULL,
    token_hash         CHAR(64)     NOT NULL,
    expires_at         DATETIME(6)  NOT NULL,
    revoked_at         DATETIME(6)  NULL,
    replaced_by_id     BINARY(16)   NULL,
    user_agent         VARCHAR(255) NULL,
    ip_address         VARCHAR(45)  NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_refresh_token PRIMARY KEY (id),
    CONSTRAINT uk_refresh_token_token_hash UNIQUE (token_hash),
    CONSTRAINT fk_refresh_token_user FOREIGN KEY (user_id) REFERENCES user_account (id),
    CONSTRAINT fk_refresh_token_replaced_by FOREIGN KEY (replaced_by_id) REFERENCES refresh_token (id),
    INDEX ix_refresh_token_family (family_id),
    CONSTRAINT fk_refresh_token_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Jeton a usage unique : verification d'email, reinitialisation du mot de passe.
CREATE TABLE one_time_token (
    id                 BINARY(16)   NOT NULL,
    user_id            BINARY(16)   NOT NULL,
    purpose            ENUM('EMAIL_VERIFICATION','PASSWORD_RESET') NOT NULL,
    token_hash         CHAR(64)     NOT NULL,
    expires_at         DATETIME(6)  NOT NULL,
    consumed_at        DATETIME(6)  NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_one_time_token PRIMARY KEY (id),
    CONSTRAINT uk_one_time_token_token_hash UNIQUE (token_hash),
    CONSTRAINT fk_one_time_token_user FOREIGN KEY (user_id) REFERENCES user_account (id),
    INDEX ix_one_time_token_user_purpose (user_id, purpose),
    CONSTRAINT fk_one_time_token_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Preferences de notification d'une personne.
CREATE TABLE notification_preference (
    user_id            BINARY(16)   NOT NULL,
    notification_type  VARCHAR(60)  NOT NULL,
    email_enabled      BOOLEAN      NOT NULL DEFAULT TRUE,
    in_app_enabled     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_notification_preference PRIMARY KEY (user_id, notification_type),
    CONSTRAINT fk_notification_preference_user FOREIGN KEY (user_id) REFERENCES user_account (id),
    CONSTRAINT fk_notification_preference_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Structure (incubateur, accelerateur...) : la frontiere d'isolation des donnees.
CREATE TABLE organization (
    id                 BINARY(16)   NOT NULL,
    name               VARCHAR(150) NOT NULL,
    slug               VARCHAR(80)  NOT NULL,
    description        VARCHAR(1000) NULL,
    email              VARCHAR(254) NULL,
    phone              VARCHAR(30)  NULL,
    website            VARCHAR(255) NULL,
    country_code       CHAR(2)      NULL,
    city               VARCHAR(100) NULL,
    logo_file_id       BINARY(16)   NULL,
    timezone           VARCHAR(64)  NOT NULL DEFAULT 'Africa/Dakar',
    stalled_threshold_days SMALLINT NOT NULL DEFAULT 21,
    review_delay_days  SMALLINT     NOT NULL DEFAULT 5,
    suspended_at       DATETIME(6)  NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_organization PRIMARY KEY (id),
    CONSTRAINT uk_organization_slug UNIQUE (slug),
    CONSTRAINT ck_organization_stalled_threshold CHECK (stalled_threshold_days BETWEEN 3 AND 180),
    CONSTRAINT ck_organization_review_delay CHECK (review_delay_days BETWEEN 1 AND 30),
    CONSTRAINT fk_organization_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Fichier televerse ; content_type est le type detecte sur le contenu reel.
CREATE TABLE stored_file (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    storage_key        VARCHAR(255) NOT NULL,
    original_name      VARCHAR(255) NOT NULL,
    content_type       VARCHAR(127) NOT NULL,
    size_bytes         BIGINT       NOT NULL,
    sha256             CHAR(64)     NOT NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_stored_file PRIMARY KEY (id),
    CONSTRAINT uk_stored_file_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_stored_file_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT uk_stored_file_storage_key UNIQUE (storage_key),
    CONSTRAINT ck_stored_file_size CHECK (size_bytes > 0),
    CONSTRAINT fk_stored_file_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Une personne dans une structure, avec un role. Seule reference a une personne dans les modules.
CREATE TABLE member (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    user_id            BINARY(16)   NOT NULL,
    role               ENUM('ADMIN','FACILITATOR','PARTICIPANT') NOT NULL,
    joined_at          DATETIME(6)  NOT NULL,
    removed_at         DATETIME(6)  NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_member PRIMARY KEY (id),
    CONSTRAINT uk_member_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_member_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT uk_member_org_user UNIQUE (organization_id, user_id),
    CONSTRAINT fk_member_user FOREIGN KEY (user_id) REFERENCES user_account (id),
    CONSTRAINT fk_member_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Modele de document (BMC, business plan, pitch deck) : sections et champs, global a la plateforme.
CREATE TABLE document_template (
    id                 BINARY(16)   NOT NULL,
    code               VARCHAR(50)  NOT NULL,
    name               VARCHAR(100) NOT NULL,
    description        VARCHAR(1000) NULL,
    definition         JSON         NOT NULL,
    definition_version INT          NOT NULL DEFAULT 1,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_document_template PRIMARY KEY (id),
    CONSTRAINT uk_document_template_code UNIQUE (code),
    CONSTRAINT fk_document_template_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Programme : le modele d'accompagnement sur lequel on lance des cohortes.
CREATE TABLE program (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    title              VARCHAR(150) NOT NULL,
    description        TEXT         NULL,
    next_program_id    BINARY(16)   NULL,
    archived_at        DATETIME(6)  NULL,
    deleted_at         DATETIME(6)  NULL,
    version            INT          NOT NULL DEFAULT 0,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_program PRIMARY KEY (id),
    CONSTRAINT uk_program_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_program_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_program_next_program FOREIGN KEY (next_program_id, organization_id) REFERENCES program (id, organization_id),
    CONSTRAINT ck_program_next_not_self CHECK (next_program_id IS NULL OR next_program_id <> id),
    CONSTRAINT fk_program_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Coachs autorises a editer le contenu d'un programme.
CREATE TABLE program_editor (
    organization_id    BINARY(16)   NOT NULL,
    program_id         BINARY(16)   NOT NULL,
    member_id          BINARY(16)   NOT NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_program_editor PRIMARY KEY (program_id, member_id),
    CONSTRAINT fk_program_editor_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_program_editor_program FOREIGN KEY (program_id, organization_id) REFERENCES program (id, organization_id),
    CONSTRAINT fk_program_editor_member FOREIGN KEY (member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT fk_program_editor_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Etape d'un programme. deleted_at : suppression annulable, et trace pour les cohortes.
CREATE TABLE step (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    program_id         BINARY(16)   NOT NULL,
    title              VARCHAR(150) NOT NULL,
    description        TEXT         NULL,
    position           SMALLINT     NOT NULL,
    deleted_at         DATETIME(6)  NULL,
    live_position      SMALLINT     AS (IF(deleted_at IS NULL, position, NULL)) VIRTUAL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_step PRIMARY KEY (id),
    CONSTRAINT uk_step_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_step_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_step_program FOREIGN KEY (program_id, organization_id) REFERENCES program (id, organization_id),
    CONSTRAINT uk_step_program_position UNIQUE (program_id, live_position),
    CONSTRAINT ck_step_position CHECK (position >= 0),
    CONSTRAINT fk_step_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Ressource de la bibliotheque de la structure.
CREATE TABLE resource (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    title              VARCHAR(200) NOT NULL,
    description        TEXT         NULL,
    kind               ENUM('FILE','LINK') NOT NULL,
    file_id            BINARY(16)   NULL,
    url                VARCHAR(2048) NULL,
    archived_at        DATETIME(6)  NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_resource PRIMARY KEY (id),
    CONSTRAINT uk_resource_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_resource_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_resource_file FOREIGN KEY (file_id, organization_id) REFERENCES stored_file (id, organization_id),
    CONSTRAINT ck_resource_content CHECK ((kind = 'FILE' AND file_id IS NOT NULL AND url IS NULL) OR (kind = 'LINK' AND url IS NOT NULL AND file_id IS NULL)),
    CONSTRAINT fk_resource_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Activite d'une etape ; le livrable attendu (au plus un) est porte par deliverable_format.
CREATE TABLE activity (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    step_id            BINARY(16)   NOT NULL,
    title              VARCHAR(200) NOT NULL,
    description        MEDIUMTEXT   NULL,
    kind               ENUM('TASK','WORKSHOP','RESOURCE','SESSION') NOT NULL,
    required           BOOLEAN      NOT NULL DEFAULT TRUE,
    due_offset_days    SMALLINT     NULL,
    deliverable_format ENUM('FILE','LINK','TEXT','DOCUMENT') NULL,
    document_template_id BINARY(16) NULL,
    position           SMALLINT     NOT NULL,
    deleted_at         DATETIME(6)  NULL,
    live_position      SMALLINT     AS (IF(deleted_at IS NULL, position, NULL)) VIRTUAL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_activity PRIMARY KEY (id),
    CONSTRAINT uk_activity_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_activity_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_activity_step FOREIGN KEY (step_id, organization_id) REFERENCES step (id, organization_id),
    CONSTRAINT uk_activity_step_position UNIQUE (step_id, live_position),
    CONSTRAINT ck_activity_due_offset CHECK (due_offset_days IS NULL OR due_offset_days BETWEEN 0 AND 730),
    CONSTRAINT ck_activity_template_needs_document CHECK (document_template_id IS NULL OR COALESCE(deliverable_format, '') = 'DOCUMENT'),
    CONSTRAINT ck_activity_document_needs_template CHECK (COALESCE(deliverable_format, '') <> 'DOCUMENT' OR document_template_id IS NOT NULL),
    CONSTRAINT ck_activity_position CHECK (position >= 0),
    CONSTRAINT fk_activity_document_template FOREIGN KEY (document_template_id) REFERENCES document_template (id),
    CONSTRAINT fk_activity_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Ressources jointes a une activite du programme.
CREATE TABLE activity_resource (
    organization_id    BINARY(16)   NOT NULL,
    activity_id        BINARY(16)   NOT NULL,
    resource_id        BINARY(16)   NOT NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_activity_resource PRIMARY KEY (activity_id, resource_id),
    CONSTRAINT fk_activity_resource_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_activity_resource_activity FOREIGN KEY (activity_id, organization_id) REFERENCES activity (id, organization_id),
    CONSTRAINT fk_activity_resource_resource FOREIGN KEY (resource_id, organization_id) REFERENCES resource (id, organization_id),
    CONSTRAINT fk_activity_resource_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Cohorte. Statut calcule : a venir (avant start_date), en cours, terminee (closed_at).
CREATE TABLE cohort (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    program_id         BINARY(16)   NOT NULL,
    name               VARCHAR(150) NOT NULL,
    start_date         DATE         NOT NULL,
    planned_end_date   DATE         NOT NULL,
    closed_at          DATETIME(6)  NULL,
    closed_by_member_id BINARY(16)  NULL,
    version            INT          NOT NULL DEFAULT 0,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_cohort PRIMARY KEY (id),
    CONSTRAINT uk_cohort_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_cohort_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_cohort_program FOREIGN KEY (program_id, organization_id) REFERENCES program (id, organization_id),
    CONSTRAINT fk_cohort_closed_by FOREIGN KEY (closed_by_member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT uk_cohort_program_name UNIQUE (program_id, name),
    CONSTRAINT ck_cohort_dates CHECK (planned_end_date >= start_date),
    CONSTRAINT ck_cohort_closed_by CHECK ((closed_at IS NULL) = (closed_by_member_id IS NULL)),
    CONSTRAINT fk_cohort_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Coachs d'une cohorte.
CREATE TABLE cohort_facilitator (
    organization_id    BINARY(16)   NOT NULL,
    cohort_id          BINARY(16)   NOT NULL,
    member_id          BINARY(16)   NOT NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_cohort_facilitator PRIMARY KEY (cohort_id, member_id),
    CONSTRAINT fk_cohort_facilitator_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_cohort_facilitator_cohort FOREIGN KEY (cohort_id, organization_id) REFERENCES cohort (id, organization_id),
    CONSTRAINT fk_cohort_facilitator_member FOREIGN KEY (member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT fk_cohort_facilitator_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Copie d'une etape du programme pour une cohorte. detached_at : retiree du programme mais conservee.
CREATE TABLE cohort_step (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    cohort_id          BINARY(16)   NOT NULL,
    source_step_id     BINARY(16)   NOT NULL,
    title              VARCHAR(150) NOT NULL,
    description        TEXT         NULL,
    position           SMALLINT     NOT NULL,
    detached_at        DATETIME(6)  NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_cohort_step PRIMARY KEY (id),
    CONSTRAINT uk_cohort_step_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_cohort_step_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_cohort_step_cohort FOREIGN KEY (cohort_id, organization_id) REFERENCES cohort (id, organization_id),
    CONSTRAINT fk_cohort_step_source_step FOREIGN KEY (source_step_id, organization_id) REFERENCES step (id, organization_id),
    CONSTRAINT uk_cohort_step_cohort_id_pair UNIQUE (id, cohort_id),
    CONSTRAINT uk_cohort_step_cohort_position UNIQUE (cohort_id, position),
    CONSTRAINT uk_cohort_step_cohort_source UNIQUE (cohort_id, source_step_id),
    CONSTRAINT ck_cohort_step_position CHECK (position >= 0),
    CONSTRAINT fk_cohort_step_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Projet accompagne ; son statut se deduit de sa derniere participation.
CREATE TABLE project (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    name               VARCHAR(150) NOT NULL,
    description        TEXT         NULL,
    sector             VARCHAR(100) NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_project PRIMARY KEY (id),
    CONSTRAINT uk_project_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_project_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    INDEX ix_project_org_name (organization_id, name),
    CONSTRAINT fk_project_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Porteurs d'un projet (un ou plusieurs entrepreneurs).
CREATE TABLE project_holder (
    organization_id    BINARY(16)   NOT NULL,
    project_id         BINARY(16)   NOT NULL,
    member_id          BINARY(16)   NOT NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_project_holder PRIMARY KEY (project_id, member_id),
    CONSTRAINT fk_project_holder_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_project_holder_project FOREIGN KEY (project_id, organization_id) REFERENCES project (id, organization_id),
    CONSTRAINT fk_project_holder_member FOREIGN KEY (member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT fk_project_holder_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Participation d'un projet a une cohorte. En cours tant que ended_at est nul ; une seule en cours par projet.
CREATE TABLE enrollment (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    project_id         BINARY(16)   NOT NULL,
    cohort_id          BINARY(16)   NOT NULL,
    started_at         DATETIME(6)  NOT NULL,
    ended_at           DATETIME(6)  NULL,
    outcome            ENUM('COMPLETED','ON_HOLD','DROPPED') NULL,
    outcome_reason     TEXT         NULL,
    ended_by_member_id BINARY(16)   NULL,
    promoted_to_enrollment_id BINARY(16) NULL,
    active_project_id  BINARY(16)   AS (IF(ended_at IS NULL, project_id, NULL)) VIRTUAL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_enrollment PRIMARY KEY (id),
    CONSTRAINT uk_enrollment_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_enrollment_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_enrollment_project FOREIGN KEY (project_id, organization_id) REFERENCES project (id, organization_id),
    CONSTRAINT fk_enrollment_cohort FOREIGN KEY (cohort_id, organization_id) REFERENCES cohort (id, organization_id),
    CONSTRAINT fk_enrollment_ended_by FOREIGN KEY (ended_by_member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT fk_enrollment_promoted_to FOREIGN KEY (promoted_to_enrollment_id, organization_id) REFERENCES enrollment (id, organization_id),
    CONSTRAINT uk_enrollment_cohort_id_pair UNIQUE (id, cohort_id),
    CONSTRAINT uk_enrollment_one_active_per_project UNIQUE (active_project_id),
    CONSTRAINT uk_enrollment_promoted_to UNIQUE (promoted_to_enrollment_id),
    INDEX ix_enrollment_cohort_ended (cohort_id, ended_at),
    INDEX ix_enrollment_project_started (project_id, started_at),
    CONSTRAINT ck_enrollment_end CHECK ((ended_at IS NULL) = (outcome IS NULL) AND (ended_at IS NULL) = (ended_by_member_id IS NULL)),
    CONSTRAINT ck_enrollment_promotion CHECK (promoted_to_enrollment_id IS NULL OR outcome = 'COMPLETED'),
    CONSTRAINT fk_enrollment_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Activite du contenu d'une cohorte : copiee du programme, propre a la cohorte, ou ponctuelle pour une participation.
CREATE TABLE cohort_activity (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    cohort_id          BINARY(16)   NOT NULL,
    cohort_step_id     BINARY(16)   NOT NULL,
    origin             ENUM('PROGRAM','COHORT','ENROLLMENT') NOT NULL,
    source_activity_id BINARY(16)   NULL,
    enrollment_id      BINARY(16)   NULL,
    title              VARCHAR(200) NOT NULL,
    description        MEDIUMTEXT   NULL,
    kind               ENUM('TASK','WORKSHOP','RESOURCE','SESSION') NOT NULL,
    required           BOOLEAN      NOT NULL DEFAULT TRUE,
    due_offset_days    SMALLINT     NULL,
    due_date_override  DATE         NULL,
    deliverable_format ENUM('FILE','LINK','TEXT','DOCUMENT') NULL,
    document_template_id BINARY(16) NULL,
    position           SMALLINT     NOT NULL,
    detached_at        DATETIME(6)  NULL,
    deleted_at         DATETIME(6)  NULL,
    live_position      SMALLINT     AS (IF(deleted_at IS NULL, position, NULL)) VIRTUAL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_cohort_activity PRIMARY KEY (id),
    CONSTRAINT uk_cohort_activity_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_cohort_activity_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_cohort_activity_cohort FOREIGN KEY (cohort_id, organization_id) REFERENCES cohort (id, organization_id),
    CONSTRAINT fk_cohort_activity_cohort_step FOREIGN KEY (cohort_step_id, cohort_id) REFERENCES cohort_step (id, cohort_id),
    CONSTRAINT fk_cohort_activity_source_activity FOREIGN KEY (source_activity_id, organization_id) REFERENCES activity (id, organization_id),
    CONSTRAINT fk_cohort_activity_enrollment FOREIGN KEY (enrollment_id, cohort_id) REFERENCES enrollment (id, cohort_id),
    CONSTRAINT uk_cohort_activity_cohort_id_pair UNIQUE (id, cohort_id),
    CONSTRAINT uk_cohort_activity_step_position UNIQUE (cohort_step_id, live_position),
    CONSTRAINT uk_cohort_activity_cohort_source UNIQUE (cohort_id, source_activity_id),
    INDEX ix_cohort_activity_enrollment (enrollment_id),
    CONSTRAINT ck_cohort_activity_origin_program CHECK ((origin = 'PROGRAM') = (source_activity_id IS NOT NULL)),
    CONSTRAINT ck_cohort_activity_origin_enrollment CHECK ((origin = 'ENROLLMENT') = (enrollment_id IS NOT NULL)),
    CONSTRAINT ck_cohort_activity_detached_only_program CHECK (detached_at IS NULL OR origin = 'PROGRAM'),
    CONSTRAINT ck_cohort_activity_due_offset CHECK (due_offset_days IS NULL OR due_offset_days BETWEEN 0 AND 730),
    CONSTRAINT ck_cohort_activity_template_needs_document CHECK (document_template_id IS NULL OR COALESCE(deliverable_format, '') = 'DOCUMENT'),
    CONSTRAINT ck_cohort_activity_document_needs_template CHECK (COALESCE(deliverable_format, '') <> 'DOCUMENT' OR document_template_id IS NOT NULL),
    CONSTRAINT ck_cohort_activity_position CHECK (position >= 0),
    CONSTRAINT fk_cohort_activity_document_template FOREIGN KEY (document_template_id) REFERENCES document_template (id),
    CONSTRAINT fk_cohort_activity_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Ressources jointes a une activite de cohorte.
CREATE TABLE cohort_activity_resource (
    organization_id    BINARY(16)   NOT NULL,
    cohort_activity_id BINARY(16)   NOT NULL,
    resource_id        BINARY(16)   NOT NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_cohort_activity_resource PRIMARY KEY (cohort_activity_id, resource_id),
    CONSTRAINT fk_cohort_activity_resource_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_cohort_activity_resource_cohort_activity FOREIGN KEY (cohort_activity_id, organization_id) REFERENCES cohort_activity (id, organization_id),
    CONSTRAINT fk_cohort_activity_resource_resource FOREIGN KEY (resource_id, organization_id) REFERENCES resource (id, organization_id),
    CONSTRAINT fk_cohort_activity_resource_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Activite sans livrable marquee faite pour une participation.
CREATE TABLE activity_completion (
    organization_id    BINARY(16)   NOT NULL,
    cohort_id          BINARY(16)   NOT NULL,
    enrollment_id      BINARY(16)   NOT NULL,
    cohort_activity_id BINARY(16)   NOT NULL,
    completed_by_member_id BINARY(16) NOT NULL,
    completed_at       DATETIME(6)  NOT NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_activity_completion PRIMARY KEY (enrollment_id, cohort_activity_id),
    CONSTRAINT fk_activity_completion_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_activity_completion_enrollment FOREIGN KEY (enrollment_id, cohort_id) REFERENCES enrollment (id, cohort_id),
    CONSTRAINT fk_activity_completion_cohort_activity FOREIGN KEY (cohort_activity_id, cohort_id) REFERENCES cohort_activity (id, cohort_id),
    CONSTRAINT fk_activity_completion_cohort FOREIGN KEY (cohort_id, organization_id) REFERENCES cohort (id, organization_id),
    CONSTRAINT fk_activity_completion_completed_by FOREIGN KEY (completed_by_member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT fk_activity_completion_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Livrable d'une participation pour une activite. Seul le statut courant est stocke ici.
CREATE TABLE deliverable (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    cohort_id          BINARY(16)   NOT NULL,
    enrollment_id      BINARY(16)   NOT NULL,
    cohort_activity_id BINARY(16)   NOT NULL,
    status             ENUM('TO_SUBMIT','SUBMITTED','CHANGES_REQUESTED','APPROVED') NOT NULL DEFAULT 'TO_SUBMIT',
    version            INT          NOT NULL DEFAULT 0,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_deliverable PRIMARY KEY (id),
    CONSTRAINT uk_deliverable_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_deliverable_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_deliverable_enrollment FOREIGN KEY (enrollment_id, cohort_id) REFERENCES enrollment (id, cohort_id),
    CONSTRAINT fk_deliverable_cohort_activity FOREIGN KEY (cohort_activity_id, cohort_id) REFERENCES cohort_activity (id, cohort_id),
    CONSTRAINT fk_deliverable_cohort FOREIGN KEY (cohort_id, organization_id) REFERENCES cohort (id, organization_id),
    CONSTRAINT uk_deliverable_enrollment_activity UNIQUE (enrollment_id, cohort_activity_id),
    INDEX ix_deliverable_cohort_status (cohort_id, status),
    CONSTRAINT fk_deliverable_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Version d'un livrable. number nul = brouillon (un seul) ; une version rendue n'est plus modifiee.
CREATE TABLE deliverable_version (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    deliverable_id     BINARY(16)   NOT NULL,
    number             SMALLINT     NULL,
    submitted_at       DATETIME(6)  NULL,
    submitted_by_member_id BINARY(16) NULL,
    content_type       ENUM('FILE','LINK','TEXT','DOCUMENT') NOT NULL,
    text_body          MEDIUMTEXT   NULL,
    link_url           VARCHAR(2048) NULL,
    file_id            BINARY(16)   NULL,
    document_template_id BINARY(16) NULL,
    document_definition_version INT NULL,
    document_data      JSON         NULL,
    draft_of_deliverable_id BINARY(16) AS (IF(number IS NULL, deliverable_id, NULL)) VIRTUAL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_deliverable_version PRIMARY KEY (id),
    CONSTRAINT uk_deliverable_version_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_deliverable_version_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_deliverable_version_deliverable FOREIGN KEY (deliverable_id, organization_id) REFERENCES deliverable (id, organization_id),
    CONSTRAINT fk_deliverable_version_submitted_by FOREIGN KEY (submitted_by_member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT fk_deliverable_version_file FOREIGN KEY (file_id, organization_id) REFERENCES stored_file (id, organization_id),
    CONSTRAINT fk_deliverable_version_document_template FOREIGN KEY (document_template_id) REFERENCES document_template (id),
    CONSTRAINT uk_deliverable_version_id_deliverable_pair UNIQUE (id, deliverable_id),
    CONSTRAINT uk_deliverable_version_number UNIQUE (deliverable_id, number),
    CONSTRAINT uk_deliverable_version_one_draft UNIQUE (draft_of_deliverable_id),
    INDEX ix_deliverable_version_submitted (deliverable_id, submitted_at),
    CONSTRAINT ck_deliverable_version_submission CHECK ((number IS NULL) = (submitted_at IS NULL) AND (submitted_at IS NULL) = (submitted_by_member_id IS NULL)),
    CONSTRAINT ck_deliverable_version_number CHECK (number IS NULL OR number >= 1),
    CONSTRAINT ck_deliverable_version_draft_kinds CHECK (submitted_at IS NOT NULL OR content_type IN ('TEXT','DOCUMENT')),
    CONSTRAINT ck_deliverable_version_file CHECK (content_type <> 'FILE' OR file_id IS NOT NULL),
    CONSTRAINT ck_deliverable_version_link CHECK (content_type <> 'LINK' OR link_url IS NOT NULL),
    CONSTRAINT ck_deliverable_version_text CHECK (content_type <> 'TEXT' OR text_body IS NOT NULL),
    CONSTRAINT ck_deliverable_version_document CHECK (content_type <> 'DOCUMENT' OR (document_template_id IS NOT NULL AND document_data IS NOT NULL AND document_definition_version IS NOT NULL)),
    CONSTRAINT fk_deliverable_version_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Fil de commentaires d'un livrable ; les actions de relecture y laissent leur trace.
CREATE TABLE deliverable_comment (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    deliverable_id     BINARY(16)   NOT NULL,
    author_member_id   BINARY(16)   NOT NULL,
    kind               ENUM('COMMENT','CHANGES_REQUESTED','APPROVED','REOPENED') NOT NULL DEFAULT 'COMMENT',
    body               TEXT         NULL,
    version_id         BINARY(16)   NULL,
    correction_due_date DATE        NULL,
    edited_at          DATETIME(6)  NULL,
    deleted_at         DATETIME(6)  NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_deliverable_comment PRIMARY KEY (id),
    CONSTRAINT uk_deliverable_comment_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_deliverable_comment_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_deliverable_comment_deliverable FOREIGN KEY (deliverable_id, organization_id) REFERENCES deliverable (id, organization_id),
    CONSTRAINT fk_deliverable_comment_author FOREIGN KEY (author_member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT fk_deliverable_comment_version FOREIGN KEY (version_id, deliverable_id) REFERENCES deliverable_version (id, deliverable_id),
    INDEX ix_deliverable_comment_deliverable_created (deliverable_id, created_at),
    CONSTRAINT ck_deliverable_comment_body CHECK (kind = 'APPROVED' OR body IS NOT NULL OR deleted_at IS NOT NULL),
    CONSTRAINT ck_deliverable_comment_correction_due CHECK (correction_due_date IS NULL OR kind = 'CHANGES_REQUESTED'),
    CONSTRAINT fk_deliverable_comment_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Seul mecanisme d'entree dans une structure. Expiree = en attente et expires_at depasse.
CREATE TABLE invitation (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    email              VARCHAR(254) NOT NULL,
    role               ENUM('ADMIN','FACILITATOR','PARTICIPANT') NOT NULL,
    cohort_id          BINARY(16)   NULL,
    project_id         BINARY(16)   NULL,
    proposed_project_name VARCHAR(150) NULL,
    token_hash         CHAR(64)     NOT NULL,
    expires_at         DATETIME(6)  NOT NULL,
    invited_by_member_id BINARY(16) NOT NULL,
    accepted_at        DATETIME(6)  NULL,
    accepted_member_id BINARY(16)   NULL,
    revoked_at         DATETIME(6)  NULL,
    pending_email      VARCHAR(254) AS (IF(accepted_at IS NULL AND revoked_at IS NULL, email, NULL)) VIRTUAL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_invitation PRIMARY KEY (id),
    CONSTRAINT uk_invitation_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_invitation_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT uk_invitation_token_hash UNIQUE (token_hash),
    CONSTRAINT uk_invitation_one_pending UNIQUE (organization_id, pending_email),
    CONSTRAINT fk_invitation_cohort FOREIGN KEY (cohort_id, organization_id) REFERENCES cohort (id, organization_id),
    CONSTRAINT fk_invitation_project FOREIGN KEY (project_id, organization_id) REFERENCES project (id, organization_id),
    CONSTRAINT fk_invitation_invited_by FOREIGN KEY (invited_by_member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT fk_invitation_accepted_member FOREIGN KEY (accepted_member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT ck_invitation_email_lowercase CHECK (CAST(email AS BINARY) = CAST(LOWER(email) AS BINARY)),
    CONSTRAINT ck_invitation_participant_only CHECK (role = 'PARTICIPANT' OR (cohort_id IS NULL AND project_id IS NULL AND proposed_project_name IS NULL)),
    CONSTRAINT ck_invitation_acceptance CHECK ((accepted_at IS NULL) = (accepted_member_id IS NULL)),
    CONSTRAINT ck_invitation_final_state CHECK (accepted_at IS NULL OR revoked_at IS NULL),
    CONSTRAINT fk_invitation_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Seance (LiveKit ou presentiel). Statut calcule : prevue, en cours, terminee (horaires), annulee (cancelled_at).
CREATE TABLE meeting (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    title              VARCHAR(200) NOT NULL,
    description        TEXT         NULL,
    starts_at          DATETIME(6)  NOT NULL,
    duration_minutes   SMALLINT     NOT NULL,
    mode               ENUM('ONLINE','IN_PERSON') NOT NULL,
    location           VARCHAR(255) NULL,
    room_name          VARCHAR(100) NULL,
    host_member_id     BINARY(16)   NOT NULL,
    cohort_id          BINARY(16)   NULL,
    enrollment_id      BINARY(16)   NULL,
    cohort_activity_id BINARY(16)   NULL,
    summary            TEXT         NULL,
    cancelled_at       DATETIME(6)  NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_meeting PRIMARY KEY (id),
    CONSTRAINT uk_meeting_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_meeting_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_meeting_host FOREIGN KEY (host_member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT fk_meeting_cohort FOREIGN KEY (cohort_id, organization_id) REFERENCES cohort (id, organization_id),
    CONSTRAINT fk_meeting_enrollment FOREIGN KEY (enrollment_id, organization_id) REFERENCES enrollment (id, organization_id),
    CONSTRAINT fk_meeting_cohort_activity FOREIGN KEY (cohort_activity_id, organization_id) REFERENCES cohort_activity (id, organization_id),
    CONSTRAINT uk_meeting_room_name UNIQUE (room_name),
    INDEX ix_meeting_org_starts (organization_id, starts_at),
    CONSTRAINT ck_meeting_duration CHECK (duration_minutes BETWEEN 5 AND 480),
    CONSTRAINT ck_meeting_online_room CHECK ((mode = 'ONLINE') = (room_name IS NOT NULL)),
    CONSTRAINT ck_meeting_in_person_location CHECK (mode <> 'IN_PERSON' OR location IS NOT NULL),
    CONSTRAINT fk_meeting_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Participants d'une seance.
CREATE TABLE meeting_participant (
    organization_id    BINARY(16)   NOT NULL,
    meeting_id         BINARY(16)   NOT NULL,
    member_id          BINARY(16)   NOT NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_meeting_participant PRIMARY KEY (meeting_id, member_id),
    CONSTRAINT fk_meeting_participant_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_meeting_participant_meeting FOREIGN KEY (meeting_id, organization_id) REFERENCES meeting (id, organization_id),
    CONSTRAINT fk_meeting_participant_member FOREIGN KEY (member_id, organization_id) REFERENCES member (id, organization_id),
    INDEX ix_meeting_participant_member (member_id),
    CONSTRAINT fk_meeting_participant_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Conversation avec l'assistant IA, rattachee au contexte ouvert (programme, cohorte, projet).
CREATE TABLE ai_conversation (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    member_id          BINARY(16)   NOT NULL,
    title              VARCHAR(200) NULL,
    program_id         BINARY(16)   NULL,
    cohort_id          BINARY(16)   NULL,
    project_id         BINARY(16)   NULL,
    archived_at        DATETIME(6)  NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_ai_conversation PRIMARY KEY (id),
    CONSTRAINT uk_ai_conversation_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_ai_conversation_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_ai_conversation_member FOREIGN KEY (member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT fk_ai_conversation_program FOREIGN KEY (program_id, organization_id) REFERENCES program (id, organization_id),
    CONSTRAINT fk_ai_conversation_cohort FOREIGN KEY (cohort_id, organization_id) REFERENCES cohort (id, organization_id),
    CONSTRAINT fk_ai_conversation_project FOREIGN KEY (project_id, organization_id) REFERENCES project (id, organization_id),
    CONSTRAINT fk_ai_conversation_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Message d'une conversation IA. sources : citations renvoyees par le service IA.
CREATE TABLE ai_message (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    conversation_id    BINARY(16)   NOT NULL,
    role               ENUM('USER','ASSISTANT') NOT NULL,
    content            MEDIUMTEXT   NOT NULL,
    model              VARCHAR(150) NULL,
    sources            JSON         NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_ai_message PRIMARY KEY (id),
    CONSTRAINT uk_ai_message_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_ai_message_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_ai_message_conversation FOREIGN KEY (conversation_id, organization_id) REFERENCES ai_conversation (id, organization_id),
    INDEX ix_ai_message_conversation_created (conversation_id, created_at),
    CONSTRAINT fk_ai_message_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Action proposee par l'IA, executee seulement apres confirmation. Expiree = PENDING et expires_at depasse.
CREATE TABLE ai_pending_action (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    message_id         BINARY(16)   NOT NULL,
    action_type        VARCHAR(50)  NOT NULL,
    payload            JSON         NOT NULL,
    status             ENUM('PENDING','CONFIRMED','REJECTED','FAILED') NOT NULL DEFAULT 'PENDING',
    expires_at         DATETIME(6)  NOT NULL,
    resolved_at        DATETIME(6)  NULL,
    resolved_by_member_id BINARY(16) NULL,
    error_message      TEXT         NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_ai_pending_action PRIMARY KEY (id),
    CONSTRAINT uk_ai_pending_action_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_ai_pending_action_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_ai_pending_action_message FOREIGN KEY (message_id, organization_id) REFERENCES ai_message (id, organization_id),
    CONSTRAINT fk_ai_pending_action_resolved_by FOREIGN KEY (resolved_by_member_id, organization_id) REFERENCES member (id, organization_id),
    CONSTRAINT ck_ai_pending_action_resolution CHECK ((status = 'PENDING') = (resolved_at IS NULL)),
    CONSTRAINT fk_ai_pending_action_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Journal de consommation IA (quotas). Independant des conversations : archiver une conversation ne remet pas le compteur a zero.
CREATE TABLE ai_usage (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    member_id          BINARY(16)   NOT NULL,
    model              VARCHAR(150) NULL,
    input_tokens       INT          NOT NULL,
    output_tokens      INT          NOT NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_ai_usage PRIMARY KEY (id),
    CONSTRAINT uk_ai_usage_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_ai_usage_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_ai_usage_member FOREIGN KEY (member_id, organization_id) REFERENCES member (id, organization_id),
    INDEX ix_ai_usage_org_created (organization_id, created_at),
    CONSTRAINT ck_ai_usage_tokens CHECK (input_tokens >= 0 AND output_tokens >= 0),
    CONSTRAINT fk_ai_usage_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Plan d'abonnement (global). Un seul plan par defaut.
CREATE TABLE plan (
    id                 BINARY(16)   NOT NULL,
    code               VARCHAR(50)  NOT NULL,
    name               VARCHAR(100) NOT NULL,
    description        VARCHAR(1000) NULL,
    price_amount       BIGINT       NOT NULL DEFAULT 0,
    currency           CHAR(3)      NOT NULL DEFAULT 'XOF',
    duration_days      SMALLINT     NULL,
    max_open_cohorts   SMALLINT     NULL,
    ai_for_facilitators BOOLEAN     NOT NULL DEFAULT FALSE,
    ai_for_participants BOOLEAN     NOT NULL DEFAULT FALSE,
    ai_monthly_tokens  BIGINT       NULL,
    is_default         BOOLEAN      NOT NULL DEFAULT FALSE,
    position           SMALLINT     NOT NULL DEFAULT 0,
    archived_at        DATETIME(6)  NULL,
    default_flag       TINYINT      AS (IF(is_default, 1, NULL)) VIRTUAL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_plan PRIMARY KEY (id),
    CONSTRAINT uk_plan_code UNIQUE (code),
    CONSTRAINT uk_plan_one_default UNIQUE (default_flag),
    CONSTRAINT ck_plan_price CHECK (price_amount >= 0),
    CONSTRAINT fk_plan_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Periode d'abonnement d'une structure ; l'historique est l'ensemble des lignes, une seule courante.
CREATE TABLE subscription (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    plan_id            BINARY(16)   NOT NULL,
    status             ENUM('PENDING_PAYMENT','ACTIVE','EXPIRED','CANCELLED') NOT NULL,
    source             ENUM('DEFAULT','PAYMENT','ADMINISTRATION') NOT NULL,
    starts_at          DATETIME(6)  NULL,
    ends_at            DATETIME(6)  NULL,
    auto_renew         BOOLEAN      NOT NULL DEFAULT FALSE,
    current_org_id     BINARY(16)   AS (IF(status IN ('PENDING_PAYMENT','ACTIVE'), organization_id, NULL)) VIRTUAL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_subscription PRIMARY KEY (id),
    CONSTRAINT uk_subscription_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_subscription_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_subscription_plan FOREIGN KEY (plan_id) REFERENCES plan (id),
    CONSTRAINT uk_subscription_one_current UNIQUE (current_org_id),
    CONSTRAINT ck_subscription_period CHECK (ends_at IS NULL OR starts_at IS NULL OR ends_at > starts_at),
    CONSTRAINT fk_subscription_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Paiement d'un abonnement (PayDunya).
CREATE TABLE payment (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    plan_id            BINARY(16)   NOT NULL,
    subscription_id    BINARY(16)   NULL,
    provider           ENUM('PAYDUNYA') NOT NULL,
    provider_reference VARCHAR(100) NOT NULL,
    provider_token     VARCHAR(255) NULL,
    amount             BIGINT       NOT NULL,
    currency           CHAR(3)      NOT NULL,
    status             ENUM('PENDING','SUCCEEDED','FAILED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    confirmed_at       DATETIME(6)  NULL,
    payment_method     VARCHAR(50)  NULL,
    payer_phone        VARCHAR(30)  NULL,
    ipn_payload        JSON         NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_payment PRIMARY KEY (id),
    CONSTRAINT uk_payment_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_payment_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_payment_plan FOREIGN KEY (plan_id) REFERENCES plan (id),
    CONSTRAINT fk_payment_subscription FOREIGN KEY (subscription_id, organization_id) REFERENCES subscription (id, organization_id),
    CONSTRAINT uk_payment_provider_reference UNIQUE (provider, provider_reference),
    CONSTRAINT ck_payment_amount CHECK (amount >= 0),
    CONSTRAINT fk_payment_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

-- Notification dans l'application.
CREATE TABLE notification (
    id                 BINARY(16)   NOT NULL,
    organization_id    BINARY(16)   NOT NULL,
    recipient_member_id BINARY(16)  NOT NULL,
    notification_type  VARCHAR(60)  NOT NULL,
    payload            JSON         NOT NULL,
    read_at            DATETIME(6)  NULL,
    created_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at         DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    created_by         BINARY(16)   NULL,
    CONSTRAINT pk_notification PRIMARY KEY (id),
    CONSTRAINT uk_notification_id_org UNIQUE (id, organization_id),
    CONSTRAINT fk_notification_organization FOREIGN KEY (organization_id) REFERENCES organization (id),
    CONSTRAINT fk_notification_recipient FOREIGN KEY (recipient_member_id, organization_id) REFERENCES member (id, organization_id),
    INDEX ix_notification_recipient_read (recipient_member_id, read_at, created_at),
    CONSTRAINT fk_notification_created_by FOREIGN KEY (created_by) REFERENCES user_account (id)
) ENGINE = InnoDB;

ALTER TABLE organization ADD CONSTRAINT fk_organization_logo_file
    FOREIGN KEY (logo_file_id, id) REFERENCES stored_file (id, organization_id);

SET FOREIGN_KEY_CHECKS = 1;
