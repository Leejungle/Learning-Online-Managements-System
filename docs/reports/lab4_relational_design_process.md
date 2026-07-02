# Lab 4 — Relational Database Design Process

> **Course:** DBI202 — Database Systems
> **Lab:** 4 — Relational Database Design Process
> **Project:** Online Learning Management System (LMS)
> **Group:** [GROUP NAME]
> **Members:** [FULL NAME — STUDENT ID], [FULL NAME — STUDENT ID], [FULL NAME — STUDENT ID], [FULL NAME — STUDENT ID]
> **Class:** [CLASS CODE]
> **Date:** [SUBMISSION DATE]

---

## 1. Objective

This lab documents the complete design process of the LMS relational database: from requirements
and a conceptual Entity-Relationship (ER) model, through the logical relational schema (mapping
entities and relationships to tables), to the physical design (data types and indexes) and the
integrity constraints that enforce the business rules. All artifacts correspond to the implemented
schema in `sql/01_schema.sql`, the triggers in `sql/02_triggers.sql`, and the data dictionary in
`docs/Normalization_and_DataDictionary.md`.

---

## 2. Design Methodology

The team followed the classic top-down database design pipeline:

1. **Requirements analysis** — identify the data the LMS must store and the business rules it must
   guarantee.
2. **Conceptual design** — build an ER model (entities, attributes, relationships) independent of
   any DBMS. The full diagram is shown in §4 (Figure 1, `docs/erd.png`).
3. **Logical design** — map the ER model to relational tables using standard mapping rules, then
   normalize to 3NF (see Lab 3).
4. **Physical design** — choose SQL Server data types, primary-key storage (`IDENTITY`), and
   secondary indexes for the most frequent lookups and reports.
5. **Constraint design** — express integrity rules declaratively (PK/FK/UNIQUE/CHECK/DEFAULT) and,
   where a rule is beyond declarative reach, procedurally (triggers and stored procedures).

---

## 3. Requirements (Summary)

Functional data requirements:
- Manage **users** with exactly one role (Student, Instructor, Admin).
- Organise **courses** into **categories**; each course is owned by one instructor and structured
  into **modules** and **materials**.
- Let students **enrol** in courses (many-to-many) and track progress.
- Support **assignments / quizzes / exams**, **submissions**, automatic and manual **grading**.
- Support **discussion forums**, **recommendations**, **interaction logs**, and completion
  **certificates** (final score ≥ 80%).

Key business rules (later enforced by constraints/triggers):
- An account is unique by `Username` and by `Email`; a course is unique by `CourseCode`.
- A student enrols in a given course at most once.
- A course owner must have the `Instructor` role; only `Student` accounts can enrol.
- Every assignment has a mandatory deadline; a submission may be flagged late by policy.
- A submission receives at most one grade; a certificate is issued only at ≥ 80%.

---

## 4. Conceptual Design (ER Model)

The ER model contains **17 entities** and their relationships. The complete Entity-Relationship
Diagram is shown in Figure 1; a text-based overview of the relationship structure follows it.

![Entity-Relationship Diagram of the LMS database](../erd.png)

*Figure 1. Entity-Relationship Diagram of the LMS database (`docs/erd.png`).*

```
Categories  --< Courses >--  Users(Instructor)
Courses     --< Modules   --< Materials
Courses     --< Assignments --< Questions --< QuestionOptions
Users(Student) >--< Courses        ......... via Enrollments (junction)
Users(Student) >--< Courses        ......... via Certificates (junction, <=1 per pair)
Assignments --< Submissions >-- Users(Student)
Submissions --< StudentAnswers >-- Questions / QuestionOptions
Submissions --1 Grades            ......... 1:1 (UNIQUE SubmissionID)
Courses     --< ForumThreads --< ForumPosts --(ParentPostID, self)
Users       --< Recommendations >-- Courses
Users       --< InteractionLogs
```

| Relationship | Cardinality | Notes |
|---|---|---|
| Users (Instructor) — Courses | 1 : N | A course has exactly one owning instructor |
| Categories — Courses | 1 : N | A category classifies many courses |
| Courses — Modules | 1 : N | Cascade delete |
| Modules — Materials | 1 : N | Cascade delete |
| Users (Student) — Courses | **M : N** | Resolved by `Enrollments` |
| Courses — Assignments | 1 : N | Cascade delete |
| Assignments — Questions | 1 : N | Cascade delete |
| Questions — QuestionOptions | 1 : N | Cascade delete |
| Assignments — Submissions | 1 : N | |
| Users (Student) — Submissions | 1 : N | |
| Submissions — StudentAnswers | 1 : N | Cascade delete |
| Submissions — Grades | 1 : 1 | Enforced by `UNIQUE(SubmissionID)` |
| Courses — ForumThreads | 1 : N | Cascade delete |
| ForumThreads — ForumPosts | 1 : N | + self-reference `ParentPostID` for nested replies |
| Users — Recommendations / InteractionLogs | 1 : N | |
| Users (Student) — Courses (Certificates) | **M : N**, ≤ 1 per pair | Resolved by `Certificates`, `UNIQUE(StudentID, CourseID)` |

