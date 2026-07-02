# Lab 3 — Anomaly Detection and Normalization

> **Course:** DBI202 — Database Systems
> **Lab:** 3 — Anomaly Detection and Normalization
> **Project:** Online Learning Management System (LMS)
> **Group:** [GROUP NAME]
> **Members:** [FULL NAME — STUDENT ID], [FULL NAME — STUDENT ID], [FULL NAME — STUDENT ID], [FULL NAME — STUDENT ID]
> **Class:** [CLASS CODE]
> **Date:** [SUBMISSION DATE]

---

## 1. Objective

This lab demonstrates why an unnormalized design is problematic and how normalization removes
those problems. Starting from a single flat table that records everything about enrollments and
grades, we (1) identify the **insertion, update, and deletion anomalies** it causes, then
(2) normalize the design step by step to **1NF → 2NF → 3NF**, and (3) explain why the resulting
LMS schema (`sql/01_schema.sql`) is free of those anomalies. The discussion follows the
normalization analysis already documented in `docs/Normalization_and_DataDictionary.md` (Part A)
and is verified against the implemented schema.

---

## 2. Starting Point — An Unnormalized Table (UNF)

Assume the institution initially keeps everything in one spreadsheet-like table that mirrors a
class register:

```
EnrollmentSheet (
    StudentID, StudentName, StudentEmail,
    CourseCode, CourseTitle, InstructorName, CategoryName,
    ModuleTitles,                         -- "M1; M2; M3"  (several values in one cell)
    AssignmentTitle, Deadline,
    Score, Feedback, GradedByName
)
```

Sample rows (illustrative):

| StudentID | StudentName | CourseCode | CourseTitle | InstructorName | ModuleTitles | AssignmentTitle | Score |
|---|---|---|---|---|---|---|---|
| 5 | An Nguyen | WEB101 | Intro Web | Mr. Pham | M1; M2; M3 | Lab 1 | 9.0 |
| 5 | An Nguyen | WEB101 | Intro Web | Mr. Pham | M1; M2; M3 | Lab 2 | 8.0 |
| 7 | Binh Tran | PY200 | Python Data | Ms. Le | M1; M2 | Quiz 1 | 7.5 |

This single table mixes student data, course data, instructor data, module data, and grade data,
and it stores several module titles inside one cell. That combination is the source of the
anomalies analysed next.

---

## 3. Anomaly Analysis

### 3.1. Insertion anomalies
- **Cannot add a new course before any student enrols.** Because course facts (`CourseCode`,
  `CourseTitle`, `InstructorName`) live in the same row as a student's grade, inserting a course
  with no enrolled students forces NULLs for `StudentID`, `Score`, etc. — the course cannot exist
  independently.
- **Cannot register a new student who has not enrolled in any course yet** for the same reason.
- **Cannot define a module** unless it is attached to some student's grade row.

### 3.2. Update anomalies
- If an instructor's name changes (e.g., *Mr. Pham* → *Mr. Pham Van A*), the value is **repeated
  on every enrollment/grade row** of every course he teaches. Updating one row but missing another
  leaves the data **inconsistent**.
- Renaming a course title (`Intro Web`) must be applied to **all** rows of that course; a partial
  update corrupts the data.

### 3.3. Deletion anomalies
- If *Binh Tran* (StudentID 7) is the **only** student enrolled in `PY200` and we delete his row,
  we also **lose all information about the course `PY200`** and its instructor *Ms. Le* — facts we
  wanted to keep.
- Deleting the last grade row of a course erases the course definition itself.

### 3.4. Redundancy / multi-valued problem
- `ModuleTitles = "M1; M2; M3"` packs several values into one cell, so we cannot query, count, or
  order modules with SQL, and module facts are duplicated on every grade row.

These four problems are the direct motivation for normalization.

---

## 4. Normalization to 1NF

