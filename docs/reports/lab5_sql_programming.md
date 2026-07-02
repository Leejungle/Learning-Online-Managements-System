# Lab 5 — SQL Queries, Views, Indexes, Functions, Procedures, and Triggers

> **Course:** DBI202 — Database Systems
> **Lab:** 5 — SQL Programming
> **Project:** Online Learning Management System (LMS)
> **Group:** [GROUP NAME]
> **Members:** [FULL NAME — STUDENT ID], [FULL NAME — STUDENT ID], [FULL NAME — STUDENT ID], [FULL NAME — STUDENT ID]
> **Class:** [CLASS CODE]
> **Date:** [SUBMISSION DATE]

---

## 1. Objective

This lab demonstrates SQL programming on the LMS database, from basic `SELECT` statements to
advanced queries (joins, grouping, subqueries, set operations), together with the database's
programmable objects: **views, indexes, user-defined functions, stored procedures, and triggers**.

To keep the report readable while still proving broad coverage of the schema, the team built a
single, **non-destructive query workbook** — `sql/10_lab5_query_workbook.sql` — that contains the
complete query set (68 tagged query groups, `[Q01]…[Q68]`). This report explains the query
**categories** and shows **representative examples with real execution results**; the full set is
referenced rather than pasted in full. The captured execution log is saved at
`docs/reports/lab5_execution_output.txt`.

> **Scope note (honest framing).** Rather than mechanically generating every query category for
> all 17 tables (which would make the report unreadable), the workbook covers **all 17 tables with
> at least one query each**, and concentrates the **advanced** query categories on the core LMS
> tables where they are meaningful. This is a deliberate *representative implementation*; the
> workbook provides broad coverage across the whole schema.

---

## 2. How to Run

```bat
sqlcmd -S localhost -E -C -d LMS -i sql\10_lab5_query_workbook.sql -o docs\reports\lab5_execution_output.txt -W
```

The workbook is **safe to run repeatedly**: every statement is `SELECT`-only except the stored-
procedure and trigger demonstrations, which run inside `BEGIN TRANSACTION … ROLLBACK` (or
`TRY/CATCH`) so the sample data is never permanently modified.

---

## 3. Query Categories with Representative Examples

### 3.1. Basic SELECT — all 17 tables (`[Q01]…[Q17]`)
Each table has at least one representative `SELECT` (with `TOP (n)` for readability). Example:

```sql
-- [Q17] Certificates
SELECT TOP (10) CertificateID, CertificateCode, StudentID, CourseID, FinalScore
FROM Certificates ORDER BY CertificateID;
```

### 3.2. WHERE / ORDER BY / DISTINCT (`[Q18]…[Q22]`)
```sql
-- [Q18] Published courses, most expensive first
SELECT CourseCode, Title, Price, Level
FROM Courses
WHERE Status = 'Published'
ORDER BY Price DESC, Title;
```

### 3.3. Aggregation & GROUP BY (`[Q23]…[Q27]`)
```sql
-- [Q24] Users per role
SELECT Role, COUNT(*) AS UserCount
FROM Users GROUP BY Role ORDER BY UserCount DESC;
```
**Result (live data):**
```
Role        UserCount
----------  ---------
Student     23
Instructor  15
Admin        1
```

### 3.4. JOIN queries (`[Q28]…[Q33]`)
Includes 3-table joins, joins through the `Enrollments` junction table, a parent–child join
(`Modules`→`Materials`), and a **self-join** on `ForumPosts` (a reply and the post it answers).
```sql
-- [Q32] Forum posts with author and the author they replied to (self-join)
SELECT t.Title AS Thread, au.FullName AS Author, pau.FullName AS ReplyingTo
FROM ForumPosts p
JOIN ForumThreads t ON t.ThreadID = p.ThreadID
JOIN Users au       ON au.UserID = p.UserID
LEFT JOIN ForumPosts parent ON parent.PostID = p.ParentPostID
LEFT JOIN Users pau ON pau.UserID = parent.UserID
ORDER BY t.Title, p.PostID;
```

### 3.5. GROUP BY … HAVING (`[Q34]…[Q36]`)
```sql
-- [Q34] Courses with more than 3 enrollments
SELECT c.Title, COUNT(e.EnrollmentID) AS Enrollments
FROM Courses c JOIN Enrollments e ON e.CourseID = c.CourseID
GROUP BY c.Title
HAVING COUNT(e.EnrollmentID) > 3
ORDER BY Enrollments DESC;
```

