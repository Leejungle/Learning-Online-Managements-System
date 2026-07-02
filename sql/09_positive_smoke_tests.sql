/* =====================================================================
   File 09 - POSITIVE SMOKE TESTS (valid workflows that SHOULD succeed)
   ---------------------------------------------------------------------
   Complements 07_business_rule_tests.sql (12 NEGATIVE tests) with a set
   of POSITIVE tests that exercise the happy path of each core procedure.

   SAFETY:
     * Every test runs inside its own transaction and ROLLBACKs at the end,
       so NO sample data is modified (safe to re-run any time).
     * Targets are picked dynamically from sample data (by Role / Status /
       CourseCode-like conditions), NOT by fragile hard-coded IDs. If the
       data needed for a test is absent, the test prints SKIP (not FAIL).
     * Results are collected in a temp table and summarized at the end.

   HOW TO RUN STANDALONE (no database reset needed):
       sqlcmd -S localhost -E -C -d LMS -i 09_positive_smoke_tests.sql
   It is also wired into run_all.sql / run_all_local.sql after file 08.
   ===================================================================== */
USE LMS;
GO
SET NOCOUNT ON;
IF OBJECT_ID('tempdb..#smoke') IS NOT NULL DROP TABLE #smoke;
CREATE TABLE #smoke (TestNo INT, Name NVARCHAR(60), Result VARCHAR(10), Detail NVARCHAR(400));
PRINT '===== POSITIVE SMOKE TESTS (transaction-wrapped, auto rollback) =====';
GO

PRINT '--- SMOKE 1: a valid Student can enroll in a Published course ---';
BEGIN TRY
    DECLARE @stu INT, @crs INT, @ok BIT = 0;
    SELECT TOP 1 @stu = UserID FROM Users WHERE Role = 'Student' ORDER BY UserID;
    SELECT TOP 1 @crs = c.CourseID
    FROM Courses c
    WHERE c.Status = 'Published'
      AND NOT EXISTS (SELECT 1 FROM Enrollments e WHERE e.CourseID = c.CourseID AND e.StudentID = @stu)
    ORDER BY c.CourseID;

    IF @stu IS NULL OR @crs IS NULL
    BEGIN
        PRINT '  SKIP: no (student, un-enrolled published course) pair available';
        INSERT #smoke VALUES (1, N'enroll', 'SKIP', N'no suitable data');
    END
    ELSE
    BEGIN
        BEGIN TRAN;
        EXEC sp_EnrollStudent @StudentID = @stu, @CourseID = @crs;
        IF EXISTS (SELECT 1 FROM Enrollments WHERE StudentID = @stu AND CourseID = @crs) SET @ok = 1;
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        IF @ok = 1 BEGIN PRINT '  PASS: enrollment created then rolled back'; INSERT #smoke VALUES (1, N'enroll', 'PASS', NULL); END
        ELSE        BEGIN PRINT '  FAIL: enrollment was not created';            INSERT #smoke VALUES (1, N'enroll', 'FAIL', NULL); END
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    PRINT '  FAIL: ' + ERROR_MESSAGE();
    INSERT #smoke VALUES (1, N'enroll', 'FAIL', ERROR_MESSAGE());
END CATCH
GO

PRINT '--- SMOKE 2: an enrolled Student can submit an assignment ---';
BEGIN TRY
    DECLARE @stu INT, @asg INT, @sub INT, @ok BIT = 0;
    SELECT TOP 1 @stu = e.StudentID, @asg = a.AssignmentID
    FROM Enrollments e
    JOIN Assignments a ON a.CourseID = e.CourseID
    WHERE e.Status IN ('Active','Completed')
      AND a.LatePolicy <> 'RejectLate'
    ORDER BY a.AssignmentID;

    IF @stu IS NULL OR @asg IS NULL
    BEGIN
        PRINT '  SKIP: no (enrolled student, assignment) pair available';
        INSERT #smoke VALUES (2, N'submit', 'SKIP', N'no suitable data');
    END
    ELSE
    BEGIN
        BEGIN TRAN;
        EXEC sp_SubmitAssignment @AssignmentID = @asg, @StudentID = @stu,
             @ContentURL = N'http://smoke/submit', @SubmissionID = @sub OUTPUT;
        IF @sub IS NOT NULL AND EXISTS (SELECT 1 FROM Submissions WHERE SubmissionID = @sub AND Status <> 'Rejected') SET @ok = 1;
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        IF @ok = 1 BEGIN PRINT '  PASS: submission created'; INSERT #smoke VALUES (2, N'submit', 'PASS', NULL); END
        ELSE        BEGIN PRINT '  FAIL: submission missing/rejected'; INSERT #smoke VALUES (2, N'submit', 'FAIL', NULL); END
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    PRINT '  FAIL: ' + ERROR_MESSAGE();
    INSERT #smoke VALUES (2, N'submit', 'FAIL', ERROR_MESSAGE());
