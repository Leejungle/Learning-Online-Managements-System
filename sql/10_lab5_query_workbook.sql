/* =====================================================================
   File 10 - LAB 5 QUERY WORKBOOK
   ---------------------------------------------------------------------
   Purpose : A single, READ-ONLY / NON-DESTRUCTIVE workbook that
             demonstrates SQL coverage for Lab 5 (DBI202) over the LMS
             database, from basic SELECTs to ad vanced queries, plus
             demonstrations of the project's VIEWS, FUNCTIONS, INDEXES,
             STORED PROCEDURES and TRIGGERS.

   Safety  : * Every query is SELECT-only unless explicitly noted.
             * No schema changes (no CREATE/ALTER/DROP of tables).
             * Procedure / trigger demonstrations that would modify data
               are wrapped in BEGIN TRANSACTION ... ROLLBACK so the
               sample data is never permanently changed.
             * Run AFTER the database is built and seeded
               (01..05, and ideally 08_more_sample_data.sql).

   How to read: queries are tagged [Qnn] to match the
                "Lab 5 Query Coverage Matrix" in the Lab 5 report
                (docs/reports/lab5_sql_programming.md).
   ===================================================================== */
USE LMS;
GO
SET NOCOUNT ON;
GO

/* =====================================================================
   PART A — BASIC SELECT FOR EVERY TABLE (all 17 tables covered)
   One representative SELECT per table. TOP (n) keeps output readable.
   ===================================================================== */

PRINT '--- [Q01] Users ---';
SELECT TOP (10) UserID, Username, FullName, Role, Status FROM Users ORDER BY UserID;

PRINT '--- [Q02] Categories ---';
SELECT CategoryID, CategoryName, Description FROM Categories ORDER BY CategoryID;

PRINT '--- [Q03] Courses ---';
SELECT TOP (10) CourseID, CourseCode, Title, Level, Status, Price FROM Courses ORDER BY CourseID;

PRINT '--- [Q04] Modules ---';
SELECT TOP (10) ModuleID, CourseID, Title, OrderIndex FROM Modules ORDER BY CourseID, OrderIndex;

PRINT '--- [Q05] Materials ---';
SELECT TOP (10) MaterialID, ModuleID, Title, MaterialType FROM Materials ORDER BY MaterialID;

PRINT '--- [Q06] Enrollments ---';
SELECT TOP (10) EnrollmentID, StudentID, CourseID, Status, ProgressPercent FROM Enrollments ORDER BY EnrollmentID;

PRINT '--- [Q07] Assignments ---';
SELECT TOP (10) AssignmentID, CourseID, Title, AType, MaxScore, Deadline FROM Assignments ORDER BY AssignmentID;

PRINT '--- [Q08] Questions ---';
SELECT TOP (10) QuestionID, AssignmentID, Points, LEFT(QuestionText, 60) AS QuestionPreview FROM Questions ORDER BY QuestionID;

PRINT '--- [Q09] QuestionOptions ---';
SELECT TOP (10) OptionID, QuestionID, IsCorrect, LEFT(OptionText, 50) AS OptionPreview FROM QuestionOptions ORDER BY OptionID;

PRINT '--- [Q10] Submissions ---';
SELECT TOP (10) SubmissionID, AssignmentID, StudentID, Status, IsLate, Attempt FROM Submissions ORDER BY SubmissionID;

PRINT '--- [Q11] StudentAnswers ---';
SELECT TOP (10) AnswerID, SubmissionID, QuestionID, SelectedOptionID FROM StudentAnswers ORDER BY AnswerID;

PRINT '--- [Q12] Grades ---';
SELECT TOP (10) GradeID, SubmissionID, Score, GradedBy, GradedAt FROM Grades ORDER BY GradeID;

PRINT '--- [Q13] ForumThreads ---';
SELECT TOP (10) ThreadID, CourseID, CreatedBy, Title FROM ForumThreads ORDER BY ThreadID;

PRINT '--- [Q14] ForumPosts ---';
SELECT TOP (10) PostID, ThreadID, UserID, ParentPostID, LEFT(Content, 50) AS ContentPreview FROM ForumPosts ORDER BY PostID;

PRINT '--- [Q15] Recommendations ---';
SELECT TOP (10) RecommendationID, StudentID, CourseID, Score, Status FROM Recommendations ORDER BY RecommendationID;

