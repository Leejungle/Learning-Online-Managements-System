/* =====================================================================
   File 04 - STORED PROCEDURES
   Transaction-managed operations that keep data consistent.
   ===================================================================== */
USE LMS;
GO

CREATE OR ALTER PROCEDURE sp_EnrollStudent
    @StudentID INT,
    @CourseID  INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM Enrollments WHERE StudentID=@StudentID AND CourseID=@CourseID)
        BEGIN
            RAISERROR('Student is already enrolled in this course.', 16, 1);
        END

        INSERT INTO Enrollments (StudentID, CourseID)
        VALUES (@StudentID, @CourseID);

        UPDATE Recommendations
           SET Status = 'Enrolled'
         WHERE StudentID = @StudentID AND CourseID = @CourseID
           AND Status IN ('Shown','Clicked');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_SubmitAssignment
    @AssignmentID INT,
    @StudentID    INT,
    @ContentURL   NVARCHAR(500) = NULL,
    @SubmissionID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @attempt INT =
            (SELECT ISNULL(MAX(Attempt),0)+1 FROM Submissions
             WHERE AssignmentID=@AssignmentID AND StudentID=@StudentID);

        INSERT INTO Submissions (AssignmentID, StudentID, ContentURL, Attempt)
        VALUES (@AssignmentID, @StudentID, @ContentURL, @attempt);

        SET @SubmissionID = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_GradeSubmission
    @SubmissionID INT,
    @Score        DECIMAL(5,2),
    @Feedback     NVARCHAR(MAX) = NULL,
    @GradedBy     INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Submissions WHERE SubmissionID=@SubmissionID)
            RAISERROR('Submission not found.', 16, 1);

        IF EXISTS (SELECT 1 FROM Grades WHERE SubmissionID=@SubmissionID)
        BEGIN
            UPDATE Grades
               SET Score=@Score, Feedback=@Feedback, GradedBy=@GradedBy, GradedAt=SYSDATETIME()
             WHERE SubmissionID=@SubmissionID;
        END
        ELSE
        BEGIN
            INSERT INTO Grades (SubmissionID, Score, Feedback, GradedBy)
            VALUES (@SubmissionID, @Score, @Feedback, @GradedBy);
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_AutoGradeQuiz
    @SubmissionID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @AssignmentID INT, @MaxScore DECIMAL(5,2), @AType VARCHAR(20);

        IF NOT EXISTS (SELECT 1 FROM Submissions WHERE SubmissionID = @SubmissionID)
            RAISERROR('Submission not found.', 16, 1);

        SELECT @AssignmentID = s.AssignmentID
        FROM Submissions s WHERE s.SubmissionID = @SubmissionID;

        IF NOT EXISTS (SELECT 1 FROM Assignments WHERE AssignmentID = @AssignmentID)
            RAISERROR('Related assignment not found.', 16, 1);

        SELECT @MaxScore = MaxScore, @AType = AType
        FROM Assignments WHERE AssignmentID = @AssignmentID;

        IF @AType NOT IN ('Quiz','Exam')
            RAISERROR('Auto-grading only supports Quiz/Exam assignments.', 16, 1);

        DECLARE @totalPoints DECIMAL(10,2) =
            (SELECT SUM(Points) FROM Questions WHERE AssignmentID=@AssignmentID);

        DECLARE @earned DECIMAL(10,2) =
        (
            SELECT ISNULL(SUM(q.Points),0)
            FROM StudentAnswers sa
            JOIN Questions q       ON q.QuestionID = sa.QuestionID
            JOIN QuestionOptions o ON o.OptionID  = sa.SelectedOptionID
            WHERE sa.SubmissionID = @SubmissionID
              AND o.IsCorrect = 1
        );

        DECLARE @final DECIMAL(5,2) =
            CASE WHEN @totalPoints > 0
                 THEN CAST(@MaxScore * @earned / @totalPoints AS DECIMAL(5,2))
                 ELSE 0 END;

        IF EXISTS (SELECT 1 FROM Grades WHERE SubmissionID=@SubmissionID)
            UPDATE Grades SET Score=@final, GradedBy=NULL,
                   Feedback=N'Auto-graded by system', GradedAt=SYSDATETIME()
             WHERE SubmissionID=@SubmissionID;
        ELSE
            INSERT INTO Grades (SubmissionID, Score, Feedback, GradedBy)
            VALUES (@SubmissionID, @final, N'Auto-graded by system', NULL);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE sp_RecommendCourses
    @StudentID INT,
    @TopN      INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Users WHERE UserID = @StudentID AND Role = 'Student')
    BEGIN
        RAISERROR('Recommendations can only be generated for Student users.', 16, 1);
        RETURN;
    END

    ;WITH MyCategories AS (
        SELECT DISTINCT c.CategoryID
        FROM Enrollments e
        JOIN Courses c ON c.CourseID = e.CourseID
        WHERE e.StudentID = @StudentID AND c.CategoryID IS NOT NULL
    ),
    Candidates AS (
        SELECT  c.CourseID,
                c.CategoryID,
                COUNT(e.EnrollmentID) AS Popularity
        FROM Courses c
        LEFT JOIN Enrollments e ON e.CourseID = c.CourseID
        WHERE c.Status = 'Published'
          AND c.CategoryID IN (SELECT CategoryID FROM MyCategories)
          AND NOT EXISTS (SELECT 1 FROM Enrollments x
                          WHERE x.CourseID = c.CourseID AND x.StudentID = @StudentID)
        GROUP BY c.CourseID, c.CategoryID
    )
    INSERT INTO Recommendations (StudentID, CourseID, Reason, Score, Status)
    SELECT TOP (@TopN)
           @StudentID,
           CourseID,
           N'Similar to categories you study',
           CAST(0.5 + 0.5 * Popularity / (1.0 + Popularity) AS DECIMAL(5,4)),
           'Shown'
    FROM Candidates
    WHERE NOT EXISTS (SELECT 1 FROM Recommendations r
                      WHERE r.StudentID=@StudentID AND r.CourseID=Candidates.CourseID
                        AND r.Status IN ('Shown','Clicked','Enrolled'))
    ORDER BY Popularity DESC;

    SELECT r.RecommendationID, r.CourseID, c.Title, r.Score, r.Reason
    FROM Recommendations r
    JOIN Courses c ON c.CourseID = r.CourseID
    WHERE r.StudentID = @StudentID AND r.Status = 'Shown'
    ORDER BY r.Score DESC;
