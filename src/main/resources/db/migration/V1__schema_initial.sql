-- =====================================================================
-- JAPPO : schema initial (remplace les anciennes migrations V1 a V15,
-- archivees dans _archives/anciennes-migrations/).
--
-- Reproduit le schema effectivement en service avant la remise a plat :
--   1. tables, colonnes, cles et contraintes generees par Hibernate
--      a partir des entites JPA ;
--   2. objets ajoutes par les migrations reellement appliquees (V12 a V15) :
--      contraintes d'unicite de missions_projet, index des conversations,
--      cles etrangeres et index de ia_usage ;
--   3. donnees de reference : plans d'abonnement FREEMIUM et PREMIUM.
--
-- Hibernate est en ddl-auto=validate : toute evolution du schema passe
-- desormais par une nouvelle migration V2, V3...
-- =====================================================================

SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE `abonnements` (
  `renouvellement_auto` bit(1) NOT NULL,
  `date_creation` datetime(6) NOT NULL,
  `date_debut` datetime(6) DEFAULT NULL,
  `date_fin` datetime(6) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `plan_id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `statut` enum('ACTIF','ANNULE','EN_ATTENTE_PAIEMENT','EXPIRE') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKhemwxt8j9lgtn00bccuggm5i2` (`structure_id`),
  KEY `FKoqd6eigj7yoqaxn0vfxsuacv8` (`plan_id`),
  CONSTRAINT `FKdt38b8y5xdyyje76wjpfg5riq` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`),
  CONSTRAINT `FKoqd6eigj7yoqaxn0vfxsuacv8` FOREIGN KEY (`plan_id`) REFERENCES `plans_abonnement` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `actions_ia_en_attente` (
  `date_creation` datetime(6) NOT NULL,
  `date_traitement` datetime(6) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `message_id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `traite_par_id` binary(16) DEFAULT NULL,
  `erreur_execution` text COLLATE utf8mb4_unicode_ci,
  `payload_json` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `statut` enum('CONFIRMEE','EN_ATTENTE','EXPIREE','REJETEE') COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('ARCHIVE_COHORTE','ARCHIVE_MISSION','ARCHIVE_PROJET','CREATE_COHORTE','CREATE_MISSION','CREATE_REUNION','UPDATE_COHORTE','UPDATE_MISSION','UPDATE_PROJET','UPDATE_REUNION') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKk2ipffquagvfvq8v48a87ukxc` (`structure_id`),
  KEY `FKb4wdebu2ljpjkbvduordb660f` (`traite_par_id`),
  CONSTRAINT `FKb4wdebu2ljpjkbvduordb660f` FOREIGN KEY (`traite_par_id`) REFERENCES `users` (`id`),
  CONSTRAINT `FKk2ipffquagvfvq8v48a87ukxc` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `cohortes` (
  `date_debut` date DEFAULT NULL,
  `date_fin` date DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `parcours_id` binary(16) NOT NULL,
  `phase_id` binary(16) NOT NULL,
  `programme_id` binary(16) DEFAULT NULL,
  `structure_id` binary(16) NOT NULL,
  `nom` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `statut` enum('ARCHIVEE','EN_COURS','PLANIFIEE','TERMINEE') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKk1vo779bxd38j2mhk4hu2m4xp` (`parcours_id`),
  KEY `FK3l714k3usvaq8ydw0fl635bb6` (`phase_id`),
  KEY `FKr59chwkn343becnhydx1eqfry` (`programme_id`),
  KEY `FK418oyxofd5w03u3srxutvx1dp` (`structure_id`),
  CONSTRAINT `FK3l714k3usvaq8ydw0fl635bb6` FOREIGN KEY (`phase_id`) REFERENCES `phases` (`id`),
  CONSTRAINT `FK418oyxofd5w03u3srxutvx1dp` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`),
  CONSTRAINT `FKk1vo779bxd38j2mhk4hu2m4xp` FOREIGN KEY (`parcours_id`) REFERENCES `parcours` (`id`),
  CONSTRAINT `FKr59chwkn343becnhydx1eqfry` FOREIGN KEY (`programme_id`) REFERENCES `programmes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `cohortes_coachs` (
  `cohorte_id` binary(16) NOT NULL,
  `user_id` binary(16) NOT NULL,
  PRIMARY KEY (`cohorte_id`,`user_id`),
  KEY `FK1bwy307du2ffsi8fdv0d308h0` (`user_id`),
  CONSTRAINT `FK1bwy307du2ffsi8fdv0d308h0` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `FKd8x045oh6pq4ckyt5jptrlgdo` FOREIGN KEY (`cohorte_id`) REFERENCES `cohortes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `conversations` (
  `archivee` bit(1) NOT NULL,
  `date_creation` datetime(6) NOT NULL,
  `date_derniere_activite` datetime(6) DEFAULT NULL,
  `date_modification` datetime(6) NOT NULL,
  `coach_id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `contexte_json` text COLLATE utf8mb4_unicode_ci,
  `titre` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKkihaeoi206n77j054sl2drl86` (`coach_id`),
  KEY `FKhjmbgc2p3bvihd0vpufgvqv80` (`structure_id`),
  CONSTRAINT `FKhjmbgc2p3bvihd0vpufgvqv80` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`),
  CONSTRAINT `FKkihaeoi206n77j054sl2drl86` FOREIGN KEY (`coach_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `email_verification_codes` (
  `used` bit(1) NOT NULL,
  `expires_at` datetime(6) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `code` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `etapes` (
  `archive` bit(1) NOT NULL,
  `obligatoire` bit(1) NOT NULL,
  `ordre` int NOT NULL,
  `date_creation` datetime(6) NOT NULL,
  `date_modification` datetime(6) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `phase_id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `nom` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `FKq9yerrnc5g81bhswm980t0b89` (`phase_id`),
  KEY `FK93b05lnrtqj47qr77basbklbv` (`structure_id`),
  CONSTRAINT `FK93b05lnrtqj47qr77basbklbv` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`),
  CONSTRAINT `FKq9yerrnc5g81bhswm980t0b89` FOREIGN KEY (`phase_id`) REFERENCES `phases` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `historique_abonnements` (
  `renouvellement_auto` bit(1) NOT NULL,
  `date_creation` datetime(6) NOT NULL,
  `date_debut` datetime(6) DEFAULT NULL,
  `date_fin` datetime(6) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `plan_id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `source` enum('ADMINISTRATION','PAIEMENT') COLLATE utf8mb4_unicode_ci NOT NULL,
  `statut` enum('ACTIF','ANNULE','EN_ATTENTE_PAIEMENT','EXPIRE') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKnvjvskiiq21ewg2xydwr6xtql` (`plan_id`),
  KEY `FKratfeksrxm8n2s4hpp8oekvkj` (`structure_id`),
  CONSTRAINT `FKnvjvskiiq21ewg2xydwr6xtql` FOREIGN KEY (`plan_id`) REFERENCES `plans_abonnement` (`id`),
  CONSTRAINT `FKratfeksrxm8n2s4hpp8oekvkj` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `historique_progression` (
  `date_entree` datetime(6) NOT NULL,
  `date_sortie` datetime(6) DEFAULT NULL,
  `effectue_par_id` binary(16) DEFAULT NULL,
  `etape_entree_id` binary(16) DEFAULT NULL,
  `etape_sortie_id` binary(16) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `phase_entree_id` binary(16) DEFAULT NULL,
  `phase_sortie_id` binary(16) DEFAULT NULL,
  `progression_id` binary(16) NOT NULL,
  `raison` text COLLATE utf8mb4_unicode_ci,
  `type_changement` enum('AUTOMATIQUE','MANUEL') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKq60vssxpdj47alfrtpugtwl34` (`effectue_par_id`),
  KEY `FK8kw6l838iuc7ech4cjwq12dff` (`etape_entree_id`),
  KEY `FKmp5m4q2rvrd3msmry2mfxr6v2` (`etape_sortie_id`),
  KEY `FK2cwof33g2owlv5uhl4ppttk8` (`phase_entree_id`),
  KEY `FKoeke1wp03d3d2j3vol9rcnqbj` (`phase_sortie_id`),
  KEY `FKqovgyfcj82qkys0u4oc7s5aoq` (`progression_id`),
  CONSTRAINT `FK2cwof33g2owlv5uhl4ppttk8` FOREIGN KEY (`phase_entree_id`) REFERENCES `phases` (`id`),
  CONSTRAINT `FK8kw6l838iuc7ech4cjwq12dff` FOREIGN KEY (`etape_entree_id`) REFERENCES `etapes` (`id`),
  CONSTRAINT `FKmp5m4q2rvrd3msmry2mfxr6v2` FOREIGN KEY (`etape_sortie_id`) REFERENCES `etapes` (`id`),
  CONSTRAINT `FKoeke1wp03d3d2j3vol9rcnqbj` FOREIGN KEY (`phase_sortie_id`) REFERENCES `phases` (`id`),
  CONSTRAINT `FKq60vssxpdj47alfrtpugtwl34` FOREIGN KEY (`effectue_par_id`) REFERENCES `users` (`id`),
  CONSTRAINT `FKqovgyfcj82qkys0u4oc7s5aoq` FOREIGN KEY (`progression_id`) REFERENCES `progressions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ia_usage` (
  `tokens_entree` int NOT NULL,
  `tokens_sortie` int NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `user_id` binary(16) NOT NULL,
  `role` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `conversation_id` varchar(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `modele` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `invitation_links` (
  `actif` bit(1) NOT NULL,
  `expires_at` datetime(6) NOT NULL,
  `id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('ADMIN_STRUCTURE','COACH','ENTREPRENEUR') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKcrw1eng7uk2gmkty473jeobwf` (`token`),
  KEY `FK1ww1ii1wbh3keo7yh4yvm4x0d` (`structure_id`),
  CONSTRAINT `FK1ww1ii1wbh3keo7yh4yvm4x0d` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `livrable_versions` (
  `date_echeance_correction` date DEFAULT NULL,
  `note` float DEFAULT NULL,
  `numero_version` int NOT NULL,
  `date_depot` datetime(6) NOT NULL,
  `date_evaluation` datetime(6) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `livrable_id` binary(16) NOT NULL,
  `nom` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ressource_recommandee` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `url` varchar(1000) COLLATE utf8mb4_unicode_ci NOT NULL,
  `commentaire_coach` text COLLATE utf8mb4_unicode_ci,
  `commentaire_entrepreneur` text COLLATE utf8mb4_unicode_ci,
  `contenu` mediumtext COLLATE utf8mb4_unicode_ci,
  `motif_refus` text COLLATE utf8mb4_unicode_ci,
  `pointsacorriger` text COLLATE utf8mb4_unicode_ci,
  `statut` enum('A_CORRIGER','EN_ATTENTE','REJETE','VALIDE') COLLATE utf8mb4_unicode_ci NOT NULL,
  `type_piece` enum('FICHIER','LIEN','TEMPLATE','TEXTE') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK5165q0n2dqv4k0ydksicjfv7k` (`livrable_id`),
  CONSTRAINT `FK5165q0n2dqv4k0ydksicjfv7k` FOREIGN KEY (`livrable_id`) REFERENCES `livrables` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `livrables` (
  `date_echeance_correction` date DEFAULT NULL,
  `note` float DEFAULT NULL,
  `numero_version` int NOT NULL,
  `date_depot` datetime(6) NOT NULL,
  `date_evaluation` datetime(6) DEFAULT NULL,
  `date_validation` datetime(6) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `livrable_attendu_id` binary(16) DEFAULT NULL,
  `mission_projet_id` binary(16) NOT NULL,
  `projet_id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `nom` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ressource_recommandee` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `url` varchar(1000) COLLATE utf8mb4_unicode_ci NOT NULL,
  `commentaire_coach` text COLLATE utf8mb4_unicode_ci,
  `contenu` mediumtext COLLATE utf8mb4_unicode_ci,
  `motif_refus` text COLLATE utf8mb4_unicode_ci,
  `pointsacorriger` text COLLATE utf8mb4_unicode_ci,
  `statut` enum('A_CORRIGER','EN_ATTENTE','REJETE','VALIDE') COLLATE utf8mb4_unicode_ci NOT NULL,
  `type_piece` enum('FICHIER','LIEN','TEMPLATE','TEXTE') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK8udtmesu5i478laqp7tg178lw` (`livrable_attendu_id`),
  KEY `FKt4k0vvqw18061iak8hu5p2jq2` (`mission_projet_id`),
  KEY `FKq3v9lvg7wrhnml20ak2s4bugu` (`projet_id`),
  KEY `FK8isqlwt2yxabxvh8ops6p55l9` (`structure_id`),
  CONSTRAINT `FK8isqlwt2yxabxvh8ops6p55l9` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`),
  CONSTRAINT `FK8udtmesu5i478laqp7tg178lw` FOREIGN KEY (`livrable_attendu_id`) REFERENCES `livrables_attendus` (`id`),
  CONSTRAINT `FKq3v9lvg7wrhnml20ak2s4bugu` FOREIGN KEY (`projet_id`) REFERENCES `projets` (`id`),
  CONSTRAINT `FKt4k0vvqw18061iak8hu5p2jq2` FOREIGN KEY (`mission_projet_id`) REFERENCES `missions_projet` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `livrables_attendus` (
  `obligatoire` bit(1) NOT NULL,
  `ordre` int DEFAULT NULL,
  `date_creation` datetime(6) NOT NULL,
  `id` binary(16) NOT NULL,
  `mission_cohorte_id` binary(16) DEFAULT NULL,
  `mission_etape_id` binary(16) DEFAULT NULL,
  `template_type` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `titre` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `template_configuration` text COLLATE utf8mb4_unicode_ci,
  `type` enum('FICHIER','LIEN','TEMPLATE','TEXTE') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKi9xkxg1qc11e2cmq5obhr9nf` (`mission_cohorte_id`),
  KEY `FK2pxw3vlad16r0j1n1bsd1vphm` (`mission_etape_id`),
  CONSTRAINT `FK2pxw3vlad16r0j1n1bsd1vphm` FOREIGN KEY (`mission_etape_id`) REFERENCES `missions_etape` (`id`),
  CONSTRAINT `FKi9xkxg1qc11e2cmq5obhr9nf` FOREIGN KEY (`mission_cohorte_id`) REFERENCES `missions_cohorte` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `meeting_participants` (
  `created_at` datetime(6) NOT NULL,
  `joined_at` datetime(6) DEFAULT NULL,
  `left_at` datetime(6) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `meeting_id` binary(16) NOT NULL,
  `user_id` binary(16) NOT NULL,
  `role` enum('ATTENDEE','HOST') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK2he4l7ab80h2ewpr0gow5s358` (`meeting_id`,`user_id`),
  KEY `FKxecipyjm07w1e3yujc9nqm5n` (`user_id`),
  CONSTRAINT `FK7uds89kvog9etbdnn653vsf6y` FOREIGN KEY (`meeting_id`) REFERENCES `meetings` (`id`),
  CONSTRAINT `FKxecipyjm07w1e3yujc9nqm5n` FOREIGN KEY (`user_id`) REFERENCES `membres_structures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `meetings` (
  `duration_minutes` int NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `scheduled_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  `coach_id` binary(16) NOT NULL,
  `cohort_id` binary(16) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `room_identifier` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `address` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `objectif` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `compte_rendu` text COLLATE utf8mb4_unicode_ci,
  `decisions` text COLLATE utf8mb4_unicode_ci,
  `location` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `mode` enum('ONLINE','PRESENTIEL') COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` enum('CANCELLED','ENDED','ONGOING','PLANNED') COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('GROUP','INDIVIDUAL') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKn0dji37b5juikdgckualbbylw` (`room_identifier`),
  KEY `FKo9q7jw3wpefv0j31k3epdnc94` (`coach_id`),
  KEY `FK53m8ynwqrxvcd3gp0wufvf09b` (`cohort_id`),
  KEY `FK4ilx9qc70277tu04vfdsfhky6` (`structure_id`),
  CONSTRAINT `FK4ilx9qc70277tu04vfdsfhky6` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`),
  CONSTRAINT `FK53m8ynwqrxvcd3gp0wufvf09b` FOREIGN KEY (`cohort_id`) REFERENCES `cohortes` (`id`),
  CONSTRAINT `FKo9q7jw3wpefv0j31k3epdnc94` FOREIGN KEY (`coach_id`) REFERENCES `membres_structures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `membres_structures` (
  `date_invitation` datetime(6) DEFAULT NULL,
  `invitation_token_expires_at` datetime(6) DEFAULT NULL,
  `cohorte_id` binary(16) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `invite_par_id` binary(16) DEFAULT NULL,
  `structure_id` binary(16) NOT NULL,
  `user_id` binary(16) NOT NULL,
  `invitation_token` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role` enum('ADMIN_STRUCTURE','COACH','ENTREPRENEUR') COLLATE utf8mb4_unicode_ci NOT NULL,
  `statut` enum('ACCEPTE','EN_ATTENTE','REFUSE') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKr5o105mvpltgfyxrpk47gr3ep` (`cohorte_id`),
  KEY `FKleluntbihj3iueqcuo62aa9qa` (`invite_par_id`),
  KEY `FK1eooeyj5qoyl1rngbnj7y6cna` (`structure_id`),
  KEY `FKpj2vil5522l3maysd4jsdn67g` (`user_id`),
  CONSTRAINT `FK1eooeyj5qoyl1rngbnj7y6cna` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`),
  CONSTRAINT `FKleluntbihj3iueqcuo62aa9qa` FOREIGN KEY (`invite_par_id`) REFERENCES `users` (`id`),
  CONSTRAINT `FKpj2vil5522l3maysd4jsdn67g` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `FKr5o105mvpltgfyxrpk47gr3ep` FOREIGN KEY (`cohorte_id`) REFERENCES `cohortes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `messages` (
  `date_envoi` datetime(6) NOT NULL,
  `id` binary(16) NOT NULL,
  `conversation_id` varchar(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `model` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `actions_json` text COLLATE utf8mb4_unicode_ci,
  `contenu` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `sources_json` text COLLATE utf8mb4_unicode_ci,
  `auteur` enum('ASSISTANT','COACH') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKt492th6wsovh1nush5yl5jj8e` (`conversation_id`),
  CONSTRAINT `FKt492th6wsovh1nush5yl5jj8e` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `mission_cohorte_ressources` (
  `mission_cohorte_id` binary(16) NOT NULL,
  `ressource_id` binary(16) NOT NULL,
  PRIMARY KEY (`mission_cohorte_id`,`ressource_id`),
  KEY `FK53n7e21wrmj0wjtdmd95w2l7b` (`ressource_id`),
  CONSTRAINT `FK53n7e21wrmj0wjtdmd95w2l7b` FOREIGN KEY (`ressource_id`) REFERENCES `ressources` (`id`),
  CONSTRAINT `FKoo1etql904vak6o6xfl5tw50g` FOREIGN KEY (`mission_cohorte_id`) REFERENCES `missions_cohorte` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `missions_cohorte` (
  `archive` bit(1) NOT NULL,
  `date_echeance` date DEFAULT NULL,
  `verrouillee` bit(1) NOT NULL,
  `date_archivage` datetime(6) DEFAULT NULL,
  `date_creation` datetime(6) NOT NULL,
  `date_verrouillage` datetime(6) DEFAULT NULL,
  `cohorte_id` binary(16) DEFAULT NULL,
  `etape_id` binary(16) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `modele_id` binary(16) DEFAULT NULL,
  `structure_id` binary(16) NOT NULL,
  `titre` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `priorite` enum('BASSE','HAUTE','MOYENNE','URGENTE') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK1bvk13d88on7baawg1kkw1f6r` (`cohorte_id`),
  KEY `FK9d2xofoox20mww37scqmpyfp5` (`etape_id`),
  KEY `FKfody210pn2sleoq6lvva708xc` (`modele_id`),
  KEY `FK2jp243gbms7ienc8wagidbxif` (`structure_id`),
  CONSTRAINT `FK1bvk13d88on7baawg1kkw1f6r` FOREIGN KEY (`cohorte_id`) REFERENCES `cohortes` (`id`),
  CONSTRAINT `FK2jp243gbms7ienc8wagidbxif` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`),
  CONSTRAINT `FK9d2xofoox20mww37scqmpyfp5` FOREIGN KEY (`etape_id`) REFERENCES `etapes` (`id`),
  CONSTRAINT `FKfody210pn2sleoq6lvva708xc` FOREIGN KEY (`modele_id`) REFERENCES `missions_modeles` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `missions_etape` (
  `obligatoire` bit(1) NOT NULL,
  `ordre` int DEFAULT NULL,
  `date_creation` datetime(6) NOT NULL,
  `etape_id` binary(16) NOT NULL,
  `id` binary(16) NOT NULL,
  `modele_id` binary(16) DEFAULT NULL,
  `structure_id` binary(16) NOT NULL,
  `titre` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `FKmbn8jwtyui4cbnd6cxpabcix5` (`etape_id`),
  KEY `FKs2mcy7d5mvy1mv571us0p06j3` (`modele_id`),
  KEY `FKe852iegvy6oii4gmhuhvg0bqb` (`structure_id`),
  CONSTRAINT `FKe852iegvy6oii4gmhuhvg0bqb` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`),
  CONSTRAINT `FKmbn8jwtyui4cbnd6cxpabcix5` FOREIGN KEY (`etape_id`) REFERENCES `etapes` (`id`),
  CONSTRAINT `FKs2mcy7d5mvy1mv571us0p06j3` FOREIGN KEY (`modele_id`) REFERENCES `missions_modeles` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `missions_modeles` (
  `obligatoire` bit(1) NOT NULL,
  `ordre` int DEFAULT NULL,
  `date_creation` datetime(6) NOT NULL,
  `etape_id` binary(16) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `titre` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `priorite_par_defaut` enum('BASSE','HAUTE','MOYENNE','URGENTE') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKkj2slyg4tvay8rkgdwoae70pe` (`etape_id`),
  KEY `FK4kr0p2vvoquvsrdy57gkfohl7` (`structure_id`),
  CONSTRAINT `FK4kr0p2vvoquvsrdy57gkfohl7` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`),
  CONSTRAINT `FKkj2slyg4tvay8rkgdwoae70pe` FOREIGN KEY (`etape_id`) REFERENCES `etapes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `missions_projet` (
  `archive` bit(1) NOT NULL,
  `date_archivage` datetime(6) DEFAULT NULL,
  `date_creation` datetime(6) NOT NULL,
  `assigne_a_id` binary(16) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `mission_cohorte_id` binary(16) DEFAULT NULL,
  `mission_etape_id` binary(16) DEFAULT NULL,
  `projet_id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `priorite` enum('BASSE','HAUTE','MOYENNE','URGENTE') COLLATE utf8mb4_unicode_ci NOT NULL,
  `statut` enum('A_FAIRE','A_REVOIR','EN_COURS','SOUMIS','VALIDE') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKdxh9s0pudqmjopjdckvsr46ld` (`assigne_a_id`),
  KEY `FKqm57jr17jfvfgv3gixbw0rko4` (`mission_cohorte_id`),
  KEY `FKs3gqbyuo6ul1trt0ffybpxrws` (`mission_etape_id`),
  KEY `FKk4jxr7xtavkxx2jyitu5hcrh4` (`projet_id`),
  KEY `FKt3q6dmylj1xtlan1aw54ktpcx` (`structure_id`),
  CONSTRAINT `FKdxh9s0pudqmjopjdckvsr46ld` FOREIGN KEY (`assigne_a_id`) REFERENCES `users` (`id`),
  CONSTRAINT `FKk4jxr7xtavkxx2jyitu5hcrh4` FOREIGN KEY (`projet_id`) REFERENCES `projets` (`id`),
  CONSTRAINT `FKqm57jr17jfvfgv3gixbw0rko4` FOREIGN KEY (`mission_cohorte_id`) REFERENCES `missions_cohorte` (`id`),
  CONSTRAINT `FKs3gqbyuo6ul1trt0ffybpxrws` FOREIGN KEY (`mission_etape_id`) REFERENCES `missions_etape` (`id`),
  CONSTRAINT `FKt3q6dmylj1xtlan1aw54ktpcx` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `parcours` (
  `archive` bit(1) NOT NULL,
  `date_creation` datetime(6) NOT NULL,
  `date_modification` datetime(6) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `programme_id` binary(16) DEFAULT NULL,
  `structure_id` binary(16) NOT NULL,
  `nom` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `FKmosj4xsn7yrtog2u2rot9a4i8` (`programme_id`),
  KEY `FKxm269uqe7yqpxbkt5sdejcax` (`structure_id`),
  CONSTRAINT `FKmosj4xsn7yrtog2u2rot9a4i8` FOREIGN KEY (`programme_id`) REFERENCES `programmes` (`id`),
  CONSTRAINT `FKxm269uqe7yqpxbkt5sdejcax` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `parcours_phases` (
  `ordre` int NOT NULL,
  `id` binary(16) NOT NULL,
  `parcours_id` binary(16) NOT NULL,
  `phase_id` binary(16) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_parcours_phase` (`parcours_id`,`phase_id`),
  UNIQUE KEY `uk_parcours_phase_ordre` (`parcours_id`,`ordre`),
  KEY `FKf7twx506x8wmggfhpqyehefql` (`phase_id`),
  CONSTRAINT `FKekcguibc56yb86hv9wtx8mx9f` FOREIGN KEY (`parcours_id`) REFERENCES `parcours` (`id`),
  CONSTRAINT `FKf7twx506x8wmggfhpqyehefql` FOREIGN KEY (`phase_id`) REFERENCES `phases` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `participations_cohorte` (
  `date_entree` datetime(6) NOT NULL,
  `date_sortie` datetime(6) DEFAULT NULL,
  `cohorte_id` binary(16) NOT NULL,
  `effectue_par_id` binary(16) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `projet_id` binary(16) NOT NULL,
  `raison` text COLLATE utf8mb4_unicode_ci,
  `motif_sortie` enum('PROMU','RETIRE','TERMINE') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKqeqwck03f5aj24xl9n0o52x8k` (`cohorte_id`),
  KEY `FKoqonfs2ma6k45en4fl6k2pa8w` (`effectue_par_id`),
  KEY `FKocn334gnvsbyuqmjae1t1mtft` (`projet_id`),
  CONSTRAINT `FKocn334gnvsbyuqmjae1t1mtft` FOREIGN KEY (`projet_id`) REFERENCES `projets` (`id`),
  CONSTRAINT `FKoqonfs2ma6k45en4fl6k2pa8w` FOREIGN KEY (`effectue_par_id`) REFERENCES `users` (`id`),
  CONSTRAINT `FKqeqwck03f5aj24xl9n0o52x8k` FOREIGN KEY (`cohorte_id`) REFERENCES `cohortes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `password_reset_tokens` (
  `used` bit(1) NOT NULL,
  `expires_at` datetime(6) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `code` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `phases` (
  `archive` bit(1) NOT NULL,
  `date_creation` datetime(6) NOT NULL,
  `date_modification` datetime(6) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `nom` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `stade` enum('ACCELERATION','INCUBATION','POST_INCUBATION','PRE_INCUBATION') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKl9dmfonfpd5jla91es4engk3a` (`structure_id`),
  CONSTRAINT `FKl9dmfonfpd5jla91es4engk3a` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `plans_abonnement` (
  `actif` bit(1) NOT NULL,
  `devise` varchar(3) COLLATE utf8mb4_unicode_ci NOT NULL,
  `duree_jours` int DEFAULT NULL,
  `est_defaut` bit(1) NOT NULL,
  `ia_coach_active` bit(1) NOT NULL,
  `ia_entrepreneur_active` bit(1) NOT NULL,
  `max_cohortes` int DEFAULT NULL,
  `ordre` int NOT NULL,
  `date_creation` datetime(6) NOT NULL,
  `date_modification` datetime(6) NOT NULL,
  `ia_tokens_mensuels` bigint DEFAULT NULL,
  `prix` bigint NOT NULL,
  `id` binary(16) NOT NULL,
  `code` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `libelle` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKnkga0m0sy8dbwt4yxgn7w0hjq` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `programmes` (
  `archive` bit(1) NOT NULL,
  `date_creation` datetime(6) NOT NULL,
  `date_modification` datetime(6) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `nom` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`id`),
  KEY `FKhncqmom5xs04fmd7dp3rbac17` (`structure_id`),
  CONSTRAINT `FKhncqmom5xs04fmd7dp3rbac17` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `progressions` (
  `pourcentage_avancement` int NOT NULL,
  `date_debut` datetime(6) NOT NULL,
  `date_derniere_maj` datetime(6) DEFAULT NULL,
  `date_fin` datetime(6) DEFAULT NULL,
  `etape_id` binary(16) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `parcours_id` binary(16) NOT NULL,
  `phase_id` binary(16) NOT NULL,
  `projet_id` binary(16) NOT NULL,
  `statut` enum('ABANDONNE','EN_COURS','EN_PAUSE','TERMINE') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_projet_parcours` (`projet_id`,`parcours_id`),
  KEY `FK1n00j6nah6pjbsw5ii70e85nc` (`etape_id`),
  KEY `FKknkx2q0cj6uwuv3su3wpqlve8` (`parcours_id`),
  KEY `FK7jif5135a5eebbux7ttt7ygjd` (`phase_id`),
  CONSTRAINT `FK1n00j6nah6pjbsw5ii70e85nc` FOREIGN KEY (`etape_id`) REFERENCES `etapes` (`id`),
  CONSTRAINT `FK7jif5135a5eebbux7ttt7ygjd` FOREIGN KEY (`phase_id`) REFERENCES `phases` (`id`),
  CONSTRAINT `FKknkx2q0cj6uwuv3su3wpqlve8` FOREIGN KEY (`parcours_id`) REFERENCES `parcours` (`id`),
  CONSTRAINT `FKlqdum2x7ospwd9xru8o0rmdgd` FOREIGN KEY (`projet_id`) REFERENCES `projets` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `projets` (
  `archive` bit(1) NOT NULL,
  `score_maturite` int DEFAULT NULL,
  `date_archivage` datetime(6) DEFAULT NULL,
  `date_creation` datetime(6) NOT NULL,
  `cohorte_id` binary(16) DEFAULT NULL,
  `entrepreneur_id` binary(16) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `nom` varchar(150) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `secteur` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `statut` enum('ABANDONNE','ACTIF','DIPLOME') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK9juba2fdiwpy9lun9586vg2wk` (`cohorte_id`),
  KEY `FK59l1x452j6qd0ekur3009n8np` (`entrepreneur_id`),
  KEY `FKcelxnbi631hg9o0hve1dce0bp` (`structure_id`),
  CONSTRAINT `FK59l1x452j6qd0ekur3009n8np` FOREIGN KEY (`entrepreneur_id`) REFERENCES `users` (`id`),
  CONSTRAINT `FK9juba2fdiwpy9lun9586vg2wk` FOREIGN KEY (`cohorte_id`) REFERENCES `cohortes` (`id`),
  CONSTRAINT `FKcelxnbi631hg9o0hve1dce0bp` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `ressources` (
  `archivee` bit(1) NOT NULL,
  `created_at` datetime(6) NOT NULL,
  `date_archivage` datetime(6) DEFAULT NULL,
  `taille` bigint DEFAULT NULL,
  `updated_at` datetime(6) NOT NULL,
  `cohorte_id` binary(16) DEFAULT NULL,
  `etape_id` binary(16) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `parcours_id` binary(16) DEFAULT NULL,
  `phase_id` binary(16) DEFAULT NULL,
  `structure_id` binary(16) NOT NULL,
  `mime_type` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `titre` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `url` varchar(2000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `nom_fichier` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `portee` enum('COHORTE','MISSION','PARCOURS','PHASE','STRUCTURE') COLLATE utf8mb4_unicode_ci NOT NULL,
  `type` enum('AUTRE','DOCUMENT','LIEN','PDF','VIDEO') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FK1e5kq4h5n0g7e8eoogu6m47gy` (`cohorte_id`),
  KEY `FKe5f2q4gaehaacwkygspbaosxf` (`etape_id`),
  KEY `FK6sel1sqs1e9bdh9ch1pwxer79` (`parcours_id`),
  KEY `FK2k4j9kh7dvduegebhiv62njxj` (`phase_id`),
  KEY `FK2lcplaoneqeub5ac1euo0t3p3` (`structure_id`),
  CONSTRAINT `FK1e5kq4h5n0g7e8eoogu6m47gy` FOREIGN KEY (`cohorte_id`) REFERENCES `cohortes` (`id`),
  CONSTRAINT `FK2k4j9kh7dvduegebhiv62njxj` FOREIGN KEY (`phase_id`) REFERENCES `phases` (`id`),
  CONSTRAINT `FK2lcplaoneqeub5ac1euo0t3p3` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`),
  CONSTRAINT `FK6sel1sqs1e9bdh9ch1pwxer79` FOREIGN KEY (`parcours_id`) REFERENCES `parcours` (`id`),
  CONSTRAINT `FKe5f2q4gaehaacwkygspbaosxf` FOREIGN KEY (`etape_id`) REFERENCES `etapes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `structures` (
  `date_creation` datetime(6) NOT NULL,
  `id` binary(16) NOT NULL,
  `proprietaire_id` binary(16) NOT NULL,
  `slug` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `adresse` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `logo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `nom` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `pays` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `site_web` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `telephone` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ville` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `statut` enum('ACTIVE','SUSPENDUE') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UKgheignmi7xlrfpf3fdamfplky` (`slug`),
  KEY `FKp6fa41xqevxti2geatlirtu84` (`proprietaire_id`),
  CONSTRAINT `FKp6fa41xqevxti2geatlirtu84` FOREIGN KEY (`proprietaire_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `transactions_paiement` (
  `date_confirmation` datetime(6) DEFAULT NULL,
  `date_creation` datetime(6) NOT NULL,
  `montant` bigint NOT NULL,
  `id` binary(16) NOT NULL,
  `plan_vise_id` binary(16) NOT NULL,
  `structure_id` binary(16) NOT NULL,
  `devise` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `moyen_paiement` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payload_ipn_brut` text COLLATE utf8mb4_unicode_ci,
  `ref_command` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `telephone_client` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `token_paiement` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `statut` enum('ANNULE','ECHEC','EN_ATTENTE','SUCCES') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK8kbeyycny7sslec2e0hfr2ekf` (`ref_command`),
  KEY `FKc768qyxu3p76sg6gqo0jsxyjq` (`plan_vise_id`),
  KEY `FKc7841eaw795qtbug7g1odec45` (`structure_id`),
  CONSTRAINT `FKc768qyxu3p76sg6gqo0jsxyjq` FOREIGN KEY (`plan_vise_id`) REFERENCES `plans_abonnement` (`id`),
  CONSTRAINT `FKc7841eaw795qtbug7g1odec45` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `transitions_phase` (
  `date_transition` datetime(6) NOT NULL,
  `effectue_par` binary(16) DEFAULT NULL,
  `id` binary(16) NOT NULL,
  `phase_cible_id` binary(16) DEFAULT NULL,
  `phase_source_id` binary(16) DEFAULT NULL,
  `projet_id` binary(16) NOT NULL,
  `raison` text COLLATE utf8mb4_unicode_ci,
  `type_transition` enum('AUTOMATIQUE','MANUEL') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  KEY `FKldayw30qejy0jnki0ati58y07` (`effectue_par`),
  KEY `FK7syrcwehnu7e2afxmy9r8vjuc` (`phase_cible_id`),
  KEY `FKn1fy7rcr8ock3xq6nyk3wk9pq` (`phase_source_id`),
  KEY `FKi8v9wmephowxu1w5qfc92fjye` (`projet_id`),
  CONSTRAINT `FK7syrcwehnu7e2afxmy9r8vjuc` FOREIGN KEY (`phase_cible_id`) REFERENCES `phases` (`id`),
  CONSTRAINT `FKi8v9wmephowxu1w5qfc92fjye` FOREIGN KEY (`projet_id`) REFERENCES `projets` (`id`),
  CONSTRAINT `FKldayw30qejy0jnki0ati58y07` FOREIGN KEY (`effectue_par`) REFERENCES `users` (`id`),
  CONSTRAINT `FKn1fy7rcr8ock3xq6nyk3wk9pq` FOREIGN KEY (`phase_source_id`) REFERENCES `phases` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `users` (
  `email_verified` bit(1) NOT NULL,
  `date_creation` datetime(6) NOT NULL,
  `id` binary(16) NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `nom` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `prenom` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role_global` enum('SUPER_ADMIN','USER') COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `UK6dotkott2kjsp8vw4d0m25fb7` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Objets issus des migrations appliquees (ex-V12, ex-V15)
-- ---------------------------------------------------------------------

ALTER TABLE `missions_projet`
    ADD CONSTRAINT `uk_mission_projet_unique` UNIQUE (`mission_cohorte_id`, `projet_id`, `structure_id`),
    ADD CONSTRAINT `uk_mission_etape_projet_structure` UNIQUE (`mission_etape_id`, `projet_id`, `structure_id`);

CREATE INDEX `idx_conv_derniere_activite` ON `conversations` (`date_derniere_activite` DESC);
CREATE INDEX `idx_conv_archivee` ON `conversations` (`archivee`);

ALTER TABLE `ia_usage`
    ADD CONSTRAINT `fk_ia_usage_structure` FOREIGN KEY (`structure_id`) REFERENCES `structures` (`id`) ON DELETE CASCADE,
    ADD CONSTRAINT `fk_ia_usage_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
    ADD CONSTRAINT `fk_ia_usage_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `conversations` (`id`) ON DELETE SET NULL,
    ADD INDEX `idx_ia_usage_structure_date` (`structure_id`, `created_at`),
    ADD INDEX `idx_ia_usage_user_date` (`user_id`, `created_at`);

SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- Donnees de reference : plans d'abonnement (ex-V13)
-- ---------------------------------------------------------------------

INSERT INTO `plans_abonnement`
    (`id`, `code`, `libelle`, `description`, `prix`, `devise`, `duree_jours`, `max_cohortes`,
     `ia_coach_active`, `ia_entrepreneur_active`, `ia_tokens_mensuels`, `est_defaut`, `actif`, `ordre`,
     `date_creation`, `date_modification`)
VALUES
    (UUID_TO_BIN(UUID()), 'FREEMIUM', 'Freemium',
     'Pour démarrer : une cohorte et l''assistant IA pour les coachs.',
     0, 'XOF', NULL, 1,
     TRUE, FALSE, 200000, TRUE, TRUE, 1,
     CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6)),
    (UUID_TO_BIN(UUID()), 'PREMIUM', 'Premium',
     'Cohortes illimitées et assistant IA pour toute la structure, entrepreneurs compris.',
     90000, 'XOF', 365, NULL,
     TRUE, TRUE, NULL, FALSE, TRUE, 2,
     CURRENT_TIMESTAMP(6), CURRENT_TIMESTAMP(6));
