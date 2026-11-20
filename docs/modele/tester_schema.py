"""Verifie les regles du schema v1 : chaque cas doit reussir (OK) ou etre refuse (REFUS)."""
import os
import subprocess
import sys

MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.4\bin\mysql.exe"
user, db = sys.argv[1], sys.argv[2]
env = dict(os.environ)  # MYSQL_PWD fourni par l'appelant


def run(sql):
    r = subprocess.run([MYSQL, "-u", user, "-h", "127.0.0.1", "-P", "3307", db, "-e", sql],
                       capture_output=True, text=True, env=env)
    err = "\n".join(l for l in r.stderr.splitlines() if "Using a password" not in l)
    return r.returncode == 0, err


def U(n):  # uuid lisible -> binaire
    return "UNHEX(LPAD('%x', 32, '0'))" % n


ok_count = 0
fail = []


def expect(label, sql, should_pass):
    global ok_count
    passed, err = run(sql)
    good = passed == should_pass
    ok_count += good
    status = "OK " if good else "ECHEC"
    detail = "" if passed else " -> " + err.split(":", 1)[-1].strip()[:110]
    print("[%s] %s %s%s" % (status, "accepte" if should_pass else "refuse ", label, detail))
    if not good:
        fail.append(label)


# --- donnees de base : 2 structures, 1 compte par membre
setup = f"""
INSERT INTO user_account (id,email,password_hash,first_name,last_name) VALUES
 ({U(1)},'admin@a.test','x','A','Admin'),({U(2)},'coach@a.test','x','C','Coach'),
 ({U(3)},'fatou@a.test','x','F','Fatou'),({U(4)},'admin@b.test','x','B','Admin');
INSERT INTO organization (id,name,slug) VALUES ({U(100)},'Fabrique 360','fabrique-360'),({U(200)},'Autre','autre');
INSERT INTO member (id,organization_id,user_id,role,joined_at) VALUES
 ({U(11)},{U(100)},{U(1)},'ADMIN',NOW()),({U(12)},{U(100)},{U(2)},'FACILITATOR',NOW()),
 ({U(13)},{U(100)},{U(3)},'PARTICIPANT',NOW()),({U(21)},{U(200)},{U(4)},'ADMIN',NOW());
INSERT INTO document_template (id,code,name,definition) VALUES ({U(900)},'BUSINESS_MODEL_CANVAS','BMC','{{}}');
INSERT INTO program (id,organization_id,title) VALUES ({U(300)},{U(100)},'Pre-incubation'),({U(301)},{U(100)},'Incubation'),({U(399)},{U(200)},'Programme B');
INSERT INTO step (id,organization_id,program_id,title,position) VALUES ({U(310)},{U(100)},{U(300)},'Validation',0),({U(311)},{U(100)},{U(300)},'Proposition',1);
INSERT INTO activity (id,organization_id,step_id,title,kind,position,deliverable_format,document_template_id) VALUES
 ({U(320)},{U(100)},{U(310)},'Entretiens','TASK',0,'FILE',NULL),({U(321)},{U(100)},{U(311)},'BMC','TASK',0,'DOCUMENT',{U(900)});
INSERT INTO cohort (id,organization_id,program_id,name,start_date,planned_end_date) VALUES
 ({U(400)},{U(100)},{U(300)},'2026-A','2026-01-01','2026-06-30'),({U(401)},{U(100)},{U(300)},'2026-B','2026-07-01','2026-12-31');
INSERT INTO cohort_step (id,organization_id,cohort_id,source_step_id,title,position) VALUES
 ({U(410)},{U(100)},{U(400)},{U(310)},'Validation',0),({U(411)},{U(100)},{U(401)},{U(310)},'Validation',0);
INSERT INTO cohort_activity (id,organization_id,cohort_id,cohort_step_id,origin,source_activity_id,title,kind,position,deliverable_format) VALUES
 ({U(420)},{U(100)},{U(400)},{U(410)},'PROGRAM',{U(320)},'Entretiens','TASK',0,'FILE'),
 ({U(421)},{U(100)},{U(401)},{U(411)},'PROGRAM',{U(320)},'Entretiens','TASK',0,'FILE');
INSERT INTO project (id,organization_id,name) VALUES ({U(500)},{U(100)},'AgriFresh');
INSERT INTO enrollment (id,organization_id,project_id,cohort_id,started_at) VALUES ({U(510)},{U(100)},{U(500)},{U(400)},NOW());
INSERT INTO deliverable (id,organization_id,cohort_id,enrollment_id,cohort_activity_id) VALUES ({U(600)},{U(100)},{U(400)},{U(510)},{U(420)});
"""
expect("donnees de base coherentes", setup, True)

print("\n-- Isolation entre structures (cles composites)")
expect("programme de A avec programme suivant dans B",
       f"UPDATE program SET next_program_id={U(399)} WHERE id={U(300)}", False)