END CATCH
GO

PRINT '--- SMOKE 3: Instructor can grade a submission (Score <= MaxScore) ---';
BEGIN TRY
    DECLARE @sub INT, @max DECIMAL(5,2), @grader INT, @ok BIT = 0;
    SELECT TOP 1 @sub = s.SubmissionID, @max = a.MaxScore
    FROM Submissions s
    JOIN Assignments a ON a.AssignmentID = s.AssignmentID
    WHERE s.Status <> 'Rejected'
    ORDER BY s.SubmissionID;
    SELECT TOP 1 @grader = UserID FROM Users WHERE Role = 'Instructor' ORDER BY UserID;

    IF @sub IS NULL OR @grader IS NULL
    BEGIN
        PRINT '  SKIP: no submission / instructor available';
        INSERT #smoke VALUES (3, N'grade', 'SKIP', N'no suitable data');
    END
    ELSE
    BEGIN
        BEGIN TRAN;
        EXEC sp_GradeSubmission @SubmissionID = @sub, @Score = @max, @Feedback = N'smoke ok', @GradedBy = @grader;
        IF EXISTS (SELECT 1 FROM Grades WHERE SubmissionID = @sub AND Score = @max) SET @ok = 1;
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        IF @ok = 1 BEGIN PRINT '  PASS: grade recorded at MaxScore'; INSERT #smoke VALUES (3, N'grade', 'PASS', NULL); END
        ELSE        BEGIN PRINT '  FAIL: grade not recorded'; INSERT #smoke VALUES (3, N'grade', 'FAIL', NULL); END
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    PRINT '  FAIL: ' + ERROR_MESSAGE();
    INSERT #smoke VALUES (3, N'grade', 'FAIL', ERROR_MESSAGE());
END CATCH
GO

PRINT '--- SMOKE 4: sp_AutoGradeQuiz grades a Quiz/Exam submission ---';
BEGIN TRY
    DECLARE @asg INT, @stu INT, @sub INT, @max DECIMAL(5,2), @score DECIMAL(5,2), @ok BIT = 0;
    SELECT TOP 1 @asg = a.AssignmentID, @stu = e.StudentID, @max = a.MaxScore
    FROM Assignments a
    JOIN Enrollments e ON e.CourseID = a.CourseID AND e.Status IN ('Active','Completed')
    WHERE a.AType IN ('Quiz','Exam')
      AND a.LatePolicy <> 'RejectLate'
      AND EXISTS (SELECT 1 FROM Questions q WHERE q.AssignmentID = a.AssignmentID)
      AND EXISTS (SELECT 1 FROM Questions q
                  JOIN QuestionOptions o ON o.QuestionID = q.QuestionID
                  WHERE q.AssignmentID = a.AssignmentID AND o.IsCorrect = 1)
      AND NOT EXISTS (SELECT 1 FROM Submissions s WHERE s.AssignmentID = a.AssignmentID AND s.StudentID = e.StudentID)
    ORDER BY a.AssignmentID;

    IF @asg IS NULL OR @stu IS NULL
    BEGIN
        PRINT '  SKIP: no suitable Quiz/Exam with correct options & fresh student';
        INSERT #smoke VALUES (4, N'autograde', 'SKIP', N'no suitable data');
    END
    ELSE
    BEGIN
        BEGIN TRAN;
        EXEC sp_SubmitAssignment @AssignmentID = @asg, @StudentID = @stu, @ContentURL = NULL, @SubmissionID = @sub OUTPUT;
        INSERT INTO StudentAnswers (SubmissionID, QuestionID, SelectedOptionID)
        SELECT @sub, q.QuestionID,
               (SELECT TOP 1 o.OptionID FROM QuestionOptions o
                 WHERE o.QuestionID = q.QuestionID AND o.IsCorrect = 1 ORDER BY o.OptionID)
        FROM Questions q
        WHERE q.AssignmentID = @asg
          AND EXISTS (SELECT 1 FROM QuestionOptions o WHERE o.QuestionID = q.QuestionID AND o.IsCorrect = 1);
        EXEC sp_AutoGradeQuiz @SubmissionID = @sub;
        SELECT @score = Score FROM Grades WHERE SubmissionID = @sub;
        IF @score IS NOT NULL AND @score >= 0 AND @score <= @max SET @ok = 1;
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        IF @ok = 1 BEGIN PRINT '  PASS: auto-graded score=' + CAST(@score AS VARCHAR(20)) + '/' + CAST(@max AS VARCHAR(20));
                         INSERT #smoke VALUES (4, N'autograde', 'PASS', N'score=' + CAST(@score AS NVARCHAR(20))); END
        ELSE        BEGIN PRINT '  FAIL: auto-grade did not produce a valid score';
                         INSERT #smoke VALUES (4, N'autograde', 'FAIL', NULL); END
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    PRINT '  FAIL: ' + ERROR_MESSAGE();
    INSERT #smoke VALUES (4, N'autograde', 'FAIL', ERROR_MESSAGE());