### 3.6. Subqueries — scalar / IN / derived table (`[Q37]…[Q39]`)
```sql
-- [Q37] Courses priced above the overall average
SELECT CourseCode, Title, Price
FROM Courses
WHERE Price > (SELECT AVG(Price) FROM Courses)
ORDER BY Price DESC;
```

### 3.7. Nested / correlated subqueries (`[Q40]…[Q42]`)
```sql
-- [Q41] Courses where NO assignment has been graded yet (nested NOT EXISTS)
SELECT c.CourseCode, c.Title
FROM Courses c
WHERE NOT EXISTS (
    SELECT 1 FROM Assignments a
    JOIN Submissions s ON s.AssignmentID = a.AssignmentID
    JOIN Grades g      ON g.SubmissionID = s.SubmissionID
    WHERE a.CourseID = c.CourseID
)
ORDER BY c.CourseCode;
```

### 3.8. EXISTS / IN / ANY / ALL (`[Q43]…[Q47]`)
```sql
-- [Q46] Courses at least as expensive as ALL beginner courses
SELECT CourseCode, Title, Price
FROM Courses
WHERE Price >= ALL (SELECT Price FROM Courses WHERE Level = 'Beginner')
ORDER BY Price DESC;
```

### 3.9. Set operations — UNION / INTERSECT / EXCEPT (`[Q48]…[Q50]`)
```sql
-- [Q49] Students who are BOTH enrolled and certified
SELECT StudentID FROM Enrollments
INTERSECT
SELECT StudentID FROM Certificates
ORDER BY StudentID;

-- [Q50] Students enrolled but with NO submission yet
SELECT StudentID FROM Enrollments
EXCEPT
SELECT StudentID FROM Submissions
ORDER BY StudentID;
```

### 3.10. Reports / statistics (`[Q51]…[Q54]`)
Representative business reports (completion rate, on-time vs late, recommendation conversion,
daily usage). The full set of six required reports lives in `sql/06_reports.sql`.

---

## 4. Programmable Objects

### 4.1. Views (≥ 2) — defined in `sql/03_functions_views.sql`
| View | Purpose |
|---|---|
| `vw_CourseCatalog` | Course catalog with instructor name, enrolled-student count, module count |
| `vw_Gradebook` | One row per submission with grade info (`LEFT JOIN Grades`, so ungraded rows still appear) |

Demonstrated by `[Q55]`, `[Q56]`:
```sql
-- [Q55]
SELECT TOP (10) CourseCode, Title, InstructorName, EnrolledStudents, ModuleCount
FROM vw_CourseCatalog ORDER BY EnrolledStudents DESC;
```

### 4.2. User-defined functions (≥ 4) — `sql/03_functions_views.sql`
| Function | Type | Purpose |
|---|---|---|
| `fn_CanAccessCourse(@StudentID,@CourseID)` | scalar `BIT` | Is the student enrolled (Active/Completed)? |
| `fn_CourseProgress(@StudentID,@CourseID)` | scalar `DECIMAL` | % of graded assignments completed |
| `fn_CourseFinalGrade(@StudentID,@CourseID)` | scalar `DECIMAL` | Coursera-style final grade (0..100) |
| `fn_HasPassedCourse(@StudentID,@CourseID)` | scalar `BIT` | Final grade ≥ 80%? |
| `fn_AccessibleMaterials(@StudentID)` | **table-valued** | Materials the student is allowed to see |

Demonstrated by `[Q57]…[Q61]` on a dynamically chosen enrolled pair. **Result (live data):**
```
StudentID CourseID CanAccess ProgressPct FinalGrade HasPassed
--------- -------- --------- ----------- ---------- ---------
5         1        1         50.00       42.50      0
```
This shows all five functions returning consistent values (the learner can access the course, has
completed 50% of graded work, has a 42.50% final grade, and therefore has not yet passed).