END
GO

CREATE OR ALTER PROCEDURE sp_IssueCertificate
    @StudentID INT,
    @CourseID  INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Users WHERE UserID=@StudentID AND Role='Student')
            RAISERROR('Only Student users can earn a certificate.', 16, 1);

        IF NOT EXISTS (SELECT 1 FROM Enrollments WHERE StudentID=@StudentID AND CourseID=@CourseID)
            RAISERROR('Student is not enrolled in this course.', 16, 1);

        IF EXISTS (SELECT 1 FROM Certificates WHERE StudentID=@StudentID AND CourseID=@CourseID)
        BEGIN
            COMMIT TRANSACTION;
            SELECT CertificateID, CertificateCode, StudentID, CourseID, FinalScore, IssuedAt
            FROM Certificates WHERE StudentID=@StudentID AND CourseID=@CourseID;
            RETURN;
        END

        DECLARE @final DECIMAL(5,2) = dbo.fn_CourseFinalGrade(@StudentID, @CourseID);

        IF @final IS NULL
            RAISERROR('This course has no graded assignments yet.', 16, 1);

        IF @final < 80.0
        BEGIN
            DECLARE @msg NVARCHAR(200) =
                N'Final score ' + CAST(@final AS VARCHAR(10))
                + N' percent is below the passing threshold of 80 percent.';
            RAISERROR(@msg, 16, 1);
        END

        INSERT INTO Certificates (StudentID, CourseID, FinalScore)
        VALUES (@StudentID, @CourseID, @final);

        UPDATE Enrollments
           SET Status='Completed', ProgressPercent=100, CompletedAt=SYSDATETIME()
         WHERE StudentID=@StudentID AND CourseID=@CourseID;

        COMMIT TRANSACTION;

        SELECT CertificateID, CertificateCode, StudentID, CourseID, FinalScore, IssuedAt
        FROM Certificates WHERE StudentID=@StudentID AND CourseID=@CourseID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

PRINT 'Stored procedures created successfully.';
GO
