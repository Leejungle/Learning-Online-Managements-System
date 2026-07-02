/* =====================================================================
   EVIDENCE - Thong ke so lieu thuc te cua database LMS
   Chay: sqlcmd -S localhost -E -C -d LMS -i docs\evidence\project_data_counts.sql
   Muc dich: doi chieu moi con so trong PROJECT_REVIEW voi du lieu that.
   ===================================================================== */
USE LMS;
GO
SET NOCOUNT ON;

PRINT '=== NGUOI DUNG ===';
SELECT Role, COUNT(*) AS SoLuong FROM Users GROUP BY Role ORDER BY Role;
SELECT COUNT(*) AS TongNguoiDung FROM Users;

PRINT '=== DANH MUC / KHOA HOC ===';
SELECT COUNT(*) AS Categories FROM Categories;
SELECT Status, COUNT(*) AS SoLuong FROM Courses GROUP BY Status ORDER BY Status;
SELECT COUNT(*) AS TongKhoaHoc FROM Courses;

PRINT '=== MODULE / HOC LIEU ===';
SELECT COUNT(*) AS Modules FROM Modules;
SELECT COUNT(*) AS Materials FROM Materials;

PRINT '=== DANG KY (theo trang thai) ===';
SELECT Status, COUNT(*) AS SoLuong FROM Enrollments GROUP BY Status ORDER BY Status;
SELECT COUNT(*) AS TongDangKy FROM Enrollments;

PRINT '=== DANH GIA / CAU HOI ===';
SELECT COUNT(*) AS Assignments FROM Assignments;
SELECT AType, COUNT(*) AS SoLuong FROM Assignments GROUP BY AType ORDER BY AType;
SELECT COUNT(*) AS Questions FROM Questions;
SELECT COUNT(*) AS QuestionOptions FROM QuestionOptions;

PRINT '=== BAI NOP / DIEM ===';
SELECT Status, COUNT(*) AS SoLuong FROM Submissions GROUP BY Status ORDER BY Status;
SELECT COUNT(*) AS TongBaiNop FROM Submissions;
SELECT COUNT(*) AS Grades FROM Grades;
SELECT COUNT(*) AS AutoGraded FROM Grades WHERE GradedBy IS NULL;
SELECT COUNT(*) AS ManualGraded FROM Grades WHERE GradedBy IS NOT NULL;

PRINT '=== CHUNG CHI / GOI Y / NHAT KY ===';
SELECT COUNT(*) AS Certificates FROM Certificates;
SELECT COUNT(*) AS StudentAnswers FROM StudentAnswers;
SELECT Status, COUNT(*) AS SoLuong FROM Recommendations GROUP BY Status ORDER BY Status;
SELECT COUNT(*) AS TongRecommendations FROM Recommendations;
SELECT COUNT(*) AS InteractionLogs FROM InteractionLogs;
SELECT COUNT(*) AS ForumThreads FROM ForumThreads;
SELECT COUNT(*) AS ForumPosts FROM ForumPosts;

PRINT '=== DOI TUONG LAP TRINH TRONG DB ===';
SELECT COUNT(*) AS DML_Triggers FROM sys.triggers WHERE is_ms_shipped = 0 AND parent_class = 1;
SELECT COUNT(*) AS Views FROM sys.views WHERE is_ms_shipped = 0;
SELECT COUNT(*) AS Procedures FROM sys.procedures WHERE is_ms_shipped = 0;
SELECT COUNT(*) AS ScalarFunctions FROM sys.objects WHERE type = 'FN' AND is_ms_shipped = 0;
SELECT COUNT(*) AS InlineTableFunctions FROM sys.objects WHERE type = 'IF' AND is_ms_shipped = 0;
SELECT COUNT(*) AS TotalFunctions FROM sys.objects WHERE type IN ('FN','IF','TF') AND is_ms_shipped = 0;
SELECT COUNT(*) AS BaseTables FROM sys.tables WHERE is_ms_shipped = 0;

PRINT '=== KICH BAN DEMO: chung chi + diem tong ket ===';
SELECT TOP (5) ce.CertificateCode, u.FullName AS Student, c.CourseCode, c.Title, ce.FinalScore
FROM Certificates ce
JOIN Users u   ON u.UserID = ce.StudentID
JOIN Courses c ON c.CourseID = ce.CourseID
ORDER BY ce.CertificateID;
GO