---

## 5. Logical Design (Mapping to the Relational Model)

The ER model maps to relations using standard rules:

1. **Each strong entity → one table** with a surrogate `IDENTITY` primary key
   (`Users`, `Courses`, `Categories`, `Modules`, `Materials`, `Assignments`, `Questions`,
   `QuestionOptions`, `Submissions`, `Grades`, `ForumThreads`, `ForumPosts`, `Recommendations`,
   `InteractionLogs`, `Certificates`).
2. **Each 1:N relationship → a foreign key** on the "many" side
   (e.g., `Modules.CourseID → Courses`, `Materials.ModuleID → Modules`,
   `Courses.InstructorID → Users`, `Courses.CategoryID → Categories`).
3. **Each M:N relationship → a junction table** carrying both foreign keys plus relationship
   attributes:
   - `Enrollments(StudentID, CourseID, EnrollDate, Status, ProgressPercent, CompletedAt)` with
     `UNIQUE(StudentID, CourseID)`.
   - `Certificates(StudentID, CourseID, FinalScore, IssuedAt, …)` with `UNIQUE(StudentID, CourseID)`.
4. **The 1:1 relationship** Submission–Grade is mapped by placing the foreign key on `Grades`
   and adding `UNIQUE(SubmissionID)` so a submission has at most one grade.
5. **The recursive relationship** (a forum post replies to another) maps to a self-referencing
   foreign key `ForumPosts.ParentPostID → ForumPosts(PostID)`.

The resulting relational schema (table → key columns) is:

| Table | PK | Foreign keys |
|---|---|---|
| `Users` | UserID | — |
| `Categories` | CategoryID | — |
| `Courses` | CourseID | InstructorID→Users, CategoryID→Categories |
| `Modules` | ModuleID | CourseID→Courses (CASCADE) |
| `Materials` | MaterialID | ModuleID→Modules (CASCADE) |
| `Enrollments` | EnrollmentID | StudentID→Users, CourseID→Courses |
| `Assignments` | AssignmentID | CourseID→Courses (CASCADE) |
| `Questions` | QuestionID | AssignmentID→Assignments (CASCADE) |
| `QuestionOptions` | OptionID | QuestionID→Questions (CASCADE) |
| `Submissions` | SubmissionID | AssignmentID→Assignments, StudentID→Users |
| `StudentAnswers` | AnswerID | SubmissionID→Submissions (CASCADE), QuestionID→Questions, SelectedOptionID→QuestionOptions |
| `Grades` | GradeID | SubmissionID→Submissions (CASCADE), GradedBy→Users |
| `ForumThreads` | ThreadID | CourseID→Courses (CASCADE), CreatedBy→Users |
| `ForumPosts` | PostID | ThreadID→ForumThreads (CASCADE), UserID→Users, ParentPostID→ForumPosts |
| `Recommendations` | RecommendationID | StudentID→Users, CourseID→Courses |
| `InteractionLogs` | LogID | UserID→Users |
| `Certificates` | CertificateID | StudentID→Users, CourseID→Courses |

A complete column-level data dictionary is provided in
`docs/Normalization_and_DataDictionary.md` (Part B).

---

## 6. Physical Design

### 6.1. Data types (representative choices)
- **Surrogate keys:** `INT IDENTITY(1,1)`; `InteractionLogs.LogID` uses `BIGINT IDENTITY` because
  logs grow fastest.
- **Text:** `VARCHAR` for ASCII codes/enumerations (`Username`, `CourseCode`, `Role`, `Status`),
  `NVARCHAR` for human-readable Unicode content (`FullName`, `Title`, `Description`).
- **Money / scores:** `DECIMAL(10,2)` for `Price`, `DECIMAL(5,2)` for scores/percentages,
  `DECIMAL(5,4)` for recommendation confidence (0..1).
- **Time:** `DATETIME2` with `DEFAULT SYSDATETIME()`.
- **Flags / identifiers:** `BIT` for `IsCorrect`/`IsLate`; `UNIQUEIDENTIFIER` for `SessionID`.
- **Computed column:** `Certificates.CertificateCode` is a non-stored computed column deriving a
  human-friendly serial (`'LMS-CERT-' + RIGHT('00000' + CAST(CertificateID AS VARCHAR(10)), 5)`).

### 6.2. Indexes
Beyond the clustered primary-key indexes, secondary indexes support frequent lookups and reports
(`sql/01_schema.sql`):

