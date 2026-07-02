/* =====================================================================
   File 06 - REPORTS / STATISTICS
   The six required analytical reports. Run after sample data is loaded.
   ===================================================================== */
USE LMS;
GO

PRINT '=== REPORT 1: Student performance report (grades & progress) ===';
SELECT  st.UserID                         AS StudentID,
        st.FullName                       AS StudentName,
        c.Title                           AS Course,
        COUNT(DISTINCT a.AssignmentID)    AS TotalAssignments,
        COUNT(DISTINCT g.GradeID)         AS GradedCount,
        CAST(AVG(g.Score) AS DECIMAL(5,2)) AS AvgScore,
        dbo.fn_CourseProgress(st.UserID, c.CourseID) AS ProgressPct,
        e.Status                          AS EnrollStatus
FROM Enrollments e
JOIN Users  st ON st.UserID = e.StudentID
JOIN Courses c ON c.CourseID = e.CourseID
LEFT JOIN Assignments a ON a.CourseID = c.CourseID
LEFT JOIN Submissions s ON s.AssignmentID = a.AssignmentID AND s.StudentID = st.UserID
LEFT JOIN Grades g      ON g.SubmissionID = s.SubmissionID
GROUP BY st.UserID, st.FullName, c.Title, c.CourseID, e.Status
ORDER BY st.FullName, Course;
GO

PRINT '=== REPORT 2: Course enrollment & completion rates ===';
SELECT  c.CourseID,
        c.CourseCode,
        c.Title,
        u.FullName AS Instructor,
        COUNT(e.EnrollmentID)                                       AS TotalEnrollments,
        SUM(CASE WHEN e.Status='Completed' THEN 1 ELSE 0 END)       AS Completed,
        SUM(CASE WHEN e.Status='Dropped'   THEN 1 ELSE 0 END)       AS Dropped,
        CAST(100.0 * SUM(CASE WHEN e.Status='Completed' THEN 1 ELSE 0 END)
             / NULLIF(COUNT(e.EnrollmentID),0) AS DECIMAL(5,2))     AS CompletionRatePct
FROM Courses c
JOIN Users u ON u.UserID = c.InstructorID
LEFT JOIN Enrollments e ON e.CourseID = c.CourseID
GROUP BY c.CourseID, c.CourseCode, c.Title, u.FullName
ORDER BY TotalEnrollments DESC;
GO

PRINT '=== REPORT 3: Instructor activity & course effectiveness ===';
SELECT  u.UserID AS InstructorID,
        u.FullName AS Instructor,
        COUNT(DISTINCT c.CourseID)      AS CoursesOwned,
        COUNT(DISTINCT a.AssignmentID)  AS AssignmentsCreated,
        COUNT(DISTINCT e.StudentID)     AS StudentsTaught,
        CAST(AVG(g.Score) AS DECIMAL(5,2)) AS AvgStudentScore
FROM Users u
LEFT JOIN Courses c     ON c.InstructorID = u.UserID
LEFT JOIN Assignments a ON a.CourseID = c.CourseID
LEFT JOIN Enrollments e ON e.CourseID = c.CourseID
LEFT JOIN Submissions s ON s.AssignmentID = a.AssignmentID
LEFT JOIN Grades g      ON g.SubmissionID = s.SubmissionID
WHERE u.Role = 'Instructor'
GROUP BY u.UserID, u.FullName
ORDER BY StudentsTaught DESC;
GO

PRINT '=== REPORT 4: Assignment submission statistics (on-time vs late) ===';
SELECT  a.AssignmentID,
        a.Title,
        a.AType,
        a.Deadline,
        a.LatePolicy,
        COUNT(s.SubmissionID)                                  AS TotalSubmissions,
        SUM(CASE WHEN s.IsLate=0 THEN 1 ELSE 0 END)            AS OnTime,
        SUM(CASE WHEN s.IsLate=1 THEN 1 ELSE 0 END)            AS Late,
        SUM(CASE WHEN s.Status='Rejected' THEN 1 ELSE 0 END)   AS Rejected,
        CAST(100.0 * SUM(CASE WHEN s.IsLate=0 THEN 1 ELSE 0 END)
             / NULLIF(COUNT(s.SubmissionID),0) AS DECIMAL(5,2)) AS OnTimeRatePct
FROM Assignments a
LEFT JOIN Submissions s ON s.AssignmentID = a.AssignmentID
GROUP BY a.AssignmentID, a.Title, a.AType, a.Deadline, a.LatePolicy
ORDER BY a.AssignmentID;
GO

PRINT '=== REPORT 5: System usage analytics (active users, session duration) ===';
SELECT  CAST(CreatedAt AS DATE)            AS [Date],
        COUNT(DISTINCT UserID)             AS ActiveUsers,
        COUNT(DISTINCT SessionID)          AS Sessions,
        COUNT(*)                           AS TotalActions,
        SUM(ISNULL(DurationSec,0))         AS TotalDurationSec,
        CAST(AVG(CAST(ISNULL(DurationSec,0) AS FLOAT)) AS DECIMAL(8,2)) AS AvgActionSec
FROM InteractionLogs
GROUP BY CAST(CreatedAt AS DATE)
ORDER BY [Date];

SELECT  l.SessionID,
        u.FullName AS [User],
        MIN(l.CreatedAt) AS SessionStart,
        MAX(l.CreatedAt) AS SessionEnd,
        DATEDIFF(SECOND, MIN(l.CreatedAt), MAX(l.CreatedAt)) AS SessionLengthSec
FROM InteractionLogs l
LEFT JOIN Users u ON u.UserID = l.UserID
GROUP BY l.SessionID, u.FullName
ORDER BY SessionStart;
GO

PRINT '=== REPORT 6: Recommendation effectiveness (content-based) ===';
SELECT  COUNT(*)                                                          AS TotalShown,
        SUM(CASE WHEN Status='Clicked'  THEN 1 ELSE 0 END)                AS Clicked,
        SUM(CASE WHEN Status='Enrolled' THEN 1 ELSE 0 END)                AS Enrolled,
        SUM(CASE WHEN Status='Ignored'  THEN 1 ELSE 0 END)                AS Ignored,
        CAST(100.0 * SUM(CASE WHEN Status IN ('Clicked','Enrolled') THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*),0) AS DECIMAL(5,2))                        AS ClickThroughRatePct,
        CAST(100.0 * SUM(CASE WHEN Status='Enrolled' THEN 1 ELSE 0 END)
             / NULLIF(COUNT(*),0) AS DECIMAL(5,2))                        AS ConversionRatePct
FROM Recommendations;

SELECT  c.Title AS RecommendedCourse,
        COUNT(*) AS Times,
        SUM(CASE WHEN r.Status='Enrolled' THEN 1 ELSE 0 END) AS Conversions
FROM Recommendations r
JOIN Courses c ON c.CourseID = r.CourseID
GROUP BY c.Title
ORDER BY Conversions DESC;
GO