**Rule (1NF):** every cell holds a single atomic value, there are no repeating groups, and each row
is identified by a key.

**Violation:** `ModuleTitles` is multi-valued; one student–course pairing spawns repeating groups
of assignments/modules.

**Action:** split each multi-valued cell into its own row and introduce explicit single-column
keys. The multi-valued `ModuleTitles` becomes a separate `Modules` table (one row per module,
referencing `CourseID`), and learning content inside a module becomes `Materials`. After this
step, every table in the final design uses a single-column `IDENTITY` key and contains **no
multi-valued columns**.

→ **Result:** the design reaches **1NF**. (Evidence: `Modules`, `Materials` tables in
`sql/01_schema.sql`.)

---

## 5. Normalization to 2NF

**Rule (2NF):** be in 1NF **and** every non-key attribute depends on the **whole** primary key
(no partial dependency on part of a composite key).

Consider an intermediate table after merging enrollment and grade data with the composite key
**(StudentID, CourseID, AssignmentID)**:

```
(StudentID, CourseID, AssignmentID) →
    StudentName, StudentEmail     -- depends only on StudentID      (PARTIAL)
    CourseTitle, InstructorName   -- depends only on CourseID        (PARTIAL)
    AssignmentTitle, Deadline     -- depends only on AssignmentID    (PARTIAL)
    Score, Feedback               -- depends on the whole key        (valid)
```

The partial dependencies violate 2NF. **Action:** decompose by the *source* of each dependency:

| Partial dependency | Extracted table |
|---|---|
| `StudentID → StudentName, Email` | **`Users`** |
| `CourseID → CourseTitle, InstructorID` | **`Courses`** |
| `AssignmentID → Title, Deadline` | **`Assignments`** |
| `(Student, Assignment) → Score, Feedback` | **`Submissions` + `Grades`** |
| M:N Student↔Course | **`Enrollments`** |

→ **Result:** each non-key attribute now depends fully on the key of its own table ⇒ **2NF**.

---

## 6. Normalization to 3NF

**Rule (3NF):** be in 2NF **and** no non-key attribute depends transitively on the key
(no *non-key → non-key* dependency).

Even after 2NF, `Courses` may still carry transitive dependencies:

```
CourseID → InstructorID → InstructorName, InstructorEmail   (transitive)
CourseID → CategoryID   → CategoryName, CategoryDescription (transitive)
```

`InstructorName` does not depend directly on `CourseID` but through `InstructorID` — a transitive
dependency that reintroduces redundancy and update anomalies.

**Action:**
- Move all instructor data into **`Users`**; `Courses` keeps only the foreign key `InstructorID`.
- Move all category data into **`Categories`**; `Courses` keeps only `CategoryID`.
- Similarly, `Submissions` keeps only `AssignmentID` (no duplicated `Deadline`/`MaxScore`), and
  `Grades.GradedBy` is a foreign key to `Users` instead of storing `GradedByName`.

→ **Result:** no remaining transitive dependencies ⇒ the entire schema reaches **3NF**.

### 6.1. 3NF verification table (main tables)