PRINT '--- [Q16] InteractionLogs ---';
SELECT TOP (10) LogID, UserID, ActionType, EntityType, DurationSec, CreatedAt FROM InteractionLogs ORDER BY LogID;

PRINT '--- [Q17] Certificates ---';
SELECT TOP (10) CertificateID, CertificateCode, StudentID, CourseID, FinalScore FROM Certificates ORDER BY CertificateID;
GO

/* =====================================================================
   PART B — WHERE / ORDER BY / DISTINCT (filtering & sorting)
   ===================================================================== */

PRINT '--- [Q18] Published courses, most expensive first (WHERE + ORDER BY) ---';
SELECT CourseCode, Title, Price, Level
FROM Courses
WHERE Status = 'Published'
ORDER BY Price DESC, Title;

PRINT '--- [Q19] Active students only (WHERE on enumerated columns) ---';
SELECT UserID, FullName, Email
FROM Users
WHERE Role = 'Student' AND Status = 'Active'
ORDER BY FullName;

PRINT '--- [Q20] Distinct material types in use (DISTINCT) ---';
SELECT DISTINCT MaterialType FROM Materials ORDER BY MaterialType;

PRINT '--- [Q21] Assignments with a deadline this year, by deadline (WHERE date + ORDER BY) ---';
SELECT AssignmentID, Title, AType, Deadline
FROM Assignments
WHERE Deadline >= '2020-01-01'
ORDER BY Deadline;

PRINT '--- [Q22] Late submissions only (BIT filter) ---';
SELECT SubmissionID, AssignmentID, StudentID, Status
FROM Submissions
WHERE IsLate = 1
ORDER BY SubmissionID;
GO

/* =====================================================================
   PART C — AGGREGATION (COUNT / SUM / AVG / MIN / MAX + GROUP BY)
   ===================================================================== */

PRINT '--- [Q23] Row counts of every table (UNION ALL of COUNT(*)) ---';
SELECT 'Users' AS TableName, COUNT(*) AS Rows FROM Users
UNION ALL SELECT 'Categories', COUNT(*) FROM Categories
UNION ALL SELECT 'Courses', COUNT(*) FROM Courses
UNION ALL SELECT 'Modules', COUNT(*) FROM Modules
UNION ALL SELECT 'Materials', COUNT(*) FROM Materials
UNION ALL SELECT 'Enrollments', COUNT(*) FROM Enrollments
UNION ALL SELECT 'Assignments', COUNT(*) FROM Assignments
UNION ALL SELECT 'Questions', COUNT(*) FROM Questions
UNION ALL SELECT 'QuestionOptions', COUNT(*) FROM QuestionOptions
UNION ALL SELECT 'Submissions', COUNT(*) FROM Submissions
UNION ALL SELECT 'StudentAnswers', COUNT(*) FROM StudentAnswers
UNION ALL SELECT 'Grades', COUNT(*) FROM Grades
UNION ALL SELECT 'ForumThreads', COUNT(*) FROM ForumThreads
UNION ALL SELECT 'ForumPosts', COUNT(*) FROM ForumPosts
UNION ALL SELECT 'Recommendations', COUNT(*) FROM Recommendations
UNION ALL SELECT 'InteractionLogs', COUNT(*) FROM InteractionLogs
UNION ALL SELECT 'Certificates', COUNT(*) FROM Certificates
ORDER BY TableName;

PRINT '--- [Q24] Users per role (GROUP BY + COUNT) ---';
SELECT Role, COUNT(*) AS UserCount
FROM Users
GROUP BY Role
ORDER BY UserCount DESC;

PRINT '--- [Q25] Course price statistics by level (MIN/MAX/AVG) ---';
SELECT Level,
       COUNT(*)              AS Courses,
       MIN(Price)            AS MinPrice,
       MAX(Price)            AS MaxPrice,
       CAST(AVG(Price) AS DECIMAL(10,2)) AS AvgPrice
FROM Courses
GROUP BY Level
ORDER BY Level;

