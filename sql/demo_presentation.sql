

USE LMS;
GO
PRINT '################ DEMO THUYET TRINH LMS - DBI202 ################';
GO


/* =====================================================================
   MẢNG 1 — SCHEMA, RÀNG BUỘC & CHUẨN HÓA   (Thành viên A)
   ===================================================================== */
PRINT '=== [M1] Danh sach 17 bang trong database ===';
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

PRINT '=== [M1] Tong so bang ===';
SELECT COUNT(*) AS TotalTables
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE';

PRINT '=== [M1] Rang buoc cua bang Users (PK / UNIQUE / CHECK) ===';
SELECT CONSTRAINT_TYPE, CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_NAME = 'Users'
ORDER BY CONSTRAINT_TYPE, CONSTRAINT_NAME;

PRINT '=== [M1] Toan bo quan he khoa ngoai (FK) cua schema ===';
SELECT  fk.name                              AS FK_Name,
        OBJECT_NAME(fk.parent_object_id)     AS FromTable,
        OBJECT_NAME(fk.referenced_object_id) AS ToTable
FROM sys.foreign_keys fk
ORDER BY FromTable, FK_Name;
GO


/* =====================================================================
   MẢNG 2 — TRIGGER & FUNCTION   (Thành viên B)
   ===================================================================== */
DECLARE @sid INT, @cid INT;
SELECT TOP (1) @sid = e.StudentID, @cid = e.CourseID
FROM Enrollments e
WHERE EXISTS (SELECT 1 FROM Assignments a WHERE a.CourseID = e.CourseID)
ORDER BY e.StudentID, e.CourseID;

PRINT '=== [M2] 5 FUNCTION tren mot cap (StudentID, CourseID) ===';
SELECT  @sid AS StudentID, @cid AS CourseID,
        dbo.fn_CanAccessCourse (@sid, @cid) AS CanAccess,
        dbo.fn_CourseProgress  (@sid, @cid) AS ProgressPct,
        dbo.fn_CourseFinalGrade(@sid, @cid) AS FinalGrade,
        dbo.fn_HasPassedCourse (@sid, @cid) AS HasPassed;

PRINT '=== [M2] Table-valued function: hoc lieu sinh vien duoc xem ===';
SELECT TOP (10) MaterialID, Title, MaterialType, CourseTitle
FROM dbo.fn_AccessibleMaterials(@sid);

PRINT '=== [M2] TRIGGER chan: user KHONG phai Student ghi danh (mong doi bi chan) ===';
BEGIN TRY
    BEGIN TRAN;
    DECLARE @nonStu INT = (SELECT TOP (1) UserID FROM Users WHERE Role = 'Instructor' ORDER BY UserID);
    DECLARE @pub    INT = (SELECT TOP (1) CourseID FROM Courses WHERE Status = 'Published' ORDER BY CourseID);
    INSERT INTO Enrollments (StudentID, CourseID) VALUES (@nonStu, @pub);
    PRINT 'KHONG MONG DOI: ghi danh thanh cong (trigger khong chan)';
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    PRINT 'OK - Trigger da chan dung: ' + ERROR_MESSAGE();
END CATCH
GO


/* =====================================================================
   MẢNG 3 — VIEW & STORED PROCEDURE   (mình - kiêm web app)
   ===================================================================== */
PRINT '=== [M3] VIEW vw_CourseCatalog (khoa + GV + so SV + so module) ===';
SELECT TOP (10) CourseCode, Title, InstructorName, EnrolledStudents, ModuleCount
FROM vw_CourseCatalog
ORDER BY EnrolledStudents DESC;

PRINT '=== [M3] VIEW vw_Gradebook (bai chua cham van hien, Score = NULL) ===';
SELECT TOP (10) CourseTitle, StudentName, AssignmentTitle, MaxScore, Score, SubmissionStatus
FROM vw_Gradebook
ORDER BY CourseTitle, StudentName;
GO

