/* =====================================================================
   File 02 - TRIGGERS : enforce business rules that simple constraints
                        cannot express.
   ===================================================================== */
USE LMS;
GO

-------------------------------------------------------------------------
-- BR: "Each course must be created and managed by ONE instructor."
--     => The InstructorID of a course must reference a user whose
--        Role = 'Instructor'.
-------------------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Courses_InstructorRole
ON Courses
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Users u ON u.UserID = i.InstructorID
        WHERE u.Role <> 'Instructor'
    )
    BEGIN
        RAISERROR('Business rule violated: a course must be managed by a user with role Instructor.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
GO

-------------------------------------------------------------------------
-- BR: "A student can enroll ... " => the enrolled user must be a Student,
--     and only Published courses can be enrolled.
-------------------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Enroll_Validate
ON Enrollments
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN Users u ON u.UserID = i.StudentID
        WHERE u.Role <> 'Student'
    )
    BEGIN
        RAISERROR('Business rule violated: only users with role Student can enroll.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN Courses c ON c.CourseID = i.CourseID
        WHERE c.Status <> 'Published'
    )
    BEGIN
        RAISERROR('Business rule violated: students can only enroll in Published courses.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
GO

-------------------------------------------------------------------------
-- BR: "Submissions after deadlines may be marked as late or rejected
--      based on policy." + "Each submission must be associated with one
--      student and one assignment" (student must be enrolled in course).
-- This trigger (runs on INSERT and UPDATE, fully set-based / multi-row safe):
--   * blocks submissions from students NOT enrolled in the course
--   * flags IsLate when SubmittedAt > Deadline
--   * sets Status = 'Rejected' when policy = 'RejectLate'
-------------------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Submissions_Policy
ON Submissions
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    -- 1) Student must be enrolled in the course that owns the assignment
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Assignments a ON a.AssignmentID = i.AssignmentID
        LEFT JOIN Enrollments e
               ON e.CourseID = a.CourseID
              AND e.StudentID = i.StudentID
              AND e.Status IN ('Active','Completed')
        WHERE e.EnrollmentID IS NULL
    )
    BEGIN
        RAISERROR('Business rule violated: student is not enrolled in the course of this assignment.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- 2) Late flag
    UPDATE s
       SET s.IsLate = 1
      FROM Submissions s
      JOIN inserted i ON i.SubmissionID = s.SubmissionID
      JOIN Assignments a ON a.AssignmentID = s.AssignmentID
     WHERE s.SubmittedAt > a.Deadline;

    -- 3) Reject late submissions when policy says so
    UPDATE s
       SET s.Status = 'Rejected'
      FROM Submissions s
      JOIN inserted i ON i.SubmissionID = s.SubmissionID
      JOIN Assignments a ON a.AssignmentID = s.AssignmentID
     WHERE s.SubmittedAt > a.Deadline
       AND a.LatePolicy = 'RejectLate';
END
GO

-------------------------------------------------------------------------
-- BR: "Each course must contain at least one learning module or material."
--     We cannot block creating an empty course on INSERT (the first module
--     is added afterwards), so instead we forbid DELETING the last module
--     of a published course.
-------------------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Modules_KeepAtLeastOne
ON Modules
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM deleted d
        JOIN Courses c ON c.CourseID = d.CourseID
        WHERE c.Status = 'Published'
          AND NOT EXISTS (SELECT 1 FROM Modules m WHERE m.CourseID = d.CourseID)
    )
    BEGIN
        RAISERROR('Business rule violated: a published course must keep at least one module.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
GO

-------------------------------------------------------------------------
-- BR: "A course can be Published only if it already has >= 1 module."
--     Runs on INSERT and UPDATE so a course cannot be created directly
--     as 'Published' without a module, nor updated to 'Published'.
-------------------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Courses_PublishNeedsModule
ON Courses
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        WHERE i.Status = 'Published'
          AND NOT EXISTS (SELECT 1 FROM Modules m WHERE m.CourseID = i.CourseID)
    )
    BEGIN
        RAISERROR('Business rule violated: a course needs at least one module before it can be Published.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
GO

-------------------------------------------------------------------------
-- BR: "Grades must be recorded for each evaluated submission."
--     When a grade is inserted, mark its submission as 'Graded'
--     (unless it was Rejected). Keeps Submissions.Status consistent.
-------------------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_Grades_MarkGraded
ON Grades
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- BR: the grader (if any) must be an Instructor or Admin.
    --     GradedBy = NULL is allowed (used by the auto-grading system).
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Users u ON u.UserID = i.GradedBy
        WHERE i.GradedBy IS NOT NULL
          AND u.Role NOT IN ('Instructor','Admin')
    )
    BEGIN
        RAISERROR('Business rule violated: GradedBy must be Instructor or Admin.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Score must not exceed assignment MaxScore (checked before side effects)
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Submissions s ON s.SubmissionID = i.SubmissionID
        JOIN Assignments a ON a.AssignmentID = s.AssignmentID
        WHERE i.Score > a.MaxScore
    )
    BEGIN
        RAISERROR('Invalid grade: score exceeds the assignment MaxScore.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Mark the graded submission as 'Graded' (unless it was Rejected)
    UPDATE s
       SET s.Status = 'Graded'
      FROM Submissions s
      JOIN inserted i ON i.SubmissionID = s.SubmissionID
     WHERE s.Status <> 'Rejected';
END
GO

-------------------------------------------------------------------------
-- BR: a student's selected option must belong to the same question that
--     the answer row points to (data-integrity across StudentAnswers).
--     Runs on INSERT and UPDATE, multi-row safe. NULL option = unanswered.
-------------------------------------------------------------------------
CREATE OR ALTER TRIGGER trg_StudentAnswers_OptionMatchesQuestion
ON StudentAnswers
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN QuestionOptions o ON o.OptionID = i.SelectedOptionID
        WHERE i.SelectedOptionID IS NOT NULL
          AND o.QuestionID <> i.QuestionID
    )
    BEGIN
        RAISERROR('Business rule violated: selected option does not belong to the question.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
GO

PRINT 'Triggers created successfully.';
GO
