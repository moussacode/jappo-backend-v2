"""Jeu de donnees de charge et mesure des requetes calculees (etape 3).

Usage : python charge.py <utilisateur> <base>   (mot de passe dans MYSQL_PWD)
La base doit contenir le schema v1 vide. Le script :
  1. genere 1 structure (10 programmes, 30 cohortes, 500 projets, ~5 000 livrables)
     plus une structure "bruit" plus petite, pour verifier le filtrage ;
  2. mesure les requetes du tableau de bord d'un programme et de l'ecran Projets
     (mediane de 7 executions, apres 2 executions de chauffe).
Les requetes mesurees sont celles de docs/modele-donnees.md, section 12.
"""
import datetime as dt
import os
import random
import secrets
import statistics
import sys
import time

import pymysql

random.seed(360)
TODAY = dt.date(2026, 11, 20)
NOW = dt.datetime(2026, 11, 20, 10, 0, 0)


def uuid7(ts=None):
    ms = int((ts or time.time()) * 1000)
    b = bytearray(ms.to_bytes(6, "big") + secrets.token_bytes(10))
    b[6] = (b[6] & 0x0F) | 0x70
    b[8] = (b[8] & 0x3F) | 0x80
    return bytes(b)


conn = pymysql.connect(host="127.0.0.1", port=3307, user=sys.argv[1], password=os.environ["MYSQL_PWD"],
                       database=sys.argv[2], autocommit=False)
cur = conn.cursor()


def ins(table, cols, rows):
    if not rows:
        return
    sql = "INSERT INTO %s (%s) VALUES (%s)" % (table, ",".join(cols), ",".join(["%s"] * len(cols)))
    for i in range(0, len(rows), 2000):
        cur.executemany(sql, rows[i:i + 2000])