PRINT '--- [Q26] Enrollments per course (GROUP BY + COUNT) ---';
SELECT c.CourseCode, c.Title, COUNT(e.EnrollmentID) AS Enrollments
FROM Courses c
LEFT JOIN Enrollments e ON e.CourseID = c.CourseID
GROUP BY c.CourseCode, c.Title
ORDER BY Enrollments DESC;

PRINT '--- [Q27] Average grade per assignment (GROUP BY + AVG) ---';
SELECT a.AssignmentID, a.Title,
       COUNT(g.GradeID)                  AS GradedCount,
       CAST(AVG(g.Score) AS DECIMAL(5,2)) AS AvgScore
FROM Assignments a
LEFT JOIN Submissions s ON s.AssignmentID = a.AssignmentID
LEFT JOIN Grades g      ON g.SubmissionID = s.SubmissionID
GROUP BY a.AssignmentID, a.Title
ORDER BY a.AssignmentID;
GO

/* =====================================================================
   PART D — JOIN QUERIES (INNER, multi-table, LEFT, self-join)
   ===================================================================== */

PRINT '--- [Q28] Courses with their instructor and category (3-table INNER/LEFT JOIN) ---';
SELECT c.CourseCode, c.Title, u.FullName AS Instructor, cat.CategoryName
FROM Courses c
JOIN Users u            ON u.UserID = c.InstructorID
LEFT JOIN Categories cat ON cat.CategoryID = c.CategoryID
ORDER BY c.CourseCode;

PRINT '--- [Q29] Student enrollments with course titles (JOIN through junction table) ---';
SELECT u.FullName AS Student, c.Title AS Course, e.Status, e.ProgressPercent
FROM Enrollments e
JOIN Users u   ON u.UserID = e.StudentID
JOIN Courses c ON c.CourseID = e.CourseID
ORDER BY u.FullName, c.Title;

PRINT '--- [Q30] Full grade trail: student -> submission -> grade (multi-JOIN) ---';
SELECT u.FullName AS Student, a.Title AS Assignment, s.Status, g.Score
FROM Submissions s
JOIN Users u       ON u.UserID = s.StudentID
JOIN Assignments a ON a.AssignmentID = s.AssignmentID
LEFT JOIN Grades g ON g.SubmissionID = s.SubmissionID
ORDER BY u.FullName, a.Title;

PRINT '--- [Q31] Modules and their materials (parent-child JOIN) ---';
SELECT c.Title AS Course, mo.Title AS Module, m.Title AS Material, m.MaterialType
FROM Materials m
JOIN Modules mo ON mo.ModuleID = m.ModuleID
JOIN Courses c  ON c.CourseID = mo.CourseID
ORDER BY c.Title, mo.OrderIndex, m.OrderIndex;

PRINT '--- [Q32] Forum posts with author and replied-to author (SELF JOIN) ---';
SELECT t.Title AS Thread,
       au.FullName  AS Author,
       pau.FullName AS ReplyingTo
FROM ForumPosts p
JOIN ForumThreads t ON t.ThreadID = p.ThreadID
JOIN Users au       ON au.UserID = p.UserID
LEFT JOIN ForumPosts parent ON parent.PostID = p.ParentPostID
LEFT JOIN Users pau ON pau.UserID = parent.UserID
ORDER BY t.Title, p.PostID;

PRINT '--- [Q33] Quiz answer key check: answer -> question -> chosen option (JOIN) ---';
SELECT TOP (20)
       sa.SubmissionID, q.QuestionID,
       o.IsCorrect AS ChoseCorrect
FROM StudentAnswers sa
JOIN Questions q       ON q.QuestionID = sa.QuestionID
LEFT JOIN QuestionOptions o ON o.OptionID = sa.SelectedOptionID
ORDER BY sa.SubmissionID, q.QuestionID;
GO

/* =====================================================================
   PART E — GROUP BY ... HAVING
   ===================================================================== */

PRINT '--- [Q34] Courses with MORE THAN 3 enrollments (HAVING) ---';
SELECT c.Title, COUNT(e.EnrollmentID) AS Enrollments
FROM Courses c
JOIN Enrollments e ON e.CourseID = c.CourseID
GROUP BY c.Title
HAVING COUNT(e.EnrollmentID) > 3
ORDER BY Enrollments DESC;