expect("cohorte de B sur un programme de A",
       f"INSERT INTO cohort (id,organization_id,program_id,name,start_date,planned_end_date) VALUES ({U(402)},{U(200)},{U(300)},'X','2026-01-01','2026-02-01')", False)
expect("membre de B ajoute comme coach d'une cohorte de A",
       f"INSERT INTO cohort_facilitator (organization_id,cohort_id,member_id) VALUES ({U(100)},{U(400)},{U(21)})", False)
expect("programme suivant dans la meme structure",
       f"UPDATE program SET next_program_id={U(301)} WHERE id={U(300)}", True)
expect("programme suivant = lui-meme",
       f"UPDATE program SET next_program_id={U(301)} WHERE id={U(301)}", False)

print("\n-- Programme et contenu")
expect("deux etapes vivantes a la meme position",
       f"INSERT INTO step (id,organization_id,program_id,title,position) VALUES ({U(312)},{U(100)},{U(300)},'Doublon',1)", False)
expect("meme position apres suppression (annulable) de l'ancienne",
       f"UPDATE step SET deleted_at=NOW() WHERE id={U(311)}; INSERT INTO step (id,organization_id,program_id,title,position) VALUES ({U(313)},{U(100)},{U(300)},'Remplace',1)", True)
expect("livrable DOCUMENT sans modele",
       f"INSERT INTO activity (id,organization_id,step_id,title,kind,position,deliverable_format) VALUES ({U(322)},{U(100)},{U(310)},'X','TASK',5,'DOCUMENT')", False)
expect("modele de document sans format DOCUMENT",
       f"INSERT INTO activity (id,organization_id,step_id,title,kind,position,document_template_id) VALUES ({U(323)},{U(100)},{U(310)},'X','TASK',6,{U(900)})", False)

print("\n-- Contenu de cohorte")
expect("activite de cohorte (origine COHORT) sans source",
       f"INSERT INTO cohort_activity (id,organization_id,cohort_id,cohort_step_id,origin,title,kind,position) VALUES ({U(422)},{U(100)},{U(400)},{U(410)},'COHORT','Atelier fiscalite','WORKSHOP',1)", True)
expect("origine PROGRAM sans activite source",
       f"INSERT INTO cohort_activity (id,organization_id,cohort_id,cohort_step_id,origin,title,kind,position) VALUES ({U(423)},{U(100)},{U(400)},{U(410)},'PROGRAM','X','TASK',2)", False)
expect("activite ponctuelle sans participation",
       f"INSERT INTO cohort_activity (id,organization_id,cohort_id,cohort_step_id,origin,title,kind,position) VALUES ({U(424)},{U(100)},{U(400)},{U(410)},'ENROLLMENT','X','TASK',3)", False)
expect("activite ponctuelle pour une participation d'une autre cohorte",
       f"INSERT INTO cohort_activity (id,organization_id,cohort_id,cohort_step_id,origin,enrollment_id,title,kind,position) VALUES ({U(425)},{U(100)},{U(401)},{U(411)},'ENROLLMENT',{U(510)},'X','TASK',4)", False)
expect("etape de cohorte d'une autre cohorte",
       f"INSERT INTO cohort_activity (id,organization_id,cohort_id,cohort_step_id,origin,title,kind,position) VALUES ({U(426)},{U(100)},{U(400)},{U(411)},'COHORT','X','TASK',9)", False)

print("\n-- Participations")
expect("deuxieme participation en cours pour le meme projet",
       f"INSERT INTO enrollment (id,organization_id,project_id,cohort_id,started_at) VALUES ({U(511)},{U(100)},{U(500)},{U(401)},NOW())", False)
expect("fin de participation sans issue",
       f"UPDATE enrollment SET ended_at=NOW(), ended_by_member_id={U(11)} WHERE id={U(510)}", False)
expect("promotion : fin COMPLETED puis nouvelle participation",
       f"UPDATE enrollment SET ended_at=NOW(), outcome='COMPLETED', ended_by_member_id={U(11)} WHERE id={U(510)}; "
       f"INSERT INTO enrollment (id,organization_id,project_id,cohort_id,started_at) VALUES ({U(512)},{U(100)},{U(500)},{U(401)},NOW()); "
       f"UPDATE enrollment SET promoted_to_enrollment_id={U(512)} WHERE id={U(510)}", True)
expect("promotion avec une issue autre que COMPLETED",
       f"UPDATE enrollment SET outcome='DROPPED' WHERE id={U(510)}", False)

print("\n-- Livrables")
expect("livrable sur une activite d'une autre cohorte que la participation",
       f"INSERT INTO deliverable (id,organization_id,cohort_id,enrollment_id,cohort_activity_id) VALUES ({U(601)},{U(100)},{U(400)},{U(510)},{U(421)})", False)
expect("deux livrables pour la meme participation et la meme activite",
       f"INSERT INTO deliverable (id,organization_id,cohort_id,enrollment_id,cohort_activity_id) VALUES ({U(602)},{U(100)},{U(400)},{U(510)},{U(420)})", False)