### 4.3. Indexes (≥ 2) — `sql/01_schema.sql`
Six secondary indexes support frequent lookups/reports. `[Q62]` lists them from the catalog views.
**Result (live data, excerpt):**
```
TableName        IndexName               IndexType     IsUnique
---------------  ----------------------  ------------  --------
Courses          IX_Courses_Instructor   NONCLUSTERED  0
Enrollments      IX_Enroll_Course        NONCLUSTERED  0
Enrollments      IX_Enroll_Student       NONCLUSTERED  0
InteractionLogs  IX_Log_User_Time        NONCLUSTERED  0
Submissions      IX_Sub_Assignment       NONCLUSTERED  0
Submissions      IX_Sub_Student          NONCLUSTERED  0
```

### 4.4. Stored procedures (≥ 4) — `sql/04_procedures.sql`
| Procedure | Purpose |
|---|---|
| `sp_EnrollStudent` | Enroll a student; mark a matching recommendation as Enrolled |
| `sp_SubmitAssignment` | Create a submission (attempt auto-incremented; late logic via trigger) |
| `sp_GradeSubmission` | Record/replace a manual grade |
| `sp_AutoGradeQuiz` | Auto-grade an objective quiz/exam against the answer key |
| `sp_RecommendCourses` | Content-based recommendations by studied categories |
| `sp_IssueCertificate` | Issue a certificate only if final grade ≥ 80%; complete the enrollment |

Demonstrated **non-destructively** by `[Q63]…[Q66]` inside `BEGIN TRANSACTION … ROLLBACK`.
Execution confirmed each one ran and was rolled back, e.g.:
```
--- [Q63] sp_RecommendCourses (writes Recommendations; rolled back) ---
RecommendationID CourseID Title             Score  Reason
35               13       Ethics in IT      .9375  Similar to categories you study
...
OK: sp_RecommendCourses demonstrated and rolled back.
```

### 4.5. Triggers (≥ 4) — `sql/02_triggers.sql`
| Trigger | Rule enforced |
|---|---|
| `trg_Courses_InstructorRole` | A course owner must have role Instructor |
| `trg_Enroll_Validate` | Only Students enroll, and only in Published courses |
| `trg_Submissions_Policy` | Enrollment check + late flag + reject-late policy |
| `trg_Modules_KeepAtLeastOne` | A published course keeps ≥ 1 module |
| `trg_Courses_PublishNeedsModule` | A course can be Published only with ≥ 1 module |
| `trg_Grades_MarkGraded` | Grader must be Instructor/Admin; score ≤ MaxScore; mark Graded |
| `trg_StudentAnswers_OptionMatchesQuestion` | A chosen option must belong to its question |

Demonstrated by `[Q67]` (attempting an invalid enrollment, which the trigger blocks) and `[Q68]`
(non-destructive integrity check). **Result (live data):**
```
--- [Q67] ... a non-Student cannot enroll (expected to fail) ---
OK (rule enforced): Business rule violated: only users with role Student can enroll.

--- [Q68] trg_StudentAnswers_OptionMatchesQuestion (effect via SELECT) ---
MismatchedAnswers
-----------------
0
```
The complete negative-test suite is in `sql/07_business_rule_tests.sql`, with safe positive tests
in `sql/09_positive_smoke_tests.sql`.

---

## 5. Lab 5 Query Coverage Matrix