PRINT '--- [Q35] Instructors who own more than one course (HAVING) ---';
SELECT u.FullName, COUNT(c.CourseID) AS Courses
FROM Users u
JOIN Courses c ON c.InstructorID = u.UserID
GROUP BY u.FullName
HAVING COUNT(c.CourseID) > 1
ORDER BY Courses DESC;

PRINT '--- [Q36] Students with average grade >= 80 (HAVING on aggregate) ---';
SELECT u.FullName, CAST(AVG(g.Score) AS DECIMAL(5,2)) AS AvgScore
FROM Users u
JOIN Submissions s ON s.StudentID = u.UserID
JOIN Grades g      ON g.SubmissionID = s.SubmissionID
GROUP BY u.FullName
HAVING AVG(g.Score) >= 80
ORDER BY AvgScore DESC;
GO

/* =====================================================================
   PART F — SUBQUERIES (scalar / in WHERE / in FROM)
   ===================================================================== */

PRINT '--- [Q37] Courses priced above the overall average price (scalar subquery) ---';
SELECT CourseCode, Title, Price
FROM Courses
WHERE Price > (SELECT AVG(Price) FROM Courses)
ORDER BY Price DESC;

PRINT '--- [Q38] Each course with its enrollment count via subquery in SELECT ---';
SELECT c.CourseCode, c.Title,
       (SELECT COUNT(*) FROM Enrollments e WHERE e.CourseID = c.CourseID) AS Enrollments
FROM Courses c
ORDER BY Enrollments DESC;

PRINT '--- [Q39] Top categories by course count (subquery in FROM / derived table) ---';
SELECT t.CategoryName, t.CourseCount
FROM (
    SELECT cat.CategoryName, COUNT(c.CourseID) AS CourseCount
    FROM Categories cat
    LEFT JOIN Courses c ON c.CategoryID = cat.CategoryID
    GROUP BY cat.CategoryName
) AS t
WHERE t.CourseCount > 0
ORDER BY t.CourseCount DESC;
GO

/* =====================================================================
   PART G — NESTED / CORRELATED SUBQUERIES
   ===================================================================== */

PRINT '--- [Q40] Students whose best score beats their course average (correlated) ---';
SELECT DISTINCT u.FullName
FROM Users u
WHERE u.Role = 'Student'
  AND EXISTS (
        SELECT 1
        FROM Submissions s
        JOIN Grades g ON g.SubmissionID = s.SubmissionID
        WHERE s.StudentID = u.UserID
          AND g.Score > (
                SELECT AVG(g2.Score)
                FROM Submissions s2
                JOIN Grades g2 ON g2.SubmissionID = s2.SubmissionID
                WHERE s2.AssignmentID = s.AssignmentID
          )
  )
ORDER BY u.FullName;

PRINT '--- [Q41] Courses where NO assignment has been graded yet (nested NOT EXISTS) ---';
SELECT c.CourseCode, c.Title
FROM Courses c
WHERE NOT EXISTS (
    SELECT 1
    FROM Assignments a
    JOIN Submissions s ON s.AssignmentID = a.AssignmentID
    JOIN Grades g      ON g.SubmissionID = s.SubmissionID
    WHERE a.CourseID = c.CourseID
)
ORDER BY c.CourseCode;

PRINT '--- [Q42] Most-enrolled course per category (nested aggregate subquery) ---';
SELECT cat.CategoryName, c.Title, COUNT(e.EnrollmentID) AS Enrollments
FROM Categories cat
JOIN Courses c     ON c.CategoryID = cat.CategoryID
LEFT JOIN Enrollments e ON e.CourseID = c.CourseID
GROUP BY cat.CategoryID, cat.CategoryName, c.Title, c.CourseID
HAVING COUNT(e.EnrollmentID) = (
    SELECT MAX(cnt.Enrollments)
    FROM (
        SELECT COUNT(e2.EnrollmentID) AS Enrollments
        FROM Courses c2
        LEFT JOIN Enrollments e2 ON e2.CourseID = c2.CourseID
        WHERE c2.CategoryID = cat.CategoryID
        GROUP BY c2.CourseID
    ) AS cnt
)
ORDER BY cat.CategoryName;
GO

/* =====================================================================
   PART H — EXISTS / IN / ANY / ALL
   ===================================================================== */

