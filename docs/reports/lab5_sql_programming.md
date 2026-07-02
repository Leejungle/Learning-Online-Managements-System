# Lab 5 — SQL Queries, View, Index, Functions, Procedures, and Triggers

> **Course:** DBI202 — Database Systems
> **Lab:** 5 — SQL Queries, View, Index, Functions, Procedures, and Triggers
> **Project:** Online Learning Management System (LMS)
> **Group:** 1
> **Members:** Huynh Pham Phi Linh — SE211780, Nguyen Tan Thinh — SE212249, Nguyen Quoc Bao — SE212261, Nguyen Hoang Vu — SE212202
> **Class:** AI2014
> **Date:** 01/07/2026

---

## 1. Objective

In this lab we practise SQL programming on the LMS database that we designed in Lab 4. We write
queries ranging from basic retrieval to advanced operations (joins, grouping, subqueries and set
operations), and we implement the database's programmable objects — user-defined functions, stored
procedures and triggers — to enforce business rules and automate tasks. We also define views to
simplify data access and indexes to improve query performance. Every statement below was executed
against our live database and the results shown are the actual output.

---

## 2. SQL Queries

### 2.1. Basic queries

**Select all records from a table.** Listing every category in the catalogue.

```sql
SELECT CategoryID, CategoryName FROM Categories ORDER BY CategoryID;
```

```
CategoryID  CategoryName
----------  -----------------------
1           Programming
2           Database
3           Data Science
4           Design
5           Mathematics
6           Computer Science
7           Artificial Intelligence
8           Software Engineering
9           Soft Skills
```

**Filter rows with WHERE.** Published beginner-level courses.

```sql
SELECT CourseCode, Title, Level, Price
FROM Courses
WHERE Status = 'Published' AND Level = 'Beginner'
ORDER BY CourseCode;
```

```
CourseCode  Title                                       Price
----------  ------------------------------------------  -----
CSI106      Introduction to Computer Science             0.00
ITE303c     Ethics in IT                                 0.00
MAE101      Mathematics for Engineering                  0.00
PFP191      Programming Fundamental with Python          0.00
SSG105      Communication and In-Group Working Skills    0.00
UX150       UI/UX Design Principles                     29.00
WD110       Web Development Basics                        0.00
```

A second WHERE example — certificates whose final score reached 90%.

```sql
SELECT CertificateCode, StudentID, CourseID, FinalScore
FROM Certificates
WHERE FinalScore >= 90
ORDER BY CertificateID;
```

```
CertificateCode  StudentID  CourseID  FinalScore
---------------  ---------  --------  ----------
LMS-CERT-00001   8          2         90.00
LMS-CERT-00003   8          3         90.00
LMS-CERT-00004   9          3         90.00
LMS-CERT-00006   10         4         90.00
LMS-CERT-00008   24         4         90.00
```

**Sort results with ORDER BY.** The most expensive courses first.

```sql
SELECT CourseCode, Title, Price
FROM Courses
ORDER BY Price DESC, Title;
```

```
CourseCode  Title                       Price
----------  --------------------------  -----
DS301       Data Science Foundations    79.00
DBI202      Database Systems            49.00
UX150       UI/UX Design Principles     29.00
```

**Aggregations (COUNT, SUM, AVG, MAX, MIN).** Number of users in each role.

```sql
SELECT Role, COUNT(*) AS UserCount
FROM Users
GROUP BY Role
ORDER BY UserCount DESC;
```

```
Role        UserCount
----------  ---------
Student     23
Instructor  15
Admin       1
```

Price statistics over the whole catalogue.

```sql
SELECT COUNT(*) AS Courses, MIN(Price) AS MinPrice,
       MAX(Price) AS MaxPrice, AVG(Price) AS AvgPrice
FROM Courses;
```

```
Courses  MinPrice  MaxPrice  AvgPrice
-------  --------  --------  --------
26       0.00      79.00     6.04
```

Enrolments grouped by their status.

```sql
SELECT Status, COUNT(*) AS Cnt
FROM Enrollments
GROUP BY Status
ORDER BY Cnt DESC;
```

```
Status     Cnt
---------  ---
Active     107
Completed  37
Dropped    14
```

### 2.2. Intermediate queries

**Join multiple tables.** Each course with its instructor and category (three-table INNER JOIN).

