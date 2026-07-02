/* =====================================================================
   File 08 - MORE SAMPLE DATA (enrichment for demo)
   ---------------------------------------------------------------------
   Mục tiêu: tăng dữ liệu để buổi demo có nhiều minh chứng hơn:
     - thêm sinh viên & giảng viên (nhiều người dùng hơn)
     - đăng ký phủ KHẮP các khóa (không còn khóa 0 học viên)
     - thêm bài đánh giá cho nhiều khóa + bài nộp + điểm chấm
     - tạo phân bố ĐẬU / RỚT rõ ràng + cấp chứng chỉ cho người đạt >= 80%

   NGUYÊN TẮC: script này AN TOÀN khi chạy lại (idempotent). Mọi INSERT đều
   có NOT EXISTS / khử trùng lặp, nên KHÔNG cần DROP hay rebuild database.
   Mọi nghiệp vụ vẫn đi qua trigger/constraint/function của DB.

   Chạy SAU 05_sample_data.sql (cần đủ schema + trigger + function + seed gốc).
   ===================================================================== */
USE LMS;
GO
SET NOCOUNT ON;

INSERT INTO Users (Username, PasswordHash, Email, FullName, DateOfBirth, Role)
SELECT v.Username, v.PasswordHash, v.Email, v.FullName, v.DOB, v.Role
FROM (VALUES
    ('sv_n01','hash_n1', 'n01@student.lms.edu', N'Tran Quoc Bao',   '2004-01-11','Student'),
    ('sv_n02','hash_n2', 'n02@student.lms.edu', N'Le Thi Cam',      '2003-02-22','Student'),
    ('sv_n03','hash_n3', 'n03@student.lms.edu', N'Pham Hoang Duc',  '2004-03-30','Student'),
    ('sv_n04','hash_n4', 'n04@student.lms.edu', N'Nguyen Thi Diu',  '2005-04-09','Student'),
    ('sv_n05','hash_n5', 'n05@student.lms.edu', N'Vo Minh Khang',   '2003-05-15','Student'),
    ('sv_n06','hash_n6', 'n06@student.lms.edu', N'Dang Thi Kieu',   '2004-06-18','Student'),
    ('sv_n07','hash_n7', 'n07@student.lms.edu', N'Bui Tan Loc',     '2002-07-27','Student'),
    ('sv_n08','hash_n8', 'n08@student.lms.edu', N'Ho Thi My',       '2004-08-08','Student'),
    ('sv_n09','hash_n9', 'n09@student.lms.edu', N'Phan Van Nam',    '2003-09-19','Student'),
    ('sv_n10','hash_n10','n10@student.lms.edu', N'Truong Thi Oanh', '2005-10-01','Student'),
    ('sv_n11','hash_n11','n11@student.lms.edu', N'Ngo Quang Phu',   '2003-11-12','Student'),
    ('sv_n12','hash_n12','n12@student.lms.edu', N'Ly Thi Quynh',    '2004-12-23','Student'),
    ('sv_n13','hash_n13','n13@student.lms.edu', N'Duong Van Tai',   '2002-01-05','Student'),
    ('sv_n14','hash_n14','n14@student.lms.edu', N'Dinh Thi Uyen',   '2004-02-14','Student'),
    ('sv_n15','hash_n15','n15@student.lms.edu', N'Cao Van Vinh',    '2003-03-26','Student'),
    ('teacher_n01','hash_ti1','teach.n01@lms.edu', N'Mai Xuan Bach',  '1986-06-06','Instructor'),
    ('teacher_n02','hash_ti2','teach.n02@lms.edu', N'Trinh Thu Cuc',  '1990-07-07','Instructor'),
    ('teacher_n03','hash_ti3','teach.n03@lms.edu', N'Hoang Dinh Em',  '1983-08-08','Instructor'),
    ('teacher_n04','hash_ti4','teach.n04@lms.edu', N'Vu Thi Phuong',  '1988-09-09','Instructor')
) AS v(Username, PasswordHash, Email, FullName, DOB, Role)
WHERE NOT EXISTS (SELECT 1 FROM Users u WHERE u.Username = v.Username);
GO
PRINT '08> Users added (students + instructors).';
GO

DECLARE @NS INT = (SELECT COUNT(*) FROM Users WHERE Role = 'Student');