def build(org_name, n_programs, n_cohorts, n_projects):
    org = uuid7()
    ins("organization", ["id", "name", "slug"], [(org, org_name, org_name.lower().replace(" ", "-"))])
    users, members = [], []

    def member(role, k):
        u, m = uuid7(), uuid7()
        users.append((u, "%s-%s-%d@%s.test" % (org_name[:4].lower(), role.lower(), k, "x"), "x", "P", str(k)))
        members.append((m, org, u, role, NOW))
        return m

    admin = member("ADMIN", 0)
    coaches = [member("FACILITATOR", k) for k in range(15)]
    participants = [member("PARTICIPANT", k) for k in range(n_projects + 100)]
    ins("user_account", ["id", "email", "password_hash", "first_name", "last_name"], users)
    ins("member", ["id", "organization_id", "user_id", "role", "joined_at"], members)

    programs, steps, acts = [], [], []
    prog_struct = []
    for p in range(n_programs):
        pid = uuid7()
        programs.append((pid, org, "Programme %d" % p))
        ps = []
        for s in range(4):
            sid = uuid7()
            steps.append((sid, org, pid, "Etape %d" % s, s))
            sa = []
            for a in range(3):
                aid = uuid7()
                fmt = None if (a == 2 and s % 2 == 0) else random.choice(["FILE", "LINK", "TEXT"])
                acts.append((aid, org, sid, "Activite %d.%d" % (s, a), "TASK", 1, 7 + s * 20 + a * 5, fmt, a))
                sa.append((aid, fmt, 7 + s * 20 + a * 5))
            ps.append((sid, s, sa))
        prog_struct.append((pid, ps))
    ins("program", ["id", "organization_id", "title"], programs)
    ins("step", ["id", "organization_id", "program_id", "title", "position"], steps)
    ins("activity", ["id", "organization_id", "step_id", "title", "kind", "required", "due_offset_days",
                     "deliverable_format", "position"], acts)

    cohorts, csteps, cacts, facil = [], [], [], []
    cohort_struct = []
    for c in range(n_cohorts):
        pid, ps = prog_struct[c % n_programs]
        cid = uuid7()
        kind = c // n_programs  # 0 terminee, 1 en cours, 2 en cours recente
        start = TODAY - dt.timedelta(days=[400, 120, 30][min(kind, 2)])
        closed = NOW if kind == 0 else None
        cohorts.append((cid, org, pid, "Cohorte %d" % c, start, start + dt.timedelta(days=180), closed,
                        admin if closed else None))
        for f in random.sample(coaches, 2):
            facil.append((org, cid, f))
        cs_list = []
        for sid, spos, sa in ps:
            csid = uuid7()
            csteps.append((csid, org, cid, sid, "Etape", spos))
            ca_list = []
            for aid, fmt, off in sa:
                caid = uuid7()
                cacts.append((caid, org, cid, csid, "PROGRAM", aid, "Activite", "TASK", 1, off, fmt, len(ca_list)))
                ca_list.append((caid, fmt, off))
            cs_list.append((csid, spos, ca_list))
        cohort_struct.append((cid, start, closed, cs_list))
    ins("cohort", ["id", "organization_id", "program_id", "name", "start_date", "planned_end_date", "closed_at",
                   "closed_by_member_id"], cohorts)
    ins("cohort_facilitator", ["organization_id", "cohort_id", "member_id"], facil)
    ins("cohort_step", ["id", "organization_id", "cohort_id", "source_step_id", "title", "position"], csteps)
    ins("cohort_activity", ["id", "organization_id", "cohort_id", "cohort_step_id", "origin", "source_activity_id",
                            "title", "kind", "required", "due_offset_days", "deliverable_format", "position"], cacts)

    projects, holders, enrolls, delivs, versions, comments, comps = [], [], [], [], [], [], []
    open_cohorts = [c for c in cohort_struct if c[2] is None]
    closed_cohorts = [c for c in cohort_struct if c[2] is not None]

    def simulate(eid, cohort, ended):
        cid, start, closed, cs_list = cohort
        flat = [(spos, ca) for _, spos, cal in cs_list for ca in cal]
        n_done = len(flat) if ended else random.randint(0, len(flat) - 1)
        for i, (spos, (caid, fmt, off)) in enumerate(flat):
            due = start + dt.timedelta(days=off)
            done_at = dt.datetime.combine(min(due, TODAY), dt.time(12)) - dt.timedelta(days=random.randint(0, 5))
            if fmt is None:
                if i < n_done:
                    comps.append((org, cid, eid, caid, participants[0], done_at))
                continue
            if i < n_done:
                status = "APPROVED"
            elif i == n_done:
                status = random.choice(["TO_SUBMIT", "SUBMITTED", "SUBMITTED", "CHANGES_REQUESTED"])
            else:
                if random.random() < 0.6:
                    status = "TO_SUBMIT"
                else:
                    continue
            did = uuid7()
            delivs.append((did, org, cid, eid, caid, status))
            if status == "TO_SUBMIT":
                continue
            nv = 1 if status != "CHANGES_REQUESTED" else random.randint(1, 2)
            for v in range(1, nv + 1):
                versions.append((uuid7(), org, did, v, done_at - dt.timedelta(days=3 * (nv - v) + 2), participants[0],
                                 "LINK", "https://exemple.test/%d" % v))
            if status == "APPROVED":
                comments.append((uuid7(), org, did, coaches[0], "APPROVED", None, None, done_at))
            elif status == "CHANGES_REQUESTED":
                comments.append((uuid7(), org, did, coaches[0], "CHANGES_REQUESTED", "A reprendre",
                                 TODAY + dt.timedelta(days=random.randint(-10, 10)), done_at))

    for k in range(n_projects):
        prj = uuid7()
        projects.append((prj, org, "Projet %03d" % k, random.choice(["Agri", "Sante", "Edtech", "Fintech"])))
        holders.append((org, prj, participants[k]))
        if k % 5 == 0 and closed_cohorts:  # passage termine puis promotion
            old = random.choice(closed_cohorts)
            e_old = uuid7()
            simulate(e_old, old, True)
            enrolls.append([e_old, org, prj, old[0], dt.datetime.combine(old[1], dt.time(9)), NOW, "COMPLETED", admin, None])
            new = random.choice(open_cohorts)
            e_new = uuid7()
            enrolls[-1][8] = e_new
            simulate(e_new, new, False)
            enrolls.append([e_new, org, prj, new[0], dt.datetime.combine(new[1], dt.time(9)), None, None, None, None])
        else:
            c = random.choice(open_cohorts)
            e = uuid7()
            ended = random.random() < 0.05
            simulate(e, c, False)
            enrolls.append([e, org, prj, c[0], dt.datetime.combine(c[1], dt.time(9)),
                            NOW if ended else None, random.choice(["ON_HOLD", "DROPPED"]) if ended else None,
                            admin if ended else None, None])
    ins("project", ["id", "organization_id", "name", "sector"], projects)
    ins("project_holder", ["organization_id", "project_id", "member_id"], holders)
    promos = [(r[8], r[0]) for r in enrolls if r[8]]
    for r in enrolls:
        r[8] = None
    ins("enrollment", ["id", "organization_id", "project_id", "cohort_id", "started_at", "ended_at", "outcome",
                       "ended_by_member_id", "promoted_to_enrollment_id"], [tuple(r) for r in enrolls])
    cur.executemany("UPDATE enrollment SET promoted_to_enrollment_id=%s WHERE id=%s", promos)
    ins("deliverable", ["id", "organization_id", "cohort_id", "enrollment_id", "cohort_activity_id", "status"], delivs)
    ins("deliverable_version", ["id", "organization_id", "deliverable_id", "number", "submitted_at",
                                "submitted_by_member_id", "content_type", "link_url"], versions)
    ins("deliverable_comment", ["id", "organization_id", "deliverable_id", "author_member_id", "kind", "body",
                                "correction_due_date", "created_at"], comments)
    ins("activity_completion", ["organization_id", "cohort_id", "enrollment_id", "cohort_activity_id",
                                "completed_by_member_id", "completed_at"], comps)
    conn.commit()
    return org, prog_struct[0][0], dict(projects=len(projects), enrollments=len(enrolls), deliverables=len(delivs),
                                        versions=len(versions), comments=len(comments), completions=len(comps),
                                        cohort_activities=len(cacts))