| Requirement category | Query IDs | Key tables involved | Short purpose | SELECT-only / non-destructive |
|---|---|---|---|---|
| Basic SELECT (all 17 tables) | Q01–Q17 | All 17 tables | At least one query per table | SELECT-only |
| WHERE / ORDER BY / DISTINCT | Q18–Q22 | Courses, Users, Materials, Assignments, Submissions | Filtering & sorting | SELECT-only |
| Aggregation / GROUP BY | Q23–Q27 | All (counts), Users, Courses, Assignments, Grades | COUNT/SUM/AVG/MIN/MAX | SELECT-only |
| JOIN (inner/left/self) | Q28–Q33 | Courses, Users, Categories, Enrollments, Modules, Materials, ForumPosts, StudentAnswers | Multi-table & self joins | SELECT-only |
| GROUP BY … HAVING | Q34–Q36 | Courses, Enrollments, Users, Grades | Aggregate filtering | SELECT-only |
| Subqueries (scalar/IN/derived) | Q37–Q39 | Courses, Enrollments, Categories | Subquery forms | SELECT-only |
| Nested / correlated subqueries | Q40–Q42 | Users, Submissions, Grades, Courses, Categories, Enrollments | Correlated logic | SELECT-only |
| EXISTS / IN / ANY / ALL | Q43–Q47 | Users, Certificates, Courses, InteractionLogs | Existence/quantified predicates | SELECT-only |
| UNION / INTERSECT / EXCEPT | Q48–Q50 | Users, Enrollments, Certificates, Submissions | Set operations | SELECT-only |
| Reports / statistics | Q51–Q54 | Courses, Enrollments, Assignments, Submissions, Recommendations, InteractionLogs | Business reporting | SELECT-only |
| Views (≥ 2) | Q55–Q56 | `vw_CourseCatalog`, `vw_Gradebook` | Read views | SELECT-only |
| Functions (≥ 4) | Q57–Q61 | Enrollments, Materials (+5 functions) | Scalar & table-valued UDFs | SELECT-only |
| Indexes (≥ 2) | Q62 | sys.indexes over LMS tables | List secondary indexes | SELECT-only |
| Stored procedures (≥ 4) | Q63–Q66 | Recommendations, Enrollments, Submissions, Grades, Certificates | Procedure demos | **TRAN + ROLLBACK** |
| Triggers (≥ 4) | Q67–Q68 | Enrollments, StudentAnswers | Rule-enforcement demos | **TRY/CATCH; no committed change** |

---

## 6. Rubric Satisfaction Summary

| Lab 5 requirement | Required | Provided | Where |
|---|---|---|---|
| SQL queries basic → advanced | yes | Q01–Q54 (54 query groups) | `sql/10_lab5_query_workbook.sql` |
| Functions | ≥ 4 | **5** | `fn_CanAccessCourse`, `fn_CourseProgress`, `fn_CourseFinalGrade`, `fn_HasPassedCourse`, `fn_AccessibleMaterials` |
| Stored procedures | ≥ 4 | **6** | `sp_EnrollStudent`, `sp_SubmitAssignment`, `sp_GradeSubmission`, `sp_AutoGradeQuiz`, `sp_RecommendCourses`, `sp_IssueCertificate` |
| Triggers | ≥ 4 | **7** | see §4.5 |
| Views | ≥ 2 | **2** | `vw_CourseCatalog`, `vw_Gradebook` |
| Indexes | ≥ 2 | **6** | see §4.3 |
| Explanations + execution results | yes | this report + `docs/reports/lab5_execution_output.txt` | — |

All minimum counts are met or exceeded.

---

## 7. Relationship to the Web Application (light reference)

The same SQL objects power a small Flask demo web application (`webapp/`) used only to visualise
the database in action — for example, the course catalog reads `vw_CourseCatalog`, enrollment uses
`sp_EnrollStudent`, recommendations use `sp_RecommendCourses`, and reports run the queries from
`sql/06_reports.sql`. The web layer adds no business logic of its own; all rules live in the
database. A full description of the web application is provided in the project's **Final Report**.

---

## 8. Conclusion

The Lab 5 workbook demonstrates SQL programming across the full difficulty range and exercises
every programmable object in the LMS database. All 68 query groups execute successfully against the
live database; the data-modifying demonstrations are transaction-wrapped and rolled back, and the
integrity check (`[Q68]`) confirms zero violations. The design satisfies — and in most categories
exceeds — the Lab 5 minimums for functions, procedures, triggers, views, and indexes, while keeping
the report readable by showing representative examples and referencing the complete query set in
`sql/10_lab5_query_workbook.sql`.

---

## Appendix — Repository Evidence Referenced

| Content | Evidence file |
|---|---|
| Complete non-destructive query workbook (Q01–Q68) | `sql/10_lab5_query_workbook.sql` |
| Captured execution log (live results) | `docs/reports/lab5_execution_output.txt` |
| Functions & views source | `sql/03_functions_views.sql` |
| Stored procedures source | `sql/04_procedures.sql` |
| Triggers source | `sql/02_triggers.sql` |
| Required analytical reports | `sql/06_reports.sql` |
| Negative business-rule tests | `sql/07_business_rule_tests.sql` |
| Positive smoke tests | `sql/09_positive_smoke_tests.sql` |
| Schema (tables, keys, indexes) | `sql/01_schema.sql` |