PRINT '=== [M3] PROCEDURE sp_RecommendCourses (an toan: ROLLBACK) ===';
BEGIN TRAN;
    DECLARE @s3 INT = (SELECT TOP (1) UserID FROM Users WHERE Role = 'Student' ORDER BY UserID);
    EXEC sp_RecommendCourses @StudentID = @s3, @TopN = 5;
ROLLBACK TRAN;
GO

PRINT '=== [M3] PROCEDURE sp_EnrollStudent (an toan: ROLLBACK) ===';
BEGIN TRAN;
    DECLARE @s4 INT, @c4 INT;
    SELECT TOP (1) @s4 = UserID FROM Users WHERE Role = 'Student' ORDER BY UserID;
    SELECT TOP (1) @c4 = c.CourseID
    FROM Courses c
    WHERE c.Status = 'Published'
      AND NOT EXISTS (SELECT 1 FROM Enrollments e WHERE e.StudentID = @s4 AND e.CourseID = c.CourseID)
    ORDER BY c.CourseID;

    EXEC sp_EnrollStudent @StudentID = @s4, @CourseID = @c4;
    SELECT StudentID, CourseID, Status, EnrollDate
    FROM Enrollments WHERE StudentID = @s4 AND CourseID = @c4;
ROLLBACK TRAN;
GO


/* =====================================================================
   MẢNG 4 — TRUY VẤN SQL & BÁO CÁO   (Thành viên C)
   ===================================================================== */
PRINT '=== [M4] JOIN qua bang trung gian: dang ky cua SV kem ten khoa ===';
SELECT TOP (10) u.FullName AS Student, c.Title AS Course, e.Status
FROM Enrollments e
JOIN Users   u ON u.UserID   = e.StudentID
JOIN Courses c ON c.CourseID = e.CourseID
ORDER BY u.FullName, Course;

PRINT '=== [M4] GROUP BY + HAVING: khoa co hon 3 luot dang ky ===';
SELECT c.Title, COUNT(e.EnrollmentID) AS Enrollments
FROM Courses c JOIN Enrollments e ON e.CourseID = c.CourseID
GROUP BY c.Title
HAVING COUNT(e.EnrollmentID) > 3
ORDER BY Enrollments DESC;

PRINT '=== [M4] Set operation: SV vua dang ky vua co chung chi (INTERSECT) ===';
SELECT StudentID FROM Enrollments
INTERSECT
SELECT StudentID FROM Certificates
ORDER BY StudentID;

PRINT '=== [M4] Bao cao 2: ti le hoan thanh theo khoa ===';
SELECT  c.CourseCode, c.Title,
        COUNT(e.EnrollmentID) AS TotalEnrollments,
        SUM(CASE WHEN e.Status = 'Completed' THEN 1 ELSE 0 END) AS Completed,
        CAST(100.0 * SUM(CASE WHEN e.Status = 'Completed' THEN 1 ELSE 0 END)
             / NULLIF(COUNT(e.EnrollmentID), 0) AS DECIMAL(5,2)) AS CompletionRatePct
FROM Courses c
LEFT JOIN Enrollments e ON e.CourseID = c.CourseID
GROUP BY c.CourseCode, c.Title
ORDER BY TotalEnrollments DESC;

PRINT '=== [M4] Bao cao 4: nop dung han vs tre ===';
SELECT  a.Title, a.AType, a.Deadline,
        COUNT(s.SubmissionID) AS TotalSubmissions,
        SUM(CASE WHEN s.IsLate = 0 THEN 1 ELSE 0 END) AS OnTime,
        SUM(CASE WHEN s.IsLate = 1 THEN 1 ELSE 0 END) AS Late
FROM Assignments a
LEFT JOIN Submissions s ON s.AssignmentID = a.AssignmentID
GROUP BY a.Title, a.AType, a.Deadline
ORDER BY a.Title;

PRINT '>>> De xem DAY DU 6 bao cao: mo va chay file sql/06_reports.sql';
GO

PRINT '################ KET THUC DEMO (khong thay doi du lieu mau) ################';
GO
