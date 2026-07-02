# Lab 2 — Entity Analysis and Functional Dependencies

> **Course:** DBI202 — Database Systems
> **Lab:** 2 — Entity Analysis and Functional Dependencies
> **Project:** Online Learning Management System (LMS)
> **Group:** 1
> **Members:** Huynh Pham Phi Linh — SE211780, Nguyen Tan Thinh — SE212249, Nguyen Quoc Bao — SE212261, Nguyen Hoang Vu — SE212202
> **Class:** AI2014
> **Date:** 01/07/2026

---

## 1. Objective

The goal of this lab is to analyse the entities of the Online Learning Management System (LMS),
list the attributes of each entity, determine the **functional dependencies (FDs)** that hold
within each entity, and derive the **candidate keys**, **primary keys**, and **foreign keys**.
The analysis is based directly on the implemented schema in `sql/01_schema.sql` and the data
dictionary in `docs/Normalization_and_DataDictionary.md`.

---

## 2. Project Domain Description

The LMS supports online learning through a web-based platform. **Users** (Students, Instructors,
Admins) interact with **Courses** organised into **Categories**. Each course is structured into
**Modules**, each containing learning **Materials**. Students register for courses through
**Enrollments** (a many-to-many relationship). Courses contain **Assignments** (Assignment / Quiz
/ Exam); quizzes use **Questions** and **QuestionOptions**. Students create **Submissions**; for
quizzes they record **StudentAnswers**; each evaluated submission receives a **Grade**. Courses
host discussions through **ForumThreads** and **ForumPosts**. The system records course
**Recommendations** and **InteractionLogs**, and issues **Certificates** when a learner's final
grade reaches the 80% threshold.

---

## 3. Notation and a Note on Surrogate Keys

- FDs are written `X → Y` ("X functionally determines Y").
- Every table uses a **surrogate primary key** (an `IDENTITY` integer). The surrogate key
  functionally determines all non-key attributes of its row.
- Several entities also have a **natural candidate key** enforced by a `UNIQUE` constraint
  (e.g., `Username`, `Email`, `CourseCode`, or the composite `(StudentID, CourseID)`). Where such
  a key exists, it is a true candidate key (it also determines the whole row); the group selected
  the surrogate as the primary key for stability and simpler foreign keys.
- `CHECK`/`NOT NULL`/`DEFAULT` are **integrity constraints**, not functional dependencies, and are
  therefore listed in Lab 4 rather than here.

---

## 4. Entity List (17)

| # | Entity (table) | Role |
|---|---|---|
| 1 | `Users` | People and their single role (Student / Instructor / Admin) |
| 2 | `Categories` | Course categories |
| 3 | `Courses` | Courses, each owned by one instructor |
| 4 | `Modules` | Chapters/modules of a course |
| 5 | `Materials` | Learning materials inside a module |
| 6 | `Enrollments` | Student↔Course registration (junction, M:N) |
| 7 | `Assignments` | Assignment / Quiz / Exam of a course |
| 8 | `Questions` | Objective questions of a quiz/exam |
| 9 | `QuestionOptions` | Answer options of a question |
| 10 | `Submissions` | A student's submission for an assignment |
| 11 | `StudentAnswers` | A student's chosen option per quiz question |
| 12 | `Grades` | The grade of a submission |
| 13 | `ForumThreads` | Discussion threads of a course |
| 14 | `ForumPosts` | Posts/replies inside a thread |
| 15 | `Recommendations` | Course recommendations shown to a student |
| 16 | `InteractionLogs` | User interaction/behaviour logs |
| 17 | `Certificates` | Completion certificates (final grade ≥ 80%) |

---

## 5. Entity Analysis: Attributes, Functional Dependencies and Keys

### 5.1. `Users`
- **Attributes:** `UserID`, `Username`, `PasswordHash`, `Email`, `FullName`, `DateOfBirth`, `Role`, `Status`, `CreatedAt`.
- **Functional dependencies:**
  - `UserID → Username, PasswordHash, Email, FullName, DateOfBirth, Role, Status, CreatedAt`
  - `Username → UserID` (UNIQUE) ⇒ `Username` determines the whole row
  - `Email → UserID` (UNIQUE) ⇒ `Email` determines the whole row
- **Candidate keys:** `{UserID}`, `{Username}`, `{Email}`.
- **Primary key:** `UserID`.
- **Foreign keys:** none (root entity).