;WITH S AS (
    SELECT UserID, ROW_NUMBER() OVER (ORDER BY UserID) AS rn
    FROM Users WHERE Role = 'Student'
),
C AS (
    SELECT CourseID, ROW_NUMBER() OVER (ORDER BY CourseID) AS cn
    FROM Courses WHERE Status = 'Published'
)
INSERT INTO Enrollments (StudentID, CourseID, EnrollDate, Status, ProgressPercent)
SELECT  S.UserID,
        C.CourseID,
        DATEADD(DAY, -(((S.rn * 3 + C.cn * 7) % 50) + 1), SYSDATETIME()),
        'Active',
        0
FROM C
JOIN S ON ((((S.rn - C.cn) % @NS) + @NS) % @NS) < (4 + (C.cn % 5))
WHERE NOT EXISTS (
    SELECT 1 FROM Enrollments e
    WHERE e.StudentID = S.UserID AND e.CourseID = C.CourseID
);
GO
PRINT '08> Bulk enrollments inserted (every course now has students).';
GO

;WITH Target AS (
    SELECT CourseID FROM Courses
    WHERE CourseCode IN ('DS301','WD110','UX150','ADY201m','AIL303m',
                         'SWE201c','CSD201','MAS291','CPV301','DPL302m')
)
INSERT INTO Assignments (CourseID, Title, Description, AType, MaxScore, Deadline, LatePolicy, PenaltyPct)
SELECT  t.CourseID, x.Title, x.Descr, x.AType, 10, '2026-12-31 23:59', 'AcceptLate', 0
FROM Target t
CROSS JOIN (VALUES
    (N'Course Assignment 1', N'Bai tap thuc hanh cuoi khoa', 'Assignment'),
    (N'Course Quiz 1',       N'Bai kiem tra kien thuc',      'Quiz')
) AS x(Title, Descr, AType)
WHERE NOT EXISTS (
    SELECT 1 FROM Assignments a WHERE a.CourseID = t.CourseID AND a.Title = x.Title
);
GO
PRINT '08> Assignments added for 10 more courses.';
GO

INSERT INTO Submissions (AssignmentID, StudentID, ContentURL, Attempt)
SELECT  a.AssignmentID,
        e.StudentID,
        'https://lms.edu/sub/' + CAST(e.StudentID AS VARCHAR(10)) + '_'
            + CAST(a.AssignmentID AS VARCHAR(10)) + '.zip',
        1
FROM Assignments a
JOIN Courses co     ON co.CourseID = a.CourseID
JOIN Enrollments e  ON e.CourseID = a.CourseID AND e.Status IN ('Active','Completed')
WHERE a.Title IN (N'Course Assignment 1', N'Course Quiz 1')
  AND a.Deadline = '2026-12-31 23:59'
  AND co.CourseCode IN ('DS301','WD110','UX150','ADY201m','AIL303m',
                        'SWE201c','CSD201','MAS291','CPV301','DPL302m')
  AND NOT EXISTS (
        SELECT 1 FROM Submissions s
        WHERE s.AssignmentID = a.AssignmentID AND s.StudentID = e.StudentID AND s.Attempt = 1
  );
GO
PRINT '08> Submissions created for new assignments.';
GO

INSERT INTO Grades (SubmissionID, Score, Feedback, GradedBy)
SELECT  s.SubmissionID,
        CASE
            WHEN ((s.StudentID * 2 + s.AssignmentID) % 10) < 6 THEN 9.0
            WHEN ((s.StudentID * 2 + s.AssignmentID) % 10) < 8 THEN 8.0
            ELSE 6.0
        END,
        N'Cham diem (seed batch 2)',
        co.InstructorID
FROM Submissions s
JOIN Assignments a ON a.AssignmentID = s.AssignmentID
JOIN Courses co    ON co.CourseID = a.CourseID
WHERE a.Title IN (N'Course Assignment 1', N'Course Quiz 1')
  AND a.Deadline = '2026-12-31 23:59'
  AND co.CourseCode IN ('DS301','WD110','UX150','ADY201m','AIL303m',
                        'SWE201c','CSD201','MAS291','CPV301','DPL302m')
  AND s.Status = 'Submitted'
  AND NOT EXISTS (SELECT 1 FROM Grades g WHERE g.SubmissionID = s.SubmissionID);
GO
PRINT '08> Grades recorded (pass/fail spread).';
GO

INSERT INTO Certificates (StudentID, CourseID, FinalScore)
SELECT  e.StudentID, e.CourseID, dbo.fn_CourseFinalGrade(e.StudentID, e.CourseID)
FROM Enrollments e
WHERE dbo.fn_HasPassedCourse(e.StudentID, e.CourseID) = 1
  AND NOT EXISTS (
        SELECT 1 FROM Certificates c
        WHERE c.StudentID = e.StudentID AND c.CourseID = e.CourseID
  );
GO