PRINT '--- [Q43] Students who have at least one certificate (EXISTS) ---';
SELECT u.UserID, u.FullName
FROM Users u
WHERE u.Role = 'Student'
  AND EXISTS (SELECT 1 FROM Certificates c WHERE c.StudentID = u.UserID)
ORDER BY u.FullName;

PRINT '--- [Q44] Courses in the same categories as published courses (IN) ---';
SELECT c.CourseCode, c.Title
FROM Courses c
WHERE c.CategoryID IN (
    SELECT CategoryID FROM Courses WHERE Status = 'Published' AND CategoryID IS NOT NULL
)
ORDER BY c.CourseCode;

PRINT '--- [Q45] Courses more expensive than ANY beginner course (> ANY) ---';
SELECT CourseCode, Title, Price
FROM Courses
WHERE Price > ANY (SELECT Price FROM Courses WHERE Level = 'Beginner')
ORDER BY Price;

PRINT '--- [Q46] Courses at least as expensive as ALL beginner courses (>= ALL) ---';
SELECT CourseCode, Title, Price
FROM Courses
WHERE Price >= ALL (SELECT Price FROM Courses WHERE Level = 'Beginner')
ORDER BY Price DESC;

PRINT '--- [Q47] Users who have NEVER logged an interaction (NOT IN) ---';
SELECT u.UserID, u.FullName
FROM Users u
WHERE u.UserID NOT IN (
    SELECT UserID FROM InteractionLogs WHERE UserID IS NOT NULL
)
ORDER BY u.UserID;
GO

/* =====================================================================
   PART I — SET OPERATIONS (UNION / INTERSECT / EXCEPT)
   ===================================================================== */

PRINT '--- [Q48] Combined contact list of instructors and admins (UNION) ---';
SELECT FullName, 'Instructor' AS Kind FROM Users WHERE Role = 'Instructor'
UNION
SELECT FullName, 'Admin' AS Kind FROM Users WHERE Role = 'Admin'
ORDER BY FullName;

PRINT '--- [Q49] Students who are BOTH enrolled and certified (INTERSECT) ---';
SELECT StudentID FROM Enrollments
INTERSECT
SELECT StudentID FROM Certificates
ORDER BY StudentID;

PRINT '--- [Q50] Students enrolled but with NO submission yet (EXCEPT) ---';
SELECT StudentID FROM Enrollments
EXCEPT
SELECT StudentID FROM Submissions
ORDER BY StudentID;
GO

/* =====================================================================
   PART J — REPORTS / STATISTICS (representative business reports;
   full set in sql/06_reports.sql)
   ===================================================================== */

PRINT '--- [Q51] Course completion-rate report (CASE + aggregate) ---';
SELECT c.Title,
       COUNT(e.EnrollmentID) AS TotalEnroll,
       SUM(CASE WHEN e.Status='Completed' THEN 1 ELSE 0 END) AS Completed,
       CAST(100.0 * SUM(CASE WHEN e.Status='Completed' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(e.EnrollmentID),0) AS DECIMAL(5,2)) AS CompletionRatePct
FROM Courses c
LEFT JOIN Enrollments e ON e.CourseID = c.CourseID
GROUP BY c.Title
ORDER BY CompletionRatePct DESC;

PRINT '--- [Q52] On-time vs late submission report (CASE) ---';
SELECT a.Title,
       COUNT(s.SubmissionID) AS Total,
       SUM(CASE WHEN s.IsLate=0 THEN 1 ELSE 0 END) AS OnTime,
       SUM(CASE WHEN s.IsLate=1 THEN 1 ELSE 0 END) AS Late
FROM Assignments a
LEFT JOIN Submissions s ON s.AssignmentID = a.AssignmentID
GROUP BY a.Title
ORDER BY Total DESC;

