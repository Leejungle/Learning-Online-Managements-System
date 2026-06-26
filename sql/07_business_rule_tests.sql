/* =====================================================================
   File 07 - BUSINESS RULE VERIFICATION (negative tests)
   Each block attempts an ILLEGAL operation and expects it to FAIL.
   A PASS message is printed when the rule correctly blocks the action.
   ===================================================================== */
USE LMS;
GO

PRINT '--- TEST 1: duplicate enrollment must fail (UQ_Enroll) ---';
BEGIN TRY
    INSERT INTO Enrollments (StudentID, CourseID) VALUES (5, 1); -- already enrolled
    PRINT '  FAIL: duplicate enrollment was allowed';
END TRY
BEGIN CATCH
    PRINT '  PASS: blocked -> ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST 2: a non-instructor cannot own a course ---';
BEGIN TRY
    INSERT INTO Courses (CourseCode, Title, InstructorID, CategoryID, Status)
    VALUES ('XX999', N'Illegal course', 5 /*a student*/, 1, 'Draft');
    PRINT '  FAIL: student was allowed to own a course';
END TRY
BEGIN CATCH
    PRINT '  PASS: blocked -> ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST 3: enrolling a non-student must fail ---';
BEGIN TRY
    INSERT INTO Enrollments (StudentID, CourseID) VALUES (2 /*instructor*/, 1);
    PRINT '  FAIL: instructor was allowed to enroll';
END TRY
BEGIN CATCH
    PRINT '  PASS: blocked -> ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST 4: invalid role value must fail (CK_Users_Role) ---';
BEGIN TRY
    INSERT INTO Users (Username, PasswordHash, Email, FullName, Role)
    VALUES ('ghost', 'h', 'ghost@lms.edu', N'Ghost', 'SuperUser');
    PRINT '  FAIL: invalid role accepted';
END TRY
BEGIN CATCH
    PRINT '  PASS: blocked -> ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST 5: submission by a non-enrolled student must fail ---';
BEGIN TRY
    DECLARE @sid INT;
    EXEC sp_SubmitAssignment @AssignmentID=1 /*CS101*/, @StudentID=8 /*not in CS101*/,
         @ContentURL=NULL, @SubmissionID=@sid OUTPUT;
    PRINT '  FAIL: non-enrolled student could submit';
END TRY
BEGIN CATCH
    PRINT '  PASS: blocked -> ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST 6: grade above MaxScore must fail ---';
BEGIN TRY
    EXEC sp_GradeSubmission @SubmissionID=1, @Score=99, @Feedback=N'too high', @GradedBy=2;
    PRINT '  FAIL: over-max score accepted';
END TRY
BEGIN CATCH
    PRINT '  PASS: blocked -> ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST 7: publishing a course with no module must fail ---';
BEGIN TRY
    INSERT INTO Courses (CourseCode, Title, InstructorID, CategoryID, Status)
    VALUES ('NM100', N'No-module course', 2, 1, 'Draft');
    DECLARE @cid INT = SCOPE_IDENTITY();
    UPDATE Courses SET Status='Published' WHERE CourseID=@cid;
    PRINT '  FAIL: empty course was published';
    DELETE FROM Courses WHERE CourseID=@cid;
END TRY
BEGIN CATCH
    PRINT '  PASS: blocked -> ' + ERROR_MESSAGE();
    DELETE FROM Courses WHERE CourseCode='NM100';
END CATCH
GO

PRINT '--- TEST 8: manual grade by a Student must fail ---';
BEGIN TRY
    -- SubmissionID 1 exists from sample data; UserID 5 is a Student
    EXEC sp_GradeSubmission @SubmissionID=1, @Score=5, @Feedback=N'illegal grader', @GradedBy=5;
    PRINT '  FAIL: a student was allowed to grade';
END TRY
BEGIN CATCH
    PRINT '  PASS: blocked -> ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST 9: StudentAnswers option from a different question must fail ---';
BEGIN TRY
    DECLARE @sub INT, @q1 INT, @optOfOtherQ INT;

    -- Use student 8 who is enrolled in DB202 (course of the Database Quiz, Assignment 4)
    EXEC sp_SubmitAssignment @AssignmentID=4, @StudentID=8, @ContentURL=NULL, @SubmissionID=@sub OUTPUT;

    -- Q4 belongs to Assignment 4; pick an option that belongs to Q5 (a DIFFERENT question)
    SELECT TOP 1 @q1 = QuestionID FROM Questions WHERE AssignmentID=4 ORDER BY QuestionID;          -- = 4
    SELECT TOP 1 @optOfOtherQ = OptionID FROM QuestionOptions
        WHERE QuestionID <> @q1 AND QuestionID IN (SELECT QuestionID FROM Questions WHERE AssignmentID=4)
        ORDER BY OptionID;                                                                          -- option of Q5

    INSERT INTO StudentAnswers (SubmissionID, QuestionID, SelectedOptionID)
    VALUES (@sub, @q1, @optOfOtherQ);   -- option belongs to another question -> must fail

    PRINT '  FAIL: mismatched option/question was accepted';
END TRY
BEGIN CATCH
    PRINT '  PASS: blocked -> ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST 10: inserting a course directly as Published with no module must fail ---';
BEGIN TRY
    INSERT INTO Courses (CourseCode, Title, InstructorID, CategoryID, Status)
    VALUES ('PUB100', N'Direct published course', 2 /*instructor*/, 1, 'Published');
    PRINT '  FAIL: published course with no module was inserted';
    DELETE FROM Courses WHERE CourseCode='PUB100';
END TRY
BEGIN CATCH
    PRINT '  PASS: blocked -> ' + ERROR_MESSAGE();
    DELETE FROM Courses WHERE CourseCode='PUB100';
END CATCH
GO

PRINT '--- TEST 11: issuing a certificate below 80% must fail ---';
BEGIN TRY
    -- Student 5 in PFP191 (CourseID 1) has not reached the 80% threshold
    EXEC sp_IssueCertificate @StudentID=5, @CourseID=1;
    PRINT '  FAIL: a certificate below 80% was issued';
END TRY
BEGIN CATCH
    PRINT '  PASS: blocked -> ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '--- TEST 12: direct INSERT of a certificate below 80% must fail (CK_Cert_Pass) ---';
BEGIN TRY
    INSERT INTO Certificates (StudentID, CourseID, FinalScore)
    VALUES (6, 3, 55.0);   -- 55% < 80% -> CHECK constraint must block
    PRINT '  FAIL: CHECK constraint did not block sub-80% certificate';
    DELETE FROM Certificates WHERE StudentID=6 AND CourseID=3;
END TRY
BEGIN CATCH
    PRINT '  PASS: blocked -> ' + ERROR_MESSAGE();
END CATCH
GO

PRINT 'Business-rule verification finished.';
GO