expect("brouillon texte",
       f"INSERT INTO deliverable_version (id,organization_id,deliverable_id,content_type,text_body) VALUES ({U(610)},{U(100)},{U(600)},'TEXT','brouillon')", True)
expect("second brouillon pour le meme livrable",
       f"INSERT INTO deliverable_version (id,organization_id,deliverable_id,content_type,text_body) VALUES ({U(611)},{U(100)},{U(600)},'TEXT','autre')", False)
expect("brouillon de type fichier",
       f"INSERT INTO deliverable_version (id,organization_id,deliverable_id,content_type) VALUES ({U(612)},{U(100)},{U(600)},'FILE')", False)
expect("version rendue sans auteur",
       f"INSERT INTO deliverable_version (id,organization_id,deliverable_id,number,submitted_at,content_type,link_url) VALUES ({U(613)},{U(100)},{U(600)},1,NOW(),'LINK','https://x.test')", False)
expect("version 1 rendue (lien)",
       f"INSERT INTO deliverable_version (id,organization_id,deliverable_id,number,submitted_at,submitted_by_member_id,content_type,link_url) VALUES ({U(614)},{U(100)},{U(600)},1,NOW(),{U(13)},'LINK','https://x.test')", True)
expect("deux versions numero 1",
       f"INSERT INTO deliverable_version (id,organization_id,deliverable_id,number,submitted_at,submitted_by_member_id,content_type,link_url) VALUES ({U(615)},{U(100)},{U(600)},1,NOW(),{U(13)},'LINK','https://y.test')", False)
expect("demande de correction sans commentaire",
       f"INSERT INTO deliverable_comment (id,organization_id,deliverable_id,author_member_id,kind) VALUES ({U(620)},{U(100)},{U(600)},{U(12)},'CHANGES_REQUESTED')", False)
expect("echeance de correction sur un simple commentaire",
       f"INSERT INTO deliverable_comment (id,organization_id,deliverable_id,author_member_id,kind,body,correction_due_date) VALUES ({U(621)},{U(100)},{U(600)},{U(12)},'COMMENT','ok','2026-03-01')", False)
expect("commentaire citant une version d'un autre livrable",
       f"INSERT INTO deliverable (id,organization_id,cohort_id,enrollment_id,cohort_activity_id) VALUES ({U(603)},{U(100)},{U(400)},{U(510)},{U(422)}); "
       f"INSERT INTO deliverable_comment (id,organization_id,deliverable_id,author_member_id,body,version_id) VALUES ({U(622)},{U(100)},{U(603)},{U(12)},'x',{U(614)})", False)

print("\n-- Invitations")
expect("invitation entrepreneur avec cohorte",
       f"INSERT INTO invitation (id,organization_id,email,role,cohort_id,token_hash,expires_at,invited_by_member_id) VALUES ({U(700)},{U(100)},'awa@x.test','PARTICIPANT',{U(401)},REPEAT('a',64),NOW()+INTERVAL 7 DAY,{U(11)})", True)
expect("deuxieme invitation en attente pour le meme email",
       f"INSERT INTO invitation (id,organization_id,email,role,token_hash,expires_at,invited_by_member_id) VALUES ({U(701)},{U(100)},'awa@x.test','FACILITATOR',REPEAT('b',64),NOW()+INTERVAL 7 DAY,{U(11)})", False)
expect("invitation coach rattachee a une cohorte",
       f"INSERT INTO invitation (id,organization_id,email,role,cohort_id,token_hash,expires_at,invited_by_member_id) VALUES ({U(702)},{U(100)},'c2@x.test','FACILITATOR',{U(401)},REPEAT('c',64),NOW()+INTERVAL 7 DAY,{U(11)})", False)
expect("email en majuscules",
       f"INSERT INTO invitation (id,organization_id,email,role,token_hash,expires_at,invited_by_member_id) VALUES ({U(703)},{U(100)},'Ab@x.test','FACILITATOR',REPEAT('d',64),NOW()+INTERVAL 7 DAY,{U(11)})", False)

print("\n-- Abonnement")
expect("deux plans par defaut",
       f"INSERT INTO plan (id,code,name,is_default) VALUES ({U(800)},'FREEMIUM','Freemium',TRUE),({U(801)},'PREMIUM','Premium',TRUE)", False)
expect("deux abonnements courants pour une structure",
       f"INSERT INTO plan (id,code,name,is_default) VALUES ({U(802)},'FREEMIUM','Freemium',TRUE); "
       f"INSERT INTO subscription (id,organization_id,plan_id,status,source) VALUES ({U(810)},{U(100)},{U(802)},'ACTIVE','DEFAULT'),({U(811)},{U(100)},{U(802)},'PENDING_PAYMENT','PAYMENT')", False)

print("\n%d / %d cas conformes" % (ok_count, ok_count + len(fail)))
sys.exit(1 if fail else 0)
