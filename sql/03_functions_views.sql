/* =====================================================================
   File 03 - FUNCTIONS & VIEWS
   ===================================================================== */
USE LMS;
GO

-------------------------------------------------------------------------
-- FUNCTION: check whether a student can access a course
--           (BR: students can only access courses they are enrolled in)
-------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_CanAccessCourse (@StudentID INT, @CourseID INT)
RETURNS BIT
AS
BEGIN
    DECLARE @ok BIT = 0;
    IF EXISTS (
        SELECT 1 FROM Enrollments
        WHERE StudentID = @StudentID
          AND CourseID  = @CourseID
          AND Status IN ('Active','Completed')
    )
        SET @ok = 1;
    RETURN @ok;
END
GO

-------------------------------------------------------------------------
-- FUNCTION: weighted course progress of a student
--           (ratio of graded assignments over total assignments)
-------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_CourseProgress (@StudentID INT, @CourseID INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @total INT, @done INT;

    SELECT @total = COUNT(*) FROM Assignments WHERE CourseID = @CourseID;

    SELECT @done = COUNT(DISTINCT s.AssignmentID)
    FROM Submissions s
    JOIN Assignments a ON a.AssignmentID = s.AssignmentID
    WHERE a.CourseID = @CourseID
      AND s.StudentID = @StudentID
      AND s.Status = 'Graded';

    IF @total = 0 RETURN 0;
    RETURN CAST(100.0 * @done / @total AS DECIMAL(5,2));
END
GO

-------------------------------------------------------------------------
-- FUNCTION: final course grade of a student (Coursera-style, percent 0..100)
--   = average over ALL graded assignments of the course of
--     (best graded score / MaxScore * 100).
--   A missing or rejected (ungraded) assignment counts as 0, so a learner
--   must actually complete the graded work to reach the passing bar.
--   Returns NULL when the course has no assignments (nothing to grade yet).
-------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_CourseFinalGrade (@StudentID INT, @CourseID INT)
RETURNS DECIMAL(5,2)
AS
BEGIN
    DECLARE @grade DECIMAL(5,2);

    SELECT @grade = CAST(AVG(perAssignment.Pct) AS DECIMAL(5,2))
    FROM (
        SELECT a.AssignmentID,
               ISNULL(MAX(100.0 * g.Score / NULLIF(a.MaxScore, 0)), 0) AS Pct
        FROM Assignments a
        LEFT JOIN Submissions s
               ON s.AssignmentID = a.AssignmentID
              AND s.StudentID    = @StudentID
              AND s.Status       = 'Graded'
        LEFT JOIN Grades g ON g.SubmissionID = s.SubmissionID
        WHERE a.CourseID = @CourseID
        GROUP BY a.AssignmentID
    ) AS perAssignment;

    RETURN @grade;   -- NULL if the course has no assignments
END
GO

-------------------------------------------------------------------------
-- FUNCTION: has the student passed the course? (final grade >= 80%)
--   Returns 1 only when there is a final grade AND it meets the threshold.
-------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_HasPassedCourse (@StudentID INT, @CourseID INT)
RETURNS BIT
AS
BEGIN
    DECLARE @g DECIMAL(5,2) = dbo.fn_CourseFinalGrade(@StudentID, @CourseID);
    RETURN CASE WHEN @g IS NOT NULL AND @g >= 80.0 THEN 1 ELSE 0 END;
END
GO

-------------------------------------------------------------------------
-- TABLE-VALUED FUNCTION: materials a given student is allowed to see
-------------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_AccessibleMaterials (@StudentID INT)
RETURNS TABLE
AS
RETURN
(
    SELECT m.MaterialID, m.Title, m.MaterialType, m.ContentURL,
           c.CourseID, c.Title AS CourseTitle
    FROM Materials m
    JOIN Modules  mo ON mo.ModuleID = m.ModuleID
    JOIN Courses  c  ON c.CourseID  = mo.CourseID
    JOIN Enrollments e ON e.CourseID = c.CourseID
    WHERE e.StudentID = @StudentID
      AND e.Status IN ('Active','Completed')
);
GO

-------------------------------------------------------------------------
-- VIEW: course catalog with instructor & enrollment counts
-------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_CourseCatalog
AS
SELECT  c.CourseID,
        c.CourseCode,
        c.Title,
        c.Level,
        c.Status,
        cat.CategoryName,
        u.FullName             AS InstructorName,
        COUNT(DISTINCT e.StudentID) AS EnrolledStudents,
        COUNT(DISTINCT m.ModuleID)  AS ModuleCount
FROM Courses c
JOIN Users u            ON u.UserID = c.InstructorID
LEFT JOIN Categories cat ON cat.CategoryID = c.CategoryID
LEFT JOIN Enrollments e  ON e.CourseID = c.CourseID
LEFT JOIN Modules m      ON m.CourseID = c.CourseID
GROUP BY c.CourseID, c.CourseCode, c.Title, c.Level, c.Status,
         cat.CategoryName, u.FullName;
GO

-------------------------------------------------------------------------
-- VIEW: gradebook (one row per graded submission)
-------------------------------------------------------------------------
CREATE OR ALTER VIEW vw_Gradebook
AS
SELECT  c.CourseID, c.Title AS CourseTitle,
        st.UserID  AS StudentID, st.FullName AS StudentName,
        a.AssignmentID, a.Title AS AssignmentTitle, a.AType, a.MaxScore,
        s.SubmissionID, s.SubmittedAt, s.IsLate, s.Status AS SubmissionStatus,
        g.Score, g.Feedback, g.GradedAt,
        gb.FullName AS GradedBy
FROM Submissions s
JOIN Assignments a  ON a.AssignmentID = s.AssignmentID
JOIN Courses c      ON c.CourseID = a.CourseID
JOIN Users st       ON st.UserID = s.StudentID
LEFT JOIN Grades g  ON g.SubmissionID = s.SubmissionID
LEFT JOIN Users gb  ON gb.UserID = g.GradedBy;
GO

PRINT 'Functions & views created successfully.';
GO