```sql
SELECT c.CourseCode, c.Title, u.FullName AS Instructor, cat.CategoryName
FROM Courses c
JOIN Users u        ON u.UserID = c.InstructorID
JOIN Categories cat ON cat.CategoryID = c.CategoryID
ORDER BY c.CourseCode;
```

```
CourseCode  Title                                        Instructor        CategoryName
----------  -------------------------------------------  ----------------  -----------------------
ADY201m     AI, Data Science with Python & SQL           Nguyen Thi Dao    Data Science
AIL303m     Machine Learning                             Nguyen Minh Tuan  Artificial Intelligence
CEA201      Computer Organization and Architecture       Nguyen Thi Dao    Computer Science
CPV301      Computer Vision                              Tran Thu Ha       Artificial Intelligence
CSD201      Data Structures and Algorithms with C        Dinh Thi Lien     Computer Science
```

**Left join** so that submissions without a grade still appear (`Score` is NULL).

```sql
SELECT s.SubmissionID, u.FullName AS Student, g.Score
FROM Submissions s
JOIN Users u       ON u.UserID = s.StudentID
LEFT JOIN Grades g ON g.SubmissionID = s.SubmissionID
ORDER BY s.SubmissionID;
```

```
SubmissionID  Student         Score
------------  --------------  -----
1             Hoang Van Dung  8.50
4             Hoang Van Dung  6.50
5             Ngo Thi Lan     8.00
6             Hoang Van Dung  NULL
7             Ngo Thi Lan     10.00
```

**Self join** on the forum: each post together with the author it replies to
(`ParentPostID` points back to `ForumPosts`).

```sql
SELECT p.PostID, au.FullName AS Author, pau.FullName AS ReplyingTo
FROM ForumPosts p
JOIN Users au            ON au.UserID = p.UserID
LEFT JOIN ForumPosts parent ON parent.PostID = p.ParentPostID
LEFT JOIN Users pau      ON pau.UserID = parent.UserID
ORDER BY p.PostID;
```

```
PostID  Author          ReplyingTo
------  --------------  --------------
1       Hoang Van Dung  NULL
2       Le Van An       Hoang Van Dung
3       Do Thi Giang    Hoang Van Dung
4       Ngo Thi Lan     NULL
5       Tran Thi Binh   Ngo Thi Lan
```

**GROUP BY … HAVING.** Courses that have more than three enrolments.

```sql
SELECT c.Title, COUNT(e.EnrollmentID) AS Enrollments
FROM Courses c
JOIN Enrollments e ON e.CourseID = c.CourseID
GROUP BY c.Title
HAVING COUNT(e.EnrollmentID) > 3
ORDER BY Enrollments DESC;
```

```
Title                                  Enrollments
-------------------------------------  -----------
Data Structures and Algorithms with C  8
Data Science Foundations               8
Introduction to Software Engineering   8
Mathematics for Machine Learning       8
Natural Language Processing            8
Web Development Basics                 8
```

Instructors who own more than one course.

```sql
SELECT u.FullName AS Instructor, COUNT(c.CourseID) AS Courses
FROM Users u
JOIN Courses c ON c.InstructorID = u.UserID
GROUP BY u.FullName
HAVING COUNT(c.CourseID) > 1
ORDER BY Courses DESC, Instructor;
```

```
Instructor        Courses
----------------  -------
Le Hoang Long     3
Le Van An         3
Nguyen Minh Tuan  3
Nguyen Thi Dao    3
Tran Thu Ha       3
```

**Subquery in WHERE (scalar).** Courses priced above the overall average.

```sql
SELECT CourseCode, Title, Price
FROM Courses
WHERE Price > (SELECT AVG(Price) FROM Courses)
ORDER BY Price DESC;
```

```
CourseCode  Title                     Price
----------  ------------------------  -----
DS301       Data Science Foundations  79.00
DBI202      Database Systems          49.00
UX150       UI/UX Design Principles   29.00
```

**Subquery in FROM (derived table).** Enrolment counts computed in a sub-select, then ordered.

```sql
SELECT t.CourseID, t.Cnt
FROM (SELECT CourseID, COUNT(*) AS Cnt
      FROM Enrollments GROUP BY CourseID) t
ORDER BY t.Cnt DESC, t.CourseID;
```

```
CourseID  Cnt
--------  ---
3         8
4         8
9         8
14        8
19        8
24        8
```

### 2.3. Advanced queries

**Correlated / nested subquery.** Courses for which no assignment has been graded yet
(`NOT EXISTS` over a nested three-table join).