# ------------------------------------------------------------------ requetes mesurees
# Etat de chaque (participation, activite) : faite ?, quand ?, echeance, statut du livrable.
STATE = """
WITH e AS (
    SELECT en.id, en.cohort_id, en.project_id, en.started_at, en.ended_at, en.outcome, c.start_date, c.program_id
    FROM enrollment en JOIN cohort c ON c.id = en.cohort_id
    WHERE en.organization_id = %(org)s AND {scope}
),
ea AS (
    SELECT e.id AS eid, ca.id AS aid, ca.required, cs.position AS spos, cs.id AS csid,
           ca.deliverable_format IS NOT NULL AS has_deliverable, d.status,
           CASE WHEN ca.deliverable_format IS NULL THEN ac.completed_at
                WHEN d.status = 'APPROVED' THEN (SELECT MAX(x.created_at) FROM deliverable_comment x
                                                 WHERE x.deliverable_id = d.id AND x.kind = 'APPROVED') END AS done_at,
           COALESCE(
               CASE WHEN d.status = 'CHANGES_REQUESTED' THEN (SELECT x.correction_due_date FROM deliverable_comment x
                     WHERE x.deliverable_id = d.id AND x.kind = 'CHANGES_REQUESTED' ORDER BY x.created_at DESC LIMIT 1) END,
               ca.due_date_override,
               DATE_ADD(e.start_date, INTERVAL ca.due_offset_days DAY)) AS due_date,
           CASE WHEN d.status = 'SUBMITTED' THEN (SELECT MAX(v.submitted_at) FROM deliverable_version v
                                                  WHERE v.deliverable_id = d.id) END AS submitted_at
    FROM e
    JOIN cohort_activity ca ON ca.cohort_id = e.cohort_id AND ca.deleted_at IS NULL
                           AND (ca.enrollment_id IS NULL OR ca.enrollment_id = e.id)
    JOIN cohort_step cs ON cs.id = ca.cohort_step_id
    LEFT JOIN deliverable d ON d.enrollment_id = e.id AND d.cohort_activity_id = ca.id
    LEFT JOIN activity_completion ac ON ac.enrollment_id = e.id AND ac.cohort_activity_id = ca.id
),
agg AS (
    SELECT eid,
           SUM(required) AS req_total,
           SUM(required AND done_at IS NOT NULL) AS req_done,
           MIN(CASE WHEN required AND done_at IS NULL THEN spos END) AS cur_pos,
           SUM(done_at IS NULL AND due_date < %(today)s
               AND (has_deliverable = 0 OR status IS NULL OR status IN ('TO_SUBMIT','CHANGES_REQUESTED'))) AS late,
           SUM(status = 'SUBMITTED') AS pending,
           MIN(submitted_at) AS oldest_pending
    FROM ea GROUP BY eid
),
st AS (
    SELECT e.*, agg.req_total, agg.req_done, agg.cur_pos, agg.late, agg.pending, agg.oldest_pending,
           ROUND(100 * agg.req_done / NULLIF(agg.req_total, 0)) AS progress,
           COALESCE((SELECT MAX(ea.done_at) FROM ea WHERE ea.eid = e.id AND ea.required AND ea.spos < agg.cur_pos),
                    e.started_at) AS step_entered_at
    FROM e JOIN agg ON agg.eid = e.id
)
"""

Q_COHORTS = STATE.format(scope="c.program_id = %(prog)s") + """
SELECT c.id, c.name, c.start_date, c.planned_end_date, c.closed_at,
       COUNT(st.id) AS projects,
       ROUND(AVG(CASE WHEN st.ended_at IS NULL THEN st.progress END)) AS avg_progress,
       (SELECT GROUP_CONCAT(HEX(f.member_id)) FROM cohort_facilitator f WHERE f.cohort_id = c.id) AS coaches
FROM cohort c LEFT JOIN st ON st.cohort_id = c.id
WHERE c.organization_id = %(org)s AND c.program_id = %(prog)s
GROUP BY c.id ORDER BY c.start_date DESC
"""