| Table | Primary key | Determining FD | 3NF? |
|---|---|---|---|
| `Users` | UserID | UserID → Username, Email, FullName, Role, Status | Yes |
| `Categories` | CategoryID | CategoryID → CategoryName, Description | Yes |
| `Courses` | CourseID | CourseID → CourseCode, Title, InstructorID, CategoryID, Level, Status | Yes |
| `Modules` | ModuleID | ModuleID → CourseID, Title, OrderIndex | Yes |
| `Materials` | MaterialID | MaterialID → ModuleID, Title, MaterialType, ContentURL | Yes |
| `Enrollments` | EnrollmentID | EnrollmentID → StudentID, CourseID, Status, ProgressPercent | Yes |
| `Assignments` | AssignmentID | AssignmentID → CourseID, Title, AType, MaxScore, Deadline, LatePolicy | Yes |
| `Questions` | QuestionID | QuestionID → AssignmentID, QuestionText, Points | Yes |
| `QuestionOptions` | OptionID | OptionID → QuestionID, OptionText, IsCorrect | Yes |
| `Submissions` | SubmissionID | SubmissionID → AssignmentID, StudentID, SubmittedAt, IsLate, Status | Yes |
| `StudentAnswers` | AnswerID | AnswerID → SubmissionID, QuestionID, SelectedOptionID | Yes |
| `Grades` | GradeID | GradeID → SubmissionID, Score, Feedback, GradedBy, GradedAt | Yes |
| `Recommendations` | RecommendationID | RecommendationID → StudentID, CourseID, Score, Status | Yes |
| `InteractionLogs` | LogID | LogID → UserID, SessionID, ActionType, DurationSec, CreatedAt | Yes |
| `Certificates` | CertificateID | CertificateID → StudentID, CourseID, FinalScore, IssuedAt | Yes |

*(`ForumThreads` and `ForumPosts` follow the same pattern: `ThreadID →` thread attributes,
`PostID →` post attributes, with no transitive dependencies.)*

---

## 7. Note on BCNF

For the functional dependencies modelled above, every determinant is a candidate key: each table
has a single-column surrogate primary key, and the natural keys enforced by `UNIQUE`
(`Users.Username`/`Email`, `Courses.CourseCode`, `Enrollments(StudentID, CourseID)`,
`Submissions(AssignmentID, StudentID, Attempt)`, `StudentAnswers(SubmissionID, QuestionID)`,
`Grades.SubmissionID`, `Certificates(StudentID, CourseID)`) are themselves candidate keys.
Because **no determinant is a non-candidate-key attribute**, the design is regarded as satisfying
**BCNF within this set of business FDs**. This is a conclusion based on the modelled dependencies,
not a fully formal proof for every conceivable FD.

---

## 8. How the Final Schema Eliminates the Original Anomalies

| Original anomaly | How the normalized schema removes it |
|---|---|
| Cannot add a course with no students | `Courses` is an independent table; a course exists without any `Enrollments` row |
| Cannot add a student with no enrollment | `Users` is independent of `Enrollments` |
| Instructor rename inconsistency | Instructor name stored once in `Users`; `Courses.InstructorID` is a foreign key |
| Course title repeated on every grade row | Title stored once in `Courses`; grades reference it via keys |
| Deleting last student loses the course | Deleting an `Enrollments`/`Grades` row never affects `Courses` |
| Multi-valued `ModuleTitles` | Replaced by `Modules` (one row per module) + `Materials` |

Referential integrity (`FOREIGN KEY`), uniqueness (`UNIQUE`), and domain rules (`CHECK`) in
`sql/01_schema.sql` then guarantee that the normalized structure stays consistent under inserts,
updates, and deletes.

---

## 9. Conclusion

The flat `EnrollmentSheet` table suffered from clear insertion, update, and deletion anomalies
caused by mixing independent facts and storing multi-valued data in one cell. Normalizing the
design to 1NF (atomic values), 2NF (no partial dependencies), and 3NF (no transitive
dependencies) decomposed it into the focused tables of the LMS schema, each describing exactly one
kind of entity. The resulting 3NF (and, within the modelled FDs, BCNF) design removes the
anomalies while remaining query-friendly, and its correctness is enforced at the database level by
primary keys, foreign keys, unique constraints, and check constraints.

---

## Appendix — Repository Evidence Referenced

| Content | Evidence file |
|---|---|
| Full UNF→1NF→2NF→3NF narrative and 3NF table | `docs/Normalization_and_DataDictionary.md` (Part A) |
| Implemented tables, keys, and constraints | `sql/01_schema.sql` |
| Per-table data dictionary | `docs/Normalization_and_DataDictionary.md` (Part B) |
| Implemented keys/constraints | `sql/01_schema.sql` |