### 5.2. `Categories`
- **Attributes:** `CategoryID`, `CategoryName`, `Description`.
- **Functional dependencies:**
  - `CategoryID → CategoryName, Description`
  - `CategoryName → CategoryID` (UNIQUE)
- **Candidate keys:** `{CategoryID}`, `{CategoryName}`.
- **Primary key:** `CategoryID`.
- **Foreign keys:** none.

### 5.3. `Courses`
- **Attributes:** `CourseID`, `CourseCode`, `Title`, `Description`, `InstructorID`, `CategoryID`, `Level`, `Price`, `Status`, `CreatedAt`.
- **Functional dependencies:**
  - `CourseID → CourseCode, Title, Description, InstructorID, CategoryID, Level, Price, Status, CreatedAt`
  - `CourseCode → CourseID` (UNIQUE)
- **Candidate keys:** `{CourseID}`, `{CourseCode}`.
- **Primary key:** `CourseID`.
- **Foreign keys:** `InstructorID → Users(UserID)`, `CategoryID → Categories(CategoryID)`.

### 5.4. `Modules`
- **Attributes:** `ModuleID`, `CourseID`, `Title`, `Description`, `OrderIndex`.
- **Functional dependencies:**
  - `ModuleID → CourseID, Title, Description, OrderIndex`
  - `(CourseID, OrderIndex) → ModuleID` (UNIQUE: module order is unique within a course)
- **Candidate keys:** `{ModuleID}`, `{CourseID, OrderIndex}`.
- **Primary key:** `ModuleID`.
- **Foreign keys:** `CourseID → Courses(CourseID)` (ON DELETE CASCADE).

### 5.5. `Materials`
- **Attributes:** `MaterialID`, `ModuleID`, `Title`, `MaterialType`, `ContentURL`, `OrderIndex`, `CreatedAt`.
- **Functional dependencies:**
  - `MaterialID → ModuleID, Title, MaterialType, ContentURL, OrderIndex, CreatedAt`
- **Candidate keys:** `{MaterialID}`.
- **Primary key:** `MaterialID`.
- **Foreign keys:** `ModuleID → Modules(ModuleID)` (ON DELETE CASCADE).

### 5.6. `Enrollments`  *(junction table — resolves M:N Student↔Course)*
- **Attributes:** `EnrollmentID`, `StudentID`, `CourseID`, `EnrollDate`, `Status`, `ProgressPercent`, `CompletedAt`.
- **Functional dependencies:**
  - `EnrollmentID → StudentID, CourseID, EnrollDate, Status, ProgressPercent, CompletedAt`
  - `(StudentID, CourseID) → EnrollmentID` (UNIQUE: a student enrols in a course at most once)
- **Candidate keys:** `{EnrollmentID}`, `{StudentID, CourseID}`.
- **Primary key:** `EnrollmentID`.
- **Foreign keys:** `StudentID → Users(UserID)`, `CourseID → Courses(CourseID)`.

### 5.7. `Assignments`
- **Attributes:** `AssignmentID`, `CourseID`, `Title`, `Description`, `AType`, `MaxScore`, `Deadline`, `LatePolicy`, `PenaltyPct`, `CreatedAt`.
- **Functional dependencies:**
  - `AssignmentID → CourseID, Title, Description, AType, MaxScore, Deadline, LatePolicy, PenaltyPct, CreatedAt`
- **Candidate keys:** `{AssignmentID}`.
- **Primary key:** `AssignmentID`.
- **Foreign keys:** `CourseID → Courses(CourseID)` (ON DELETE CASCADE).

### 5.8. `Questions`
- **Attributes:** `QuestionID`, `AssignmentID`, `QuestionText`, `Points`.
- **Functional dependencies:**
  - `QuestionID → AssignmentID, QuestionText, Points`
- **Candidate keys:** `{QuestionID}`.
- **Primary key:** `QuestionID`.
- **Foreign keys:** `AssignmentID → Assignments(AssignmentID)` (ON DELETE CASCADE).

### 5.9. `QuestionOptions`
- **Attributes:** `OptionID`, `QuestionID`, `OptionText`, `IsCorrect`.
- **Functional dependencies:**
  - `OptionID → QuestionID, OptionText, IsCorrect`
- **Candidate keys:** `{OptionID}`.
- **Primary key:** `OptionID`.
- **Foreign keys:** `QuestionID → Questions(QuestionID)` (ON DELETE CASCADE).