Q_ALERTS = STATE.format(scope="c.program_id = %(prog)s AND en.ended_at IS NULL AND c.start_date <= %(today)s") + """
SELECT
  (SELECT COUNT(*) FROM ea JOIN e ON e.id = ea.eid WHERE ea.done_at IS NULL AND ea.due_date < %(today)s
       AND (ea.has_deliverable = 0 OR ea.status IS NULL OR ea.status IN ('TO_SUBMIT','CHANGES_REQUESTED'))) AS late,
  (SELECT COUNT(*) FROM st WHERE st.cur_pos IS NOT NULL
       AND DATEDIFF(%(today)s, st.step_entered_at) > %(stalled)s) AS stalled,
  (SELECT COUNT(*) FROM ea WHERE ea.status = 'SUBMITTED') AS pending,
  (SELECT COUNT(*) FROM ea WHERE ea.status = 'SUBMITTED'
       AND DATEDIFF(%(today)s, ea.submitted_at) > %(review)s) AS pending_overdue
"""

Q_DISTRIBUTION = STATE.format(scope="c.program_id = %(prog)s AND en.ended_at IS NULL") + """
SELECT COALESCE(st.cur_pos, -1) AS step_position, COUNT(*) AS projects
FROM st GROUP BY COALESCE(st.cur_pos, -1) ORDER BY step_position
"""

LATEST = "en.id = (SELECT x.id FROM enrollment x WHERE x.project_id = en.project_id ORDER BY x.started_at DESC LIMIT 1)"

Q_PROJECTS = STATE.format(scope=LATEST) + """
SELECT p.name, st.progress, st.cur_pos, st.late, st.pending, COUNT(*) OVER () AS total_rows,
       CASE WHEN st.ended_at IS NULL THEN 'EN_COURS' ELSE st.outcome END AS status,
       CASE WHEN st.ended_at IS NULL AND st.cur_pos IS NOT NULL
            THEN DATEDIFF(%(today)s, st.step_entered_at) END AS days_in_step,
       (SELECT GROUP_CONCAT(u.last_name) FROM project_holder h JOIN member m ON m.id = h.member_id
            JOIN user_account u ON u.id = m.user_id WHERE h.project_id = p.id) AS holders
FROM st JOIN project p ON p.id = st.project_id
{where}
ORDER BY {order} LIMIT 50 OFFSET %(offset)s
"""

Q_PROJECTS_COUNT = STATE.format(scope=LATEST) + "SELECT COUNT(*) FROM st {where}"


def measure(label, sql, params, runs=7):
    for _ in range(2):
        cur.execute(sql, params)
        cur.fetchall()
    times = []
    rows = 0
    for _ in range(runs):
        t = time.perf_counter()
        cur.execute(sql, params)
        rows = len(cur.fetchall())
        times.append((time.perf_counter() - t) * 1000)
    med = statistics.median(times)
    print("  %-52s %7.1f ms  (max %6.1f)  %4d ligne(s)  %s" % (label, med, max(times), rows,
                                                                "OK" if med < 300 else "TROP LENT"))
    return med


org, prog, counts = build("Fabrique 360", 10, 30, 500)
_noise = build("Structure bruit", 3, 6, 120)
cur.execute("ANALYZE TABLE enrollment, cohort, cohort_activity, cohort_step, deliverable, deliverable_version, "
            "deliverable_comment, activity_completion, project, project_holder, member, user_account")
cur.fetchall()
print("Volumes (structure mesuree) :", counts)

P = dict(org=org, prog=prog, today=TODAY, stalled=21, review=5, offset=0)
print("\nTableau de bord d'un programme :")
r = [measure("cohortes (projets, progression moyenne, coachs)", Q_COHORTS, P),
     measure("alertes (retards, bloques, retours en attente)", Q_ALERTS, P),
     measure("repartition des projets par etape", Q_DISTRIBUTION, P)]
print("  %-52s %7.1f ms" % ("total du tableau de bord", sum(r)))

print("\nEcran Projets (500 projets, page de 50) :")
measure("tri par nom, page 1", Q_PROJECTS.format(where="", order="p.name"), P)
measure("tri par progression, page 5", Q_PROJECTS.format(where="", order="st.progress DESC, p.name"), dict(P, offset=200))
measure("filtre en retard, tri par retards", Q_PROJECTS.format(where="WHERE st.late > 0", order="st.late DESC"), P)
measure("filtre bloques", Q_PROJECTS.format(
    where="WHERE st.ended_at IS NULL AND st.cur_pos IS NOT NULL AND DATEDIFF(%(today)s, st.step_entered_at) > %(stalled)s",
    order="st.step_entered_at"), P)
measure("(ancien) total dans une requete separee", Q_PROJECTS_COUNT.format(where=""), P)

cur.execute(Q_PROJECTS_COUNT.format(where="") .replace("%(org)s", "%(org2)s"), dict(P, org2=_noise[0]))
print("\nFiltrage : la structure bruit voit %d projet(s) (attendu 120)." % cur.fetchone()[0])
conn.close()