PRINT '--- [Q53] Recommendation effectiveness (conversion funnel) ---';
SELECT COUNT(*) AS TotalShown,
       SUM(CASE WHEN Status='Clicked'  THEN 1 ELSE 0 END) AS Clicked,
       SUM(CASE WHEN Status='Enrolled' THEN 1 ELSE 0 END) AS Enrolled,
       CAST(100.0 * SUM(CASE WHEN Status='Enrolled' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS ConversionRatePct
FROM Recommendations;

PRINT '--- [Q54] Daily usage analytics from logs (date grouping) ---';
SELECT CAST(CreatedAt AS DATE) AS [Date],
       COUNT(DISTINCT UserID)  AS ActiveUsers,
       COUNT(*)                AS TotalActions
FROM InteractionLogs
GROUP BY CAST(CreatedAt AS DATE)
ORDER BY [Date];
GO

/* =====================================================================
   PART K — VIEWS (demonstration; defined in 03_functions_views.sql)
   ===================================================================== */

PRINT '--- [Q55] Read view vw_CourseCatalog ---';
SELECT TOP (10) CourseCode, Title, InstructorName, EnrolledStudents, ModuleCount
FROM vw_CourseCatalog
ORDER BY EnrolledStudents DESC;

PRINT '--- [Q56] Read view vw_Gradebook ---';
SELECT TOP (10) CourseTitle, StudentName, AssignmentTitle, Score, SubmissionStatus
FROM vw_Gradebook
ORDER BY CourseTitle, StudentName;
GO

/* =====================================================================
   PART L — FUNCTIONS (demonstration; defined in 03_functions_views.sql)
   Uses a dynamically chosen enrolled (student, course) pair so the demo
   never depends on a hard-coded ID.
   ===================================================================== */

PRINT '--- [Q57..Q60] Scalar functions on a real enrolled pair ---';
DECLARE @sid INT, @cid INT;
SELECT TOP (1) @sid = e.StudentID, @cid = e.CourseID
FROM Enrollments e
JOIN Users u ON u.UserID = e.StudentID AND u.Role = 'Student'
ORDER BY e.EnrollmentID;

IF @sid IS NOT NULL
BEGIN
    SELECT @sid AS StudentID, @cid AS CourseID,
           dbo.fn_CanAccessCourse(@sid, @cid)   AS CanAccess,
           dbo.fn_CourseProgress(@sid, @cid)     AS ProgressPct,
           dbo.fn_CourseFinalGrade(@sid, @cid)   AS FinalGrade,
           dbo.fn_HasPassedCourse(@sid, @cid)    AS HasPassed;

    PRINT '--- [Q61] Table-valued function fn_AccessibleMaterials ---';
    SELECT TOP (10) MaterialID, Title, MaterialType, CourseTitle
    FROM dbo.fn_AccessibleMaterials(@sid);
END
ELSE
    PRINT 'SKIP: no enrolled student found to demonstrate functions.';
GO

/* =====================================================================
   PART M — INDEXES (demonstration; defined in 01_schema.sql)
   ===================================================================== */

PRINT '--- [Q62] List user-defined indexes on the LMS tables ---';
SELECT t.name AS TableName,
       i.name AS IndexName,
       i.type_desc AS IndexType,
       i.is_unique AS IsUnique
FROM sys.indexes i
JOIN sys.tables t ON t.object_id = i.object_id
WHERE i.name IS NOT NULL
  AND t.name IN ('Courses','Enrollments','Submissions','InteractionLogs')
ORDER BY t.name, i.name;
GO

/* =====================================================================
   PART N — STORED PROCEDURES (safe demonstration)
   All EXECs that modify data run inside BEGIN TRANSACTION ... ROLLBACK,
   so the sample data is restored after the demonstration.
   ===================================================================== */

PRINT '--- [Q63] sp_RecommendCourses (writes Recommendations; rolled back) ---';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @recStudent INT =
        (SELECT TOP (1) e.StudentID
         FROM Enrollments e JOIN Users u ON u.UserID=e.StudentID AND u.Role='Student'
         ORDER BY e.StudentID);
    IF @recStudent IS NOT NULL
        EXEC sp_RecommendCourses @StudentID = @recStudent, @TopN = 3;
    ELSE
        PRINT 'SKIP: no student available.';
    ROLLBACK TRANSACTION;
    PRINT 'OK: sp_RecommendCourses demonstrated and rolled back.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'Caught (expected/handled): ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- [Q64] sp_EnrollStudent (writes Enrollments; rolled back) ---';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @s INT, @c INT;
    SELECT TOP (1) @s = u.UserID, @c = c.CourseID
    FROM Users u
    CROSS JOIN Courses c
    WHERE u.Role='Student' AND c.Status='Published'
      AND NOT EXISTS (SELECT 1 FROM Enrollments e WHERE e.StudentID=u.UserID AND e.CourseID=c.CourseID)
    ORDER BY u.UserID, c.CourseID;

    IF @s IS NOT NULL
    BEGIN
        EXEC sp_EnrollStudent @StudentID=@s, @CourseID=@c;
        SELECT @s AS StudentID, @c AS CourseID, 'enrolled (rolled back)' AS Result;
    END
    ELSE
        PRINT 'SKIP: no eligible (student, published course) pair found.';
    ROLLBACK TRANSACTION;
    PRINT 'OK: sp_EnrollStudent demonstrated and rolled back.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'Caught (expected/handled): ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- [Q65] sp_SubmitAssignment + sp_AutoGradeQuiz (writes; rolled back) ---';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @aid INT, @stu INT, @sub INT;
    SELECT TOP (1) @aid = a.AssignmentID, @stu = e.StudentID
    FROM Assignments a
    JOIN Enrollments e ON e.CourseID = a.CourseID AND e.Status IN ('Active','Completed')
    WHERE a.AType IN ('Quiz','Exam')
    ORDER BY a.AssignmentID;

    IF @aid IS NOT NULL
    BEGIN
        EXEC sp_SubmitAssignment @AssignmentID=@aid, @StudentID=@stu,
                                 @ContentURL=N'demo://lab5', @SubmissionID=@sub OUTPUT;
        EXEC sp_AutoGradeQuiz @SubmissionID=@sub;
        SELECT @sub AS SubmissionID, Score FROM Grades WHERE SubmissionID=@sub;
    END
    ELSE
        PRINT 'SKIP: no Quiz/Exam with an enrolled student found.';
    ROLLBACK TRANSACTION;
    PRINT 'OK: submit + auto-grade demonstrated and rolled back.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'Caught (expected/handled): ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- [Q66] sp_IssueCertificate (writes Certificates; rolled back) ---';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @cs INT, @cc INT;
    SELECT TOP (1) @cs = e.StudentID, @cc = e.CourseID
    FROM Enrollments e
    WHERE dbo.fn_HasPassedCourse(e.StudentID, e.CourseID) = 1
      AND NOT EXISTS (SELECT 1 FROM Certificates ct WHERE ct.StudentID=e.StudentID AND ct.CourseID=e.CourseID)
    ORDER BY e.EnrollmentID;

    IF @cs IS NOT NULL
        EXEC sp_IssueCertificate @StudentID=@cs, @CourseID=@cc;
    ELSE
        PRINT 'SKIP: no passing, not-yet-certified (student, course) pair found.';
    ROLLBACK TRANSACTION;
    PRINT 'OK: sp_IssueCertificate demonstrated and rolled back.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'Caught (expected/handled): ' + ERROR_MESSAGE();
END CATCH
GO

/* =====================================================================
   PART O — TRIGGERS (safe demonstration of enforcement)
   Each demo attempts an operation a trigger must BLOCK. The trigger
   rolls back, the error is caught, and we confirm the rule held.
   Full negative-test suite is in sql/07_business_rule_tests.sql.
   ===================================================================== */

PRINT '--- [Q67] trg_Enroll_Validate: a non-Student cannot enroll (expected to fail) ---';
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @nonStudent INT = (SELECT TOP (1) UserID FROM Users WHERE Role='Instructor' ORDER BY UserID);
    DECLARE @anyPub INT     = (SELECT TOP (1) CourseID FROM Courses WHERE Status='Published' ORDER BY CourseID);
    INSERT INTO Enrollments (StudentID, CourseID) VALUES (@nonStudent, @anyPub);
    PRINT 'UNEXPECTED: enrollment succeeded (trigger did not block).';
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'OK (rule enforced): ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- [Q68] trg_StudentAnswers_OptionMatchesQuestion (effect via SELECT) ---';
SELECT COUNT(*) AS MismatchedAnswers
FROM StudentAnswers sa
JOIN QuestionOptions o ON o.OptionID = sa.SelectedOptionID
WHERE sa.SelectedOptionID IS NOT NULL
  AND o.QuestionID <> sa.QuestionID;
GO

PRINT '======================================================================';
PRINT ' LAB 5 QUERY WORKBOOK COMPLETED (read-only / all writes rolled back).';
PRINT '======================================================================';
GO