UPDATE e
   SET Status = 'Completed', ProgressPercent = 100, CompletedAt = SYSDATETIME()
FROM Enrollments e
WHERE e.Status = 'Active'
  AND dbo.fn_HasPassedCourse(e.StudentID, e.CourseID) = 1;
GO

UPDATE e
   SET Status = 'Dropped'
FROM Enrollments e
WHERE e.Status = 'Active'
  AND dbo.fn_CourseFinalGrade(e.StudentID, e.CourseID) IS NOT NULL
  AND dbo.fn_HasPassedCourse(e.StudentID, e.CourseID) = 0
  AND ((e.StudentID + e.CourseID) % 3) = 0;
GO
PRINT '08> Certificates issued; completions & drops updated.';
GO

DECLARE @r1 INT = (SELECT UserID FROM Users WHERE Username = 'sv_n01');
DECLARE @r2 INT = (SELECT UserID FROM Users WHERE Username = 'sv_n05');
DECLARE @r3 INT = (SELECT UserID FROM Users WHERE Username = 'sv_n09');
DECLARE @r4 INT = (SELECT UserID FROM Users WHERE Username = 'sv_n12');

IF @r1 IS NOT NULL EXEC sp_RecommendCourses @StudentID=@r1, @TopN=3;
IF @r2 IS NOT NULL EXEC sp_RecommendCourses @StudentID=@r2, @TopN=3;
IF @r3 IS NOT NULL EXEC sp_RecommendCourses @StudentID=@r3, @TopN=3;
IF @r4 IS NOT NULL EXEC sp_RecommendCourses @StudentID=@r4, @TopN=3;
GO

UPDATE TOP (3) Recommendations SET Status='Clicked'
WHERE Status='Shown' AND StudentID IN (SELECT UserID FROM Users WHERE Username IN ('sv_n01','sv_n05'));
UPDATE TOP (2) Recommendations SET Status='Ignored'
WHERE Status='Shown' AND StudentID IN (SELECT UserID FROM Users WHERE Username IN ('sv_n09','sv_n12'));
GO
PRINT '08> Recommendations generated & simulated.';
GO

IF NOT EXISTS (SELECT 1 FROM InteractionLogs
               WHERE CreatedAt >= '2026-06-22' AND CreatedAt < '2026-06-27')
BEGIN
    DECLARE @sa UNIQUEIDENTIFIER = NEWID(), @sb UNIQUEIDENTIFIER = NEWID(),
            @sc UNIQUEIDENTIFIER = NEWID(), @sd UNIQUEIDENTIFIER = NEWID(),
            @se UNIQUEIDENTIFIER = NEWID();
    DECLARE @u1 INT = (SELECT UserID FROM Users WHERE Username='sv_n01');
    DECLARE @u2 INT = (SELECT UserID FROM Users WHERE Username='sv_n05');
    DECLARE @u3 INT = (SELECT UserID FROM Users WHERE Username='sv_n09');
    DECLARE @u4 INT = (SELECT UserID FROM Users WHERE Username='sv_n12');

    INSERT INTO InteractionLogs (UserID, SessionID, ActionType, EntityType, EntityID, DurationSec, CreatedAt) VALUES
    (@u1, @sa, 'Login',        NULL,         NULL, NULL, '2026-06-22 08:00'),
    (@u1, @sa, 'ViewMaterial', 'Material',   1,    180,  '2026-06-22 08:03'),
    (@u1, @sa, 'Submit',       'Assignment', 1,    240,  '2026-06-22 08:30'),
    (@u2, @sb, 'Login',        NULL,         NULL, NULL, '2026-06-23 14:00'),
    (@u2, @sb, 'ViewMaterial', 'Material',   2,    260,  '2026-06-23 14:05'),
    (@u3, @sc, 'Login',        NULL,         NULL, NULL, '2026-06-24 19:30'),
    (@u3, @sc, 'ViewMaterial', 'Material',   3,    150,  '2026-06-24 19:33'),
    (@u3, @sc, 'Submit',       'Assignment', 3,    300,  '2026-06-24 20:00'),
    (@u4, @sd, 'Login',        NULL,         NULL, NULL, '2026-06-25 09:15'),
    (@u4, @sd, 'ViewMaterial', 'Material',   4,    210,  '2026-06-25 09:20'),
    (@u1, @se, 'Login',        NULL,         NULL, NULL, '2026-06-26 21:00'),
    (@u1, @se, 'ViewMaterial', 'Material',   5,    195,  '2026-06-26 21:04');
END
GO
PRINT '08> Interaction logs added.';
GO

PRINT 'File 08 - more sample data inserted successfully.';
GO