```sql
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

```
CourseCode  Title
----------  ------------------------------------------
CEA201      Computer Organization and Architecture
CSD203      Data Structures and Algorithms with Python
CSI106      Introduction to Computer Science
DAP391m     AI-DS Project
DAT301m     AI Development with TensorFlow
```

A correlated subquery comparing each row to a group average — enrolments whose progress is above
the average progress of their own course.

```sql
SELECT e.StudentID, e.CourseID, e.ProgressPercent
FROM Enrollments e
WHERE e.ProgressPercent > (
    SELECT AVG(e2.ProgressPercent)
    FROM Enrollments e2
    WHERE e2.CourseID = e.CourseID
)
ORDER BY e.ProgressPercent DESC;
```

```
StudentID  CourseID  ProgressPercent
---------  --------  ---------------
11         5         100.00
10         4         100.00
11         4         100.00
24         4         100.00
9          3         100.00
```

**EXISTS.** Courses that have at least one enrolment.

```sql
SELECT c.CourseCode, c.Title
FROM Courses c
WHERE EXISTS (SELECT 1 FROM Enrollments e WHERE e.CourseID = c.CourseID)
ORDER BY c.CourseCode;
```

```
CourseCode  Title
----------  ----------------------------------
ADY201m     AI, Data Science with Python & SQL
AIL303m     Machine Learning
CEA201      Computer Organization and Architecture
CPV301      Computer Vision
CSD201      Data Structures and Algorithms with C
```

**IN / ALL.** Courses at least as expensive as every beginner course (`>= ALL`).

```sql
SELECT CourseCode, Title, Price
FROM Courses
WHERE Price >= ALL (SELECT Price FROM Courses WHERE Level = 'Beginner')
ORDER BY Price DESC;
```

```
CourseCode  Title                     Price
----------  ------------------------  -----
DS301       Data Science Foundations  79.00
DBI202      Database Systems          49.00
UX150       UI/UX Design Principles   29.00
```

**Set operations.** `INTERSECT` — students who are both enrolled and certified.

```sql
SELECT StudentID FROM Enrollments
INTERSECT
SELECT StudentID FROM Certificates
ORDER BY StudentID;
```

```
StudentID
---------
5, 6, 7, 8, 9, 10, 11, 12, 22, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36
```

`EXCEPT` — students who are enrolled but have not earned any certificate yet.

```sql
SELECT StudentID FROM Enrollments
EXCEPT
SELECT StudentID FROM Certificates
ORDER BY StudentID;
```

```
StudentID
---------
23
```

`UNION` — a single staff list combining instructors and admins.

```sql
SELECT UserID, FullName, 'Instructor' AS Kind FROM Users WHERE Role = 'Instructor'
UNION
SELECT UserID, FullName, 'Admin' FROM Users WHERE Role = 'Admin'
ORDER BY UserID;
```

```
UserID  FullName          Kind
------  ----------------  ----------
1       Nguyen Quan Tri   Admin
2       Le Van An         Instructor
3       Tran Thi Binh     Instructor
4       Pham Van Cuong    Instructor
13      Nguyen Thi Dao    Instructor
```

---

## 3. Functions

We implemented five user-defined functions in `sql/03_functions_views.sql`: four scalar functions
and one table-valued function.

| Function | Type | Purpose |
|---|---|---|
| `fn_CanAccessCourse(@StudentID, @CourseID)` | scalar `BIT` | Returns 1 if the student is enrolled (Active/Completed) in the course |
| `fn_CourseProgress(@StudentID, @CourseID)` | scalar `DECIMAL(5,2)` | Percentage of graded assignments the student has completed |
| `fn_CourseFinalGrade(@StudentID, @CourseID)` | scalar `DECIMAL(5,2)` | The final course grade (0..100) computed from graded work |
| `fn_HasPassedCourse(@StudentID, @CourseID)` | scalar `BIT` | Returns 1 if the final grade is at least 80% |
| `fn_AccessibleMaterials(@StudentID)` | table-valued | Returns every material the student is allowed to open |

Calling the four scalar functions on one enrolled student–course pair:

```sql
DECLARE @sid INT, @cid INT;
SELECT TOP (1) @sid = StudentID, @cid = CourseID
FROM Enrollments WHERE Status IN ('Active','Completed') ORDER BY EnrollmentID;