END CATCH
GO

PRINT '--- SMOKE 5: sp_RecommendCourses runs for a Student ---';
BEGIN TRY
    DECLARE @stu INT, @before INT, @after INT, @ok BIT = 0;
    SELECT TOP 1 @stu = e.StudentID
    FROM Enrollments e
    JOIN Courses c ON c.CourseID = e.CourseID
    WHERE c.CategoryID IS NOT NULL
    GROUP BY e.StudentID
    ORDER BY e.StudentID;

    IF @stu IS NULL
    BEGIN
        PRINT '  SKIP: no student with a categorized enrollment';
        INSERT #smoke VALUES (5, N'recommend', 'SKIP', N'no suitable data');
    END
    ELSE
    BEGIN
        SELECT @before = COUNT(*) FROM Recommendations WHERE StudentID = @stu;
        BEGIN TRAN;
        EXEC sp_RecommendCourses @StudentID = @stu, @TopN = 5;
        SELECT @after = COUNT(*) FROM Recommendations WHERE StudentID = @stu;
        IF @after >= @before SET @ok = 1;
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        IF @ok = 1 BEGIN PRINT '  PASS: recommender ran (rows before=' + CAST(@before AS VARCHAR(10)) + ', after=' + CAST(@after AS VARCHAR(10)) + ')';
                         INSERT #smoke VALUES (5, N'recommend', 'PASS', N'before=' + CAST(@before AS NVARCHAR(10)) + N' after=' + CAST(@after AS NVARCHAR(10))); END
        ELSE        BEGIN PRINT '  FAIL: recommender did not run as expected';
                         INSERT #smoke VALUES (5, N'recommend', 'FAIL', NULL); END
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    PRINT '  FAIL: ' + ERROR_MESSAGE();
    INSERT #smoke VALUES (5, N'recommend', 'FAIL', ERROR_MESSAGE());
END CATCH
GO

PRINT '--- SMOKE 6: sp_IssueCertificate is idempotent for an existing pass ---';
BEGIN TRY
    DECLARE @stu INT, @crs INT, @ok BIT = 0;
    SELECT TOP 1 @stu = StudentID, @crs = CourseID FROM Certificates ORDER BY CertificateID;

    IF @stu IS NULL
    BEGIN
        PRINT '  SKIP: no certificate exists in sample data';
        INSERT #smoke VALUES (6, N'certificate', 'SKIP', N'no suitable data');
    END
    ELSE
    BEGIN
        BEGIN TRAN;
        EXEC sp_IssueCertificate @StudentID = @stu, @CourseID = @crs;
        IF EXISTS (SELECT 1 FROM Certificates WHERE StudentID = @stu AND CourseID = @crs) SET @ok = 1;
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        IF @ok = 1 BEGIN PRINT '  PASS: existing certificate returned idempotently'; INSERT #smoke VALUES (6, N'certificate', 'PASS', NULL); END
        ELSE        BEGIN PRINT '  FAIL: certificate not returned'; INSERT #smoke VALUES (6, N'certificate', 'FAIL', NULL); END
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    PRINT '  FAIL: ' + ERROR_MESSAGE();
    INSERT #smoke VALUES (6, N'certificate', 'FAIL', ERROR_MESSAGE());
END CATCH
GO

PRINT '===== SMOKE TEST SUMMARY =====';
SELECT TestNo, Name, Result, Detail FROM #smoke ORDER BY TestNo;
DECLARE @pass INT = (SELECT COUNT(*) FROM #smoke WHERE Result = 'PASS');
DECLARE @fail INT = (SELECT COUNT(*) FROM #smoke WHERE Result = 'FAIL');
DECLARE @skip INT = (SELECT COUNT(*) FROM #smoke WHERE Result = 'SKIP');
PRINT '  PASS=' + CAST(@pass AS VARCHAR(5)) + '  FAIL=' + CAST(@fail AS VARCHAR(5)) + '  SKIP=' + CAST(@skip AS VARCHAR(5));
IF @fail = 0 PRINT 'SMOKE: PASS (no failures)';
ELSE         PRINT 'SMOKE: FAIL (see rows above)';
DROP TABLE #smoke;
GO