| Index | Table(column) | Purpose |
|---|---|---|
| `IX_Courses_Instructor` | `Courses(InstructorID)` | List courses by instructor |
| `IX_Enroll_Course` | `Enrollments(CourseID)` | Enrollment counts / rosters per course |
| `IX_Enroll_Student` | `Enrollments(StudentID)` | A student's enrolled courses |
| `IX_Sub_Student` | `Submissions(StudentID)` | A student's submissions |
| `IX_Sub_Assignment` | `Submissions(AssignmentID)` | Submissions per assignment (grading) |
| `IX_Log_User_Time` | `InteractionLogs(UserID, CreatedAt)` | Behaviour analytics by user over time |

---

## 7. Integrity-Constraint Design

### 7.1. Declarative constraints (in the schema)
- **Primary keys** — one per table (identity surrogate).
- **Foreign keys** — referential integrity for every relationship; `ON DELETE CASCADE` on
  ownership chains (`Modules`, `Materials`, `Assignments`, `Questions`, `QuestionOptions`,
  `StudentAnswers`, `Grades`, `ForumThreads`, `ForumPosts`).
- **UNIQUE** — natural keys and cardinality rules: `Username`, `Email`, `CourseCode`,
  `(CourseID, OrderIndex)`, `(StudentID, CourseID)`, `(AssignmentID, StudentID, Attempt)`,
  `(SubmissionID, QuestionID)`, `Grades.SubmissionID`, `Certificates(StudentID, CourseID)`.
- **CHECK** — domain rules: role and status enumerations, `Price ≥ 0`, `MaxScore > 0`,
  `ProgressPercent BETWEEN 0 AND 100`, recommendation `Score BETWEEN 0 AND 1`, certificate
  `FinalScore ≥ 80`, e-mail pattern, etc.
- **DEFAULT** — sensible defaults (`Status='Active'`, `CreatedAt=SYSDATETIME()`, `Attempt=1`, …).

### 7.2. Procedural constraints (triggers)
Some rules cannot be expressed declaratively and are enforced by triggers (`sql/02_triggers.sql`):

| Trigger | Rule enforced |
|---|---|
| `trg_Courses_InstructorRole` | A course's owner must have the `Instructor` role |
| `trg_Enroll_Validate` | Only `Student` accounts may enrol (and into valid courses) |
| `trg_Submissions_Policy` | Applies late / reject / penalty policy and sets `IsLate` |
| `trg_Modules_KeepAtLeastOne` | A course must keep at least one module |
| `trg_Courses_PublishNeedsModule` | A course can be `Published` only if it has a module |
| `trg_Grades_MarkGraded` | Marks the submission `Graded` and validates score ≤ MaxScore |
| `trg_StudentAnswers_OptionMatchesQuestion` | A chosen option must belong to its question |

### 7.3. Transactional business logic (stored procedures)
Multi-step operations are wrapped in stored procedures with transactions and error handling
(`sql/04_procedures.sql`): `sp_EnrollStudent`, `sp_SubmitAssignment`, `sp_GradeSubmission`,
`sp_AutoGradeQuiz`, `sp_RecommendCourses`, `sp_IssueCertificate`. These guarantee that complex
actions (e.g., auto-grading a quiz then optionally issuing a certificate) either fully succeed or
fully roll back.

---

## 8. Design Decisions and Trade-offs

- **Surrogate keys over natural keys.** Identity surrogates keep foreign keys narrow and stable
  even if a natural value (e.g., a username) later changes; natural keys are still protected with
  `UNIQUE`.
- **Cascade only on true ownership.** `ON DELETE CASCADE` is used where a child cannot exist
  without its parent (module→course, option→question). It is **not** used on `Enrollments`/
  `Submissions` toward `Users`, so deleting historical academic data is a deliberate action.
- **Snapshot vs. live progress.** `Enrollments.ProgressPercent` stores a snapshot updated on
  completion, while `fn_CourseProgress` computes live progress on demand — a documented redundancy
  for performance, not a normalization error.
- **Declarative first, procedural only when needed.** The team preferred `CHECK`/`UNIQUE`/`FK`
  for rules that fit them and reserved triggers for cross-row/cross-table rules.

---

## 9. Conclusion

The LMS database was designed through a disciplined process: requirements → ER conceptual model →
3NF logical relational schema → physical design (types, identity keys, indexes) → a layered
constraint design combining declarative constraints, triggers, and transactional stored
procedures. The mapping rules produced clean tables, junction tables resolved the two many-to-many
relationships (`Enrollments`, `Certificates`), and integrity is enforced as close to the data as
possible. The result is a maintainable, consistent schema that directly supports the SQL
programming demonstrated in Lab 5.

---

## Appendix — Repository Evidence Referenced

| Content | Evidence file |
|---|---|
| Tables, keys, data types, indexes, constraints | `sql/01_schema.sql` |
| Trigger-enforced business rules | `sql/02_triggers.sql` |
| Functions and views | `sql/03_functions_views.sql` |
| Transactional stored procedures | `sql/04_procedures.sql` |
| Column-level data dictionary | `docs/Normalization_and_DataDictionary.md` (Part B) |
| Entity-Relationship Diagram | `docs/erd.png` (Figure 1) |