SELECT @sid AS StudentID, @cid AS CourseID,
       dbo.fn_CanAccessCourse(@sid, @cid) AS CanAccess,
       dbo.fn_CourseProgress(@sid, @cid)  AS ProgressPct,
       dbo.fn_CourseFinalGrade(@sid, @cid) AS FinalGrade,
       dbo.fn_HasPassedCourse(@sid, @cid) AS HasPassed;
```

```
StudentID  CourseID  CanAccess  ProgressPct  FinalGrade  HasPassed
---------  --------  ---------  -----------  ----------  ---------
5          1         1          50.00        42.50       0
```

The four values are consistent: the student can access the course, has completed 50% of the graded
work, has a 42.50% final grade, and therefore has not yet passed. The table-valued function returns
the materials the same student may open:

```sql
SELECT TOP (5) MaterialID, Title, MaterialType
FROM dbo.fn_AccessibleMaterials(@sid) ORDER BY MaterialID;
```

```
MaterialID  Title                                            MaterialType
----------  -----------------------------------------------  ------------
1           Lecture Slides: Getting Started with Python      Slide
2           Reading Material: Getting Started with Python     Document
3           Video Lecture: Getting Started with Python        Video
4           Practice Exercises: Getting Started with Python   Document
5           Reference Link: Getting Started with Python       Link
```

---

## 4. Stored Procedures

Six stored procedures in `sql/04_procedures.sql` encapsulate the multi-step operations of the LMS.
Each one runs inside a transaction with `TRY/CATCH` error handling so it either fully succeeds or
fully rolls back.

| Procedure | Purpose |
|---|---|
| `sp_EnrollStudent` | Enrol a student in a course and mark a matching recommendation as enrolled |
| `sp_SubmitAssignment` | Create a submission (auto-incrementing the attempt number) |
| `sp_GradeSubmission` | Record or replace a manual grade for a submission |
| `sp_AutoGradeQuiz` | Automatically grade an objective quiz against its answer key |
| `sp_RecommendCourses` | Generate content-based course recommendations from studied categories |
| `sp_IssueCertificate` | Issue a certificate only when the final grade is at least 80% |

Running `sp_RecommendCourses` for the most active student produces ranked recommendations. (The
demonstration is wrapped in a transaction and rolled back so the sample data is unchanged.)

```sql
BEGIN TRAN;
EXEC sp_RecommendCourses @StudentID = 5, @TopN = 5;
ROLLBACK;
```

```
RecommendationID  CourseID  Title                               Score   Reason
----------------  --------  ----------------------------------  ------  ------------------------------
28                4         Web Development Basics              0.9444  Similar to categories you study
29                13        Ethics in IT                       0.9375  Similar to categories you study
30                18        AI-DS Project                      0.9375  Similar to categories you study
31                12        AI, Data Science with Python & SQL 0.9286  Similar to categories you study
32                17        Computer Vision                    0.9286  Similar to categories you study
```

Running `sp_EnrollStudent` creates a new enrolment row (shown below, then rolled back):

```sql
BEGIN TRAN;
EXEC sp_EnrollStudent @StudentID = 5, @CourseID = 3;
SELECT EnrollmentID, StudentID, CourseID, Status
FROM Enrollments WHERE StudentID = 5 AND CourseID = 3;
ROLLBACK;
```

```
EnrollmentID  StudentID  CourseID  Status
------------  ---------  --------  ------
162           5          3         Active
```

---

## 5. Triggers

Seven triggers in `sql/02_triggers.sql` enforce business rules and keep the data consistent.

| Trigger | Rule enforced |
|---|---|
| `trg_Courses_InstructorRole` | A course owner must have the `Instructor` role |
| `trg_Enroll_Validate` | Only `Student` accounts may enrol, and only in `Published` courses |
| `trg_Submissions_Policy` | Checks enrolment, sets the `IsLate` flag and applies the late policy |
| `trg_Modules_KeepAtLeastOne` | A published course must keep at least one module |
| `trg_Courses_PublishNeedsModule` | A course can be `Published` only if it has a module |
| `trg_Grades_MarkGraded` | Grader must be Instructor/Admin, score ≤ MaxScore, submission marked Graded |
| `trg_StudentAnswers_OptionMatchesQuestion` | A chosen answer option must belong to its own question |

To demonstrate `trg_Enroll_Validate`, we try to enrol an instructor account (not a student). The
trigger rejects the insert with a clear error message:

```sql
INSERT INTO Enrollments (StudentID, CourseID, Status)
VALUES (2, 1, 'Active');   -- user 2 is an Instructor
```

```
OK rule enforced: Business rule violated: only users with role Student can enroll.
```

`trg_StudentAnswers_OptionMatchesQuestion` guarantees that a saved answer always references an
option belonging to the same question. The check below confirms zero violations exist in the data:

```sql
SELECT COUNT(*) AS MismatchedAnswers
FROM StudentAnswers sa
JOIN QuestionOptions o ON o.OptionID = sa.SelectedOptionID
WHERE o.QuestionID <> sa.QuestionID;
```

```
MismatchedAnswers
-----------------
0
```

---

## 6. Views and Indexes

### 6.1. Views

Two views in `sql/03_functions_views.sql` simplify the most common complex queries.

| View | Purpose |
|---|---|
| `vw_CourseCatalog` | One row per course with instructor name, enrolled-student count and module count |
| `vw_Gradebook` | One row per submission with its grade information (ungraded rows still appear) |

Reading the course catalogue view:

```sql
SELECT TOP (8) CourseCode, Title, InstructorName, EnrolledStudents, ModuleCount
FROM vw_CourseCatalog
ORDER BY EnrolledStudents DESC, CourseCode;
```

```
CourseCode  Title                                  InstructorName    EnrolledStudents  ModuleCount
----------  -------------------------------------  ----------------  ----------------  -----------
CSD201      Data Structures and Algorithms with C  Dinh Thi Lien     8                 11
DS301       Data Science Foundations               Pham Van Cuong    8                 10
MAI391      Mathematics for Machine Learning       Dinh Thi Lien     8                 10
NLP301c     Natural Language Processing            Nguyen Minh Tuan  8                 10
SWE201c     Introduction to Software Engineering   Le Hoang Long     8                 10
```

Reading the gradebook view (a submission with no grade shows `NULL`):

```sql
SELECT TOP (8) StudentName, AssignmentTitle, Score, SubmissionStatus
FROM vw_Gradebook
ORDER BY SubmissionID;
```

```
StudentName     AssignmentTitle           Score  SubmissionStatus
--------------  ------------------------  -----  ----------------
Hoang Van Dung  Python Basics Assignment  8.50   Graded
Do Thi Giang    Python Basics Assignment  7.00   Graded
Vu Van Hai      Python Basics Assignment  9.00   Graded
Hoang Van Dung  Python Quiz 1             NULL   Rejected
Ngo Thi Lan     Database Quiz             10.00  Graded
```

### 6.2. Indexes

Besides the clustered primary-key indexes, we created six secondary indexes to speed up the most
frequent lookups and reports. `IX_Log_User_Time` is a composite index on two columns, and the
others are single-column indexes.

```sql
SELECT t.name AS TableName, i.name AS IndexName, i.type_desc AS IndexType, i.is_unique
FROM sys.indexes i
JOIN sys.tables t ON t.object_id = i.object_id
WHERE i.name LIKE 'IX[_]%'
ORDER BY t.name, i.name;
```

```
TableName        IndexName              IndexType     is_unique
---------------  ---------------------  ------------  ---------
Courses          IX_Courses_Instructor  NONCLUSTERED  0
Enrollments      IX_Enroll_Course       NONCLUSTERED  0
Enrollments      IX_Enroll_Student      NONCLUSTERED  0
InteractionLogs  IX_Log_User_Time       NONCLUSTERED  0
Submissions      IX_Sub_Assignment      NONCLUSTERED  0
Submissions      IX_Sub_Student         NONCLUSTERED  0
```

---

## 7. Conclusion and Reflection

This lab put the Lab 4 database to work through the full range of SQL programming. We wrote basic
queries (selection, filtering, sorting and aggregation), intermediate queries (multi-table joins,
grouping with `HAVING`, and subqueries in both `WHERE` and `FROM`), and advanced queries
(correlated subqueries, `EXISTS`/`IN`/`ALL`, and the `UNION`/`INTERSECT`/`EXCEPT` set operations).
On top of the queries we built five functions, six stored procedures, seven triggers, two views and
six indexes, and every one of them executed successfully against our live data.

Working through these objects showed us how much logic can — and should — live inside the database.
Functions let us reuse calculations such as course progress and final grade; stored procedures wrap
multi-step operations like enrolment and certificate issuance in safe transactions; triggers stop
invalid data before it is ever written; views hide complex joins behind a simple name; and indexes
keep the frequent queries fast. Together they make the LMS database not just a place to store data
but the component that guarantees the rules of the system are always respected.