### 5.10. `Submissions`
- **Attributes:** `SubmissionID`, `AssignmentID`, `StudentID`, `SubmittedAt`, `ContentURL`, `IsLate`, `Status`, `Attempt`.
- **Functional dependencies:**
  - `SubmissionID → AssignmentID, StudentID, SubmittedAt, ContentURL, IsLate, Status, Attempt`
  - `(AssignmentID, StudentID, Attempt) → SubmissionID` (UNIQUE: one row per attempt)
- **Candidate keys:** `{SubmissionID}`, `{AssignmentID, StudentID, Attempt}`.
- **Primary key:** `SubmissionID`.
- **Foreign keys:** `AssignmentID → Assignments(AssignmentID)`, `StudentID → Users(UserID)`.

### 5.11. `StudentAnswers`
- **Attributes:** `AnswerID`, `SubmissionID`, `QuestionID`, `SelectedOptionID`.
- **Functional dependencies:**
  - `AnswerID → SubmissionID, QuestionID, SelectedOptionID`
  - `(SubmissionID, QuestionID) → AnswerID, SelectedOptionID` (UNIQUE: one answer per question per submission)
- **Candidate keys:** `{AnswerID}`, `{SubmissionID, QuestionID}`.
- **Primary key:** `AnswerID`.
- **Foreign keys:** `SubmissionID → Submissions(SubmissionID)` (CASCADE), `QuestionID → Questions(QuestionID)`, `SelectedOptionID → QuestionOptions(OptionID)`.

### 5.12. `Grades`
- **Attributes:** `GradeID`, `SubmissionID`, `Score`, `Feedback`, `GradedBy`, `GradedAt`.
- **Functional dependencies:**
  - `GradeID → SubmissionID, Score, Feedback, GradedBy, GradedAt`
  - `SubmissionID → GradeID` (UNIQUE: at most one grade per submission)
- **Candidate keys:** `{GradeID}`, `{SubmissionID}`.
- **Primary key:** `GradeID`.
- **Foreign keys:** `SubmissionID → Submissions(SubmissionID)` (CASCADE), `GradedBy → Users(UserID)` (nullable; NULL = system auto-grade).

### 5.13. `ForumThreads`
- **Attributes:** `ThreadID`, `CourseID`, `CreatedBy`, `Title`, `CreatedAt`.
- **Functional dependencies:**
  - `ThreadID → CourseID, CreatedBy, Title, CreatedAt`
- **Candidate keys:** `{ThreadID}`.
- **Primary key:** `ThreadID`.
- **Foreign keys:** `CourseID → Courses(CourseID)` (CASCADE), `CreatedBy → Users(UserID)`.

### 5.14. `ForumPosts`
- **Attributes:** `PostID`, `ThreadID`, `UserID`, `Content`, `ParentPostID`, `CreatedAt`.
- **Functional dependencies:**
  - `PostID → ThreadID, UserID, Content, ParentPostID, CreatedAt`
- **Candidate keys:** `{PostID}`.
- **Primary key:** `PostID`.
- **Foreign keys:** `ThreadID → ForumThreads(ThreadID)` (CASCADE), `UserID → Users(UserID)`, `ParentPostID → ForumPosts(PostID)` (self-reference for nested replies).

### 5.15. `Recommendations`
- **Attributes:** `RecommendationID`, `StudentID`, `CourseID`, `Reason`, `Score`, `Status`, `CreatedAt`.
- **Functional dependencies:**
  - `RecommendationID → StudentID, CourseID, Reason, Score, Status, CreatedAt`
- **Candidate keys:** `{RecommendationID}`.
  *(No `UNIQUE(StudentID, CourseID)` is imposed: the same course may be recommended to the same student more than once over time, e.g., re-shown with a new status. Hence the surrogate key is the only candidate key.)*
- **Primary key:** `RecommendationID`.
- **Foreign keys:** `StudentID → Users(UserID)`, `CourseID → Courses(CourseID)`.

### 5.16. `InteractionLogs`
- **Attributes:** `LogID`, `UserID`, `SessionID`, `ActionType`, `EntityType`, `EntityID`, `DurationSec`, `CreatedAt`.
- **Functional dependencies:**
  - `LogID → UserID, SessionID, ActionType, EntityType, EntityID, DurationSec, CreatedAt`
- **Candidate keys:** `{LogID}`.
- **Primary key:** `LogID` (`BIGINT IDENTITY`).
- **Foreign keys:** `UserID → Users(UserID)` (nullable).

### 5.17. `Certificates`
- **Attributes:** `CertificateID`, `StudentID`, `CourseID`, `FinalScore`, `IssuedAt`, `CertificateCode` *(computed)*.
- **Functional dependencies:**
  - `CertificateID → StudentID, CourseID, FinalScore, IssuedAt, CertificateCode`
  - `(StudentID, CourseID) → CertificateID` (UNIQUE: one certificate per student per course)
  - `CertificateID ↔ CertificateCode` (the code is derived 1:1 from the identity, so each determines the other)
- **Candidate keys:** `{CertificateID}`, `{StudentID, CourseID}`, `{CertificateCode}`.
- **Primary key:** `CertificateID`.
- **Foreign keys:** `StudentID → Users(UserID)`, `CourseID → Courses(CourseID)`.

---

## 6. Relationships Summary (from Foreign Keys)

The overall structure of the entities and their relationships is shown in the Entity-Relationship
Diagram below.

![Entity-Relationship Diagram of the LMS database](../diagrams/erd_chen.png)

*Figure 1. Entity-Relationship Diagram of the LMS database in Chen notation (`docs/diagrams/erd_chen.png`).*


| Relationship | Type | Implemented by |
|---|---|---|
| Instructor (User) **owns** Courses | 1:N | `Courses.InstructorID → Users` |
| Category **classifies** Courses | 1:N | `Courses.CategoryID → Categories` |
| Course **has** Modules | 1:N | `Modules.CourseID → Courses` |
| Module **contains** Materials | 1:N | `Materials.ModuleID → Modules` |
| Student **enrols in** Course | **M:N** | `Enrollments(StudentID, CourseID)` junction |
| Course **has** Assignments | 1:N | `Assignments.CourseID → Courses` |
| Assignment **has** Questions | 1:N | `Questions.AssignmentID → Assignments` |
| Question **has** Options | 1:N | `QuestionOptions.QuestionID → Questions` |
| Student **makes** Submissions | 1:N | `Submissions.StudentID → Users` |
| Assignment **receives** Submissions | 1:N | `Submissions.AssignmentID → Assignments` |
| Submission **has** StudentAnswers | 1:N | `StudentAnswers.SubmissionID → Submissions` |
| Submission **graded by** Grade | 1:1 | `Grades.SubmissionID` (UNIQUE) → Submissions |
| Course **has** ForumThreads | 1:N | `ForumThreads.CourseID → Courses` |
| Thread **has** Posts (nested) | 1:N + self | `ForumPosts.ThreadID → ForumThreads`, `ParentPostID → ForumPosts` |
| Student **receives** Recommendations | 1:N | `Recommendations.StudentID → Users` |
| User **generates** InteractionLogs | 1:N | `InteractionLogs.UserID → Users` |
| Student **earns** Certificate for Course | M:N resolved, 1 per pair | `Certificates(StudentID, CourseID)` UNIQUE |

---

## 7. Conclusion and Reflection

This lab identified the **17 entities** of the LMS, their attributes, the functional dependencies
that hold inside each entity, and the resulting candidate keys, primary keys, and foreign keys.
A consistent pattern emerged: every entity is anchored by a **surrogate primary key** that
functionally determines all of its non-key attributes, while several entities also expose a
**natural candidate key** through a `UNIQUE` constraint (`Username`, `Email`, `CourseCode`,
`(CourseID, OrderIndex)`, `(StudentID, CourseID)`, `(AssignmentID, StudentID, Attempt)`,
`(SubmissionID, QuestionID)`, `SubmissionID`, `CertificateCode`).

Because each non-key attribute depends on the whole key of its own entity and there are **no
non-key → non-key (transitive) dependencies**, the design is already free of partial and
transitive dependencies — which Lab 3 formally confirms through normalization to 3NF. The clear
foreign-key relationships, and in particular the junction tables `Enrollments` and
`Certificates`, demonstrate correct handling of many-to-many relationships, providing a solid,
integrity-preserving foundation for the remaining design and implementation labs.

---

## Appendix — Repository Evidence Referenced

| Content | Evidence file |
|---|---|
| Table definitions, columns, PK/FK/UNIQUE constraints | `sql/01_schema.sql` |
| Per-table data dictionary (types and constraints) | `docs/Normalization_and_DataDictionary.md` (Part B) |
| FD / 3NF determination table | `docs/Normalization_and_DataDictionary.md` (Part A) |
| Entity-Relationship Diagram (Chen notation) | `docs/diagrams/erd_chen.png` (Figure 1) |
