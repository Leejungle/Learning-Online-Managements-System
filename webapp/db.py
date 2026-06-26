"""
Lớp truy cập dữ liệu cho web app demo LMS.

Nguyên tắc:
- SQL Server là source of truth. App CHỈ đọc + gọi stored procedure/view/function
  có sẵn, KHÔNG bao giờ chạy DDL (CREATE/DROP/ALTER) hay sửa schema.
- Luôn dùng parameterized query (truyền tham số qua '?'), tránh SQL injection.
- Kết nối bằng Windows Authentication (Trusted_Connection=yes) vì SQL Server
  đang ở chế độ chỉ Windows Auth.
"""

import os
import re
import pyodbc
from dotenv import load_dotenv

# Tắt ODBC connection pooling.
# Lý do: SQL Server dùng Windows Integrated Auth (Trusted_Connection). Khi bật
# pooling (mặc định), một kết nối vật lý bị tái dùng sau khi giao dịch trong
# stored procedure bị ROLLBACK/THROW có thể khiến lần handshake SSPI kế tiếp
# thất bại ngắt quãng ("Login failed for user ..."). Tắt pooling -> mỗi lần
# kết nối là mới, ổn định cho demo. Phải đặt TRƯỚC mọi pyodbc.connect().
pyodbc.pooling = False

load_dotenv()

DB_DRIVER = os.getenv("DB_DRIVER", "ODBC Driver 18 for SQL Server")
DB_SERVER = os.getenv("DB_SERVER", "localhost")
DB_NAME = os.getenv("DB_NAME", "LMS")
DB_TRUSTED_CONNECTION = os.getenv("DB_TRUSTED_CONNECTION", "yes")
DB_TRUST_SERVER_CERTIFICATE = os.getenv("DB_TRUST_SERVER_CERTIFICATE", "yes")


def get_connection_string() -> str:
    """Dựng chuỗi kết nối ODBC từ biến môi trường."""
    return (
        f"Driver={{{DB_DRIVER}}};"
        f"Server={DB_SERVER};"
        f"Database={DB_NAME};"
        f"Trusted_Connection={DB_TRUSTED_CONNECTION};"
        f"TrustServerCertificate={DB_TRUST_SERVER_CERTIFICATE};"
    )


def get_connection():
    """Mở một kết nối mới tới SQL Server."""
    return pyodbc.connect(get_connection_string())


def _rows_to_dicts(cursor):
    """Chuyển kết quả cursor hiện tại thành list[dict] (key = tên cột)."""
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


def query_all(sql: str, params: tuple = ()):
    """Chạy 1 câu SELECT, trả về list[dict]."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(sql, params)
        return _rows_to_dicts(cursor)


def query_one(sql: str, params: tuple = ()):
    """Chạy 1 câu SELECT, trả về 1 dict (hàng đầu tiên) hoặc None."""
    rows = query_all(sql, params)
    return rows[0] if rows else None


def query_scalar(sql: str, params: tuple = ()):
    """Chạy 1 câu SELECT, trả về 1 giá trị đơn (ô đầu tiên) hoặc None."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(sql, params)
        row = cursor.fetchone()
        return row[0] if row else None


def sql_error_message(exc: Exception) -> str:
    """
    Trích message nghiệp vụ "sạch" từ lỗi pyodbc (do RAISERROR/THROW trong
    trigger/procedure ném ra) để hiển thị nguyên văn cho người dùng.
    Ví dụ chuỗi gốc:
      ('42000', "[42000] [Microsoft][ODBC Driver 18 ...][SQL Server]
       Business rule violated: only users with role Student can enroll. (50000) ...")
    -> trả về: "Business rule violated: only users with role Student can enroll."
    """
    raw = str(exc)
    # Lấy các đoạn dạng  ]<message> (mã_số)  rồi bỏ phần "[SQL Server]" prefix.
    matches = re.findall(r"\]([^\[\]]+?)\s*\((?:\d+)\)", raw)
    candidates = [m.strip() for m in matches if m.strip()]
    # Ưu tiên đoạn chứa thông điệp nghiệp vụ, nếu không lấy đoạn cuối cùng.
    for c in candidates:
        if "Business rule" in c or "Invalid" in c or "already enrolled" in c:
            return c
    if candidates:
        return candidates[-1]
    return raw


# =====================================================================
# Truy vấn nghiệp vụ (chỉ đọc) - tập trung tại đây để dễ rà soát.
# Tất cả đều parameterized.
# =====================================================================

def get_all_users():
    """Danh sách user cho 'demo user selector' (sắp theo role rồi tên)."""
    return query_all(
        """
        SELECT UserID, FullName, Role, Username, Email
        FROM Users
        ORDER BY CASE Role
                     WHEN 'Student'    THEN 1
                     WHEN 'Instructor' THEN 2
                     WHEN 'Admin'      THEN 3
                     ELSE 4 END,
                 FullName;
        """
    )


def get_user(user_id: int):
    """Lấy 1 user theo ID (dùng để xác thực lựa chọn trong selector)."""
    return query_one(
        "SELECT UserID, FullName, Role, Username, Email FROM Users WHERE UserID = ?;",
        (user_id,),
    )


def get_catalog_categories():
    """Các category đang có khóa học (cho dropdown lọc của catalog)."""
    return query_all(
        """
        SELECT DISTINCT CategoryName
        FROM vw_CourseCatalog
        WHERE CategoryName IS NOT NULL
        ORDER BY CategoryName;
        """
    )


def get_course_catalog(search=None, level=None, category=None, status=None):
    """
    Đọc danh mục khóa học từ vw_CourseCatalog, có lọc tùy chọn.
    Mọi điều kiện đều dùng tham số '?' để tránh SQL injection.
    """
    sql = ["SELECT CourseID, CourseCode, Title, Level, Status, CategoryName,",
           "       InstructorName, EnrolledStudents, ModuleCount",
           "FROM vw_CourseCatalog",
           "WHERE 1 = 1"]
    params = []

    if search:
        sql.append("AND (Title LIKE ? OR CourseCode LIKE ?)")
        like = f"%{search}%"
        params.extend([like, like])
    if level:
        sql.append("AND Level = ?")
        params.append(level)
    if category:
        sql.append("AND CategoryName = ?")
        params.append(category)
    if status:
        sql.append("AND Status = ?")
        params.append(status)

    sql.append("ORDER BY CourseCode;")
    return query_all("\n".join(sql), tuple(params))


# ---------------------------------------------------------------------
# Phase 2: Course detail (modules/materials) + Student dashboard
# ---------------------------------------------------------------------

def get_course_header(course_id: int):
    """
    Thông tin tổng quan 1 khóa học cho trang chi tiết.
    Tái dùng view vw_CourseCatalog (sĩ số, số module, GV, category) và lấy
    thêm Description từ bảng Courses (view không chứa cột này).
    """
    return query_one(
        """
        SELECT v.CourseID, v.CourseCode, v.Title, v.Level, v.Status,
               v.CategoryName, v.InstructorName, v.EnrolledStudents, v.ModuleCount,
               c.Description
        FROM vw_CourseCatalog v
        JOIN Courses c ON c.CourseID = v.CourseID
        WHERE v.CourseID = ?;
        """,
        (course_id,),
    )


def get_course_modules(course_id: int):
    """
    Outline khóa học: danh sách Module, mỗi module kèm Materials của nó.
    Đọc thẳng từ bảng Modules LEFT JOIN Materials theo CourseID, rồi gom
    nhóm theo module trong Python (giữ thứ tự OrderIndex).
    """
    rows = query_all(
        """
        SELECT m.ModuleID,
               m.Title       AS ModuleTitle,
               m.OrderIndex  AS ModuleOrder,
               mat.MaterialID,
               mat.Title        AS MaterialTitle,
               mat.MaterialType AS MaterialType,
               mat.ContentURL   AS ContentURL,
               mat.OrderIndex   AS MaterialOrder
        FROM Modules m
        LEFT JOIN Materials mat ON mat.ModuleID = m.ModuleID
        WHERE m.CourseID = ?
        ORDER BY m.OrderIndex, mat.OrderIndex;
        """,
        (course_id,),
    )

    modules = []
    by_id = {}
    for r in rows:
        mid = r["ModuleID"]
        module = by_id.get(mid)
        if module is None:
            module = {
                "ModuleID": mid,
                "ModuleTitle": r["ModuleTitle"],
                "ModuleOrder": r["ModuleOrder"],
                "materials": [],
            }
            by_id[mid] = module
            modules.append(module)
        if r["MaterialID"] is not None:
            module["materials"].append(
                {
                    "MaterialID": r["MaterialID"],
                    "Title": r["MaterialTitle"],
                    "MaterialType": r["MaterialType"],
                    "ContentURL": r["ContentURL"],
                }
            )
    return modules


def can_access_course(student_id: int, course_id: int) -> bool:
    """
    Học viên có quyền xem học liệu của khóa không (BR: chỉ khi đã đăng ký).
    Dùng function dbo.fn_CanAccessCourse trả BIT (1/0).
    """
    result = query_scalar(
        "SELECT dbo.fn_CanAccessCourse(?, ?);", (student_id, course_id)
    )
    return bool(result)


def get_student_grades(student_id: int):
    """Bảng điểm của 1 sinh viên, đọc từ view vw_Gradebook."""
    return query_all(
        """
        SELECT CourseID, CourseTitle, AssignmentTitle, AType, MaxScore,
               SubmittedAt, IsLate, SubmissionStatus, Score, Feedback,
               GradedAt, GradedBy
        FROM vw_Gradebook
        WHERE StudentID = ?
        ORDER BY CourseTitle, AssignmentTitle;
        """,
        (student_id,),
    )


def get_student_progress(student_id: int):
    """
    Tiến độ theo từng khóa SV đã đăng ký (liệt kê theo bảng Enrollments).
    Tiến độ lấy DUY NHẤT từ function fn_CourseProgress (không dùng cột
    Enrollments.ProgressPercent để tránh lệch số khi demo).
    Kèm trạng thái enrollment để hiển thị cạnh thẻ tiến độ.
    """
    return query_all(
        """
        SELECT e.CourseID,
               c.CourseCode,
               c.Title             AS CourseTitle,
               e.Status            AS EnrollmentStatus,
               e.EnrollDate,
               dbo.fn_CourseProgress(e.StudentID, e.CourseID) AS ProgressPct
        FROM Enrollments e
        JOIN Courses c ON c.CourseID = e.CourseID
        WHERE e.StudentID = ?
        ORDER BY c.CourseCode;
        """,
        (student_id,),
    )


# ---------------------------------------------------------------------
# Phase 3: Reports / Statistics
# Mỗi hàm dưới đây = ĐÚNG 1 câu SELECT trong sql/06_reports.sql (read-only).
# File 06_reports.sql có nhiều result set (report 5 & 6 mỗi cái 2 SELECT),
# nên ở đây tách thành từng hàm riêng để web chạy độc lập từng truy vấn.
# Không nhận tham số từ người dùng -> không có rủi ro injection.
# ---------------------------------------------------------------------

def report_student_performance():
    """Report 1: Học lực sinh viên (điểm & tiến độ) - dùng fn_CourseProgress."""
    return query_all(
        """
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
        """
    )


def report_course_completion():
    """Report 2: Tỷ lệ đăng ký & hoàn thành theo khóa."""
    return query_all(
        """
        SELECT  c.CourseID,
                c.CourseCode,
                c.Title,
                u.FullName AS Instructor,
                COUNT(e.EnrollmentID)                                  AS TotalEnrollments,
                SUM(CASE WHEN e.Status='Completed' THEN 1 ELSE 0 END)  AS Completed,
                SUM(CASE WHEN e.Status='Dropped'   THEN 1 ELSE 0 END)  AS Dropped,
                CAST(100.0 * SUM(CASE WHEN e.Status='Completed' THEN 1 ELSE 0 END)
                     / NULLIF(COUNT(e.EnrollmentID),0) AS DECIMAL(5,2)) AS CompletionRatePct
        FROM Courses c
        JOIN Users u ON u.UserID = c.InstructorID
        LEFT JOIN Enrollments e ON e.CourseID = c.CourseID
        GROUP BY c.CourseID, c.CourseCode, c.Title, u.FullName
        ORDER BY TotalEnrollments DESC;
        """
    )


def report_instructor_activity():
    """Report 3: Hoạt động giảng viên & hiệu quả khóa học."""
    return query_all(
        """
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
        """
    )


def report_assignment_submission():
    """Report 4: Thống kê nộp bài (đúng hạn vs trễ)."""
    return query_all(
        """
        SELECT  a.AssignmentID,
                a.Title,
                a.AType,
                a.Deadline,
                a.LatePolicy,
                COUNT(s.SubmissionID)                                AS TotalSubmissions,
                SUM(CASE WHEN s.IsLate=0 THEN 1 ELSE 0 END)          AS OnTime,
                SUM(CASE WHEN s.IsLate=1 THEN 1 ELSE 0 END)          AS Late,
                SUM(CASE WHEN s.Status='Rejected' THEN 1 ELSE 0 END) AS Rejected,
                CAST(100.0 * SUM(CASE WHEN s.IsLate=0 THEN 1 ELSE 0 END)
                     / NULLIF(COUNT(s.SubmissionID),0) AS DECIMAL(5,2)) AS OnTimeRatePct
        FROM Assignments a
        LEFT JOIN Submissions s ON s.AssignmentID = a.AssignmentID
        GROUP BY a.AssignmentID, a.Title, a.AType, a.Deadline, a.LatePolicy
        ORDER BY a.AssignmentID;
        """
    )


def report_usage_daily():
    """Report 5 (phần 1): Phân tích sử dụng hệ thống theo ngày."""
    return query_all(
        """
        SELECT  CAST(CreatedAt AS DATE)            AS [Date],
                COUNT(DISTINCT UserID)             AS ActiveUsers,
                COUNT(DISTINCT SessionID)          AS Sessions,
                COUNT(*)                           AS TotalActions,
                SUM(ISNULL(DurationSec,0))         AS TotalDurationSec,
                CAST(AVG(CAST(ISNULL(DurationSec,0) AS FLOAT)) AS DECIMAL(8,2)) AS AvgActionSec
        FROM InteractionLogs
        GROUP BY CAST(CreatedAt AS DATE)
        ORDER BY [Date];
        """
    )


def report_usage_sessions():
    """Report 5 (phần 2): Thời lượng từng phiên."""
    return query_all(
        """
        SELECT  l.SessionID,
                u.FullName AS [User],
                MIN(l.CreatedAt) AS SessionStart,
                MAX(l.CreatedAt) AS SessionEnd,
                DATEDIFF(SECOND, MIN(l.CreatedAt), MAX(l.CreatedAt)) AS SessionLengthSec
        FROM InteractionLogs l
        LEFT JOIN Users u ON u.UserID = l.UserID
        GROUP BY l.SessionID, u.FullName
        ORDER BY SessionStart;
        """
    )


def report_recommendation_overall():
    """Report 6 (phần 1): Hiệu quả gợi ý AI - tổng quan (1 dòng)."""
    return query_one(
        """
        SELECT  COUNT(*)                                                AS TotalShown,
                SUM(CASE WHEN Status='Clicked'  THEN 1 ELSE 0 END)      AS Clicked,
                SUM(CASE WHEN Status='Enrolled' THEN 1 ELSE 0 END)      AS Enrolled,
                SUM(CASE WHEN Status='Ignored'  THEN 1 ELSE 0 END)      AS Ignored,
                CAST(100.0 * SUM(CASE WHEN Status IN ('Clicked','Enrolled') THEN 1 ELSE 0 END)
                     / NULLIF(COUNT(*),0) AS DECIMAL(5,2))              AS ClickThroughRatePct,
                CAST(100.0 * SUM(CASE WHEN Status='Enrolled' THEN 1 ELSE 0 END)
                     / NULLIF(COUNT(*),0) AS DECIMAL(5,2))              AS ConversionRatePct
        FROM Recommendations;
        """
    )


def report_recommendation_by_course():
    """Report 6 (phần 2): Hiệu quả gợi ý AI theo khóa học."""
    return query_all(
        """
        SELECT  c.Title AS RecommendedCourse,
                COUNT(*) AS Times,
                SUM(CASE WHEN r.Status='Enrolled' THEN 1 ELSE 0 END) AS Conversions
        FROM Recommendations r
        JOIN Courses c ON c.CourseID = r.CourseID
        GROUP BY c.Title
        ORDER BY Conversions DESC;
        """
    )


# ---------------------------------------------------------------------
# Phase 4: Actions (GHI DB) - gọi stored procedure có sẵn.
# Quan trọng: KHÔNG nuốt lỗi. Nếu trigger/procedure RAISERROR/THROW thì để
# pyodbc raise lên cho route bắt và hiển thị nguyên văn message (qua
# sql_error_message). Mỗi procedure tự quản transaction (BEGIN TRAN/ROLLBACK).
# ---------------------------------------------------------------------

def enroll_student(student_id: int, course_id: int):
    """
    Đăng ký 1 sinh viên vào 1 khóa học bằng procedure sp_EnrollStudent.
    Có thể raise pyodbc.Error nếu vi phạm quy tắc (vd: đã đăng ký, không phải
    Student, khóa chưa Published) -> route sẽ hiển thị message.
    """
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("EXEC sp_EnrollStudent ?, ?", (student_id, course_id))
        conn.commit()


def recommend_courses(student_id: int, top_n: int = 5):
    """
    Gọi sp_RecommendCourses: vừa SINH gợi ý (INSERT) vừa trả về danh sách
    gợi ý 'Shown'. Trả về list[dict]. Có thể raise nếu user không phải Student.
    """
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("EXEC sp_RecommendCourses ?, ?", (student_id, top_n))
        rows = _rows_to_dicts(cursor) if cursor.description else []
        conn.commit()
        return rows


def get_recommendations(student_id: int):
    """Đọc các gợi ý đã lưu cho 1 sinh viên (để hiển thị trang Recommendations)."""
    return query_all(
        """
        SELECT  r.RecommendationID,
                r.CourseID,
                c.CourseCode,
                c.Title,
                r.Reason,
                r.Score,
                r.Status,
                r.CreatedAt
        FROM Recommendations r
        JOIN Courses c ON c.CourseID = r.CourseID
        WHERE r.StudentID = ?
        ORDER BY r.Status, r.Score DESC;
        """,
        (student_id,),
    )


def get_courses_brief():
    """Danh sách khóa học gọn cho dropdown showcase (gồm cả Status)."""
    return query_all(
        """
        SELECT CourseID, CourseCode, Title, Status
        FROM Courses
        ORDER BY CourseCode;
        """
    )


# ---------------------------------------------------------------------
# Phase 5: Submission (sp_SubmitAssignment, OUTPUT param), Grading
# (sp_GradeSubmission), Forum (ForumThreads/ForumPosts).
# ---------------------------------------------------------------------

def get_course_assignments(course_id: int, student_id=None):
    """
    Danh sách bài đánh giá của 1 khóa, kèm bài nộp MỚI NHẤT của sinh viên
    (nếu có) và điểm. student_id=None -> không gắn bài nộp (xem read-only).
    """
    return query_all(
        """
        SELECT a.AssignmentID, a.Title, a.AType, a.MaxScore, a.Deadline, a.LatePolicy,
               sub.SubmissionID, sub.Status AS SubStatus, sub.IsLate, sub.SubmittedAt,
               g.Score
        FROM Assignments a
        OUTER APPLY (
            SELECT TOP 1 s.SubmissionID, s.Status, s.IsLate, s.SubmittedAt
            FROM Submissions s
            WHERE s.AssignmentID = a.AssignmentID AND s.StudentID = ?
            ORDER BY s.Attempt DESC
        ) sub
        LEFT JOIN Grades g ON g.SubmissionID = sub.SubmissionID
        WHERE a.CourseID = ?
        ORDER BY a.AssignmentID;
        """,
        (student_id, course_id),
    )


def submit_assignment(assignment_id: int, student_id: int, content_url=None):
    """
    Nộp bài qua sp_SubmitAssignment (procedure có OUTPUT @SubmissionID).
    Dùng batch T-SQL khai báo biến để lấy OUTPUT, rồi đọc lại Status/IsLate
    (do trigger trg_Submissions_Policy đặt) để báo cho người dùng.
    Trả về dict {SubmissionID, Status, IsLate}. Có thể raise nếu chưa enroll.
    """
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "DECLARE @sid INT;\n"
            "EXEC sp_SubmitAssignment @AssignmentID=?, @StudentID=?, "
            "@ContentURL=?, @SubmissionID=@sid OUTPUT;\n"
            "SELECT @sid AS SubmissionID, s.Status AS SubStatus, s.IsLate AS IsLate\n"
            "FROM Submissions s WHERE s.SubmissionID = @sid;",
            (assignment_id, student_id, content_url),
        )
        row = None
        while True:
            if cursor.description:
                row = cursor.fetchone()
                break
            if not cursor.nextset():
                break
        conn.commit()
        if row is None:
            return None
        return {"SubmissionID": row[0], "SubStatus": row[1], "IsLate": row[2]}


def get_gradable_submissions(instructor_id=None):
    """
    Bài nộp cần chấm. instructor_id=None -> tất cả (cho Admin); ngược lại chỉ
    bài thuộc khóa do giảng viên đó phụ trách.
    """
    base = """
        SELECT s.SubmissionID, c.Title AS Course, a.Title AS Assignment, a.MaxScore,
               st.FullName AS Student, s.Status, s.IsLate, s.SubmittedAt,
               g.Score, g.Feedback
        FROM Submissions s
        JOIN Assignments a ON a.AssignmentID = s.AssignmentID
        JOIN Courses c     ON c.CourseID = a.CourseID
        JOIN Users st      ON st.UserID = s.StudentID
        LEFT JOIN Grades g ON g.SubmissionID = s.SubmissionID
    """
    if instructor_id is None:
        return query_all(base + " ORDER BY c.Title, a.Title, st.FullName;")
    return query_all(
        base + " WHERE c.InstructorID = ? ORDER BY c.Title, a.Title, st.FullName;",
        (instructor_id,),
    )


def grade_submission(submission_id: int, score, feedback, graded_by: int):
    """
    Chấm điểm 1 bài nộp qua sp_GradeSubmission. Có thể raise nếu vi phạm
    (điểm > MaxScore, người chấm không phải Instructor/Admin, ...).
    """
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC sp_GradeSubmission @SubmissionID=?, @Score=?, @Feedback=?, @GradedBy=?",
            (submission_id, score, feedback, graded_by),
        )
        conn.commit()


def get_forum_threads(course_id: int):
    """Các chủ đề thảo luận của 1 khóa + số bài viết."""
    return query_all(
        """
        SELECT t.ThreadID, t.Title, t.CreatedAt,
               u.FullName AS CreatedBy,
               (SELECT COUNT(*) FROM ForumPosts p WHERE p.ThreadID = t.ThreadID) AS PostCount
        FROM ForumThreads t
        JOIN Users u ON u.UserID = t.CreatedBy
        WHERE t.CourseID = ?
        ORDER BY t.CreatedAt DESC;
        """,
        (course_id,),
    )


def get_forum_posts(thread_id: int):
    """Các bài viết trong 1 chủ đề."""
    return query_all(
        """
        SELECT p.PostID, p.Content, p.ParentPostID, p.CreatedAt,
               u.FullName AS Author, u.Role AS AuthorRole
        FROM ForumPosts p
        JOIN Users u ON u.UserID = p.UserID
        WHERE p.ThreadID = ?
        ORDER BY p.CreatedAt;
        """,
        (thread_id,),
    )


def add_forum_thread(course_id: int, created_by: int, title: str, content: str):
    """Tạo chủ đề mới + bài viết đầu tiên (parameterized, 1 transaction)."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO ForumThreads (CourseID, CreatedBy, Title) "
            "OUTPUT INSERTED.ThreadID VALUES (?, ?, ?);",
            (course_id, created_by, title),
        )
        thread_id = cursor.fetchone()[0]
        cursor.execute(
            "INSERT INTO ForumPosts (ThreadID, UserID, Content) VALUES (?, ?, ?);",
            (thread_id, created_by, content),
        )
        conn.commit()
        return thread_id


def add_forum_post(thread_id: int, user_id: int, content: str, parent_post_id=None):
    """Thêm 1 bài viết vào chủ đề (parameterized)."""
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO ForumPosts (ThreadID, UserID, Content, ParentPostID) "
            "VALUES (?, ?, ?, ?);",
            (thread_id, user_id, content, parent_post_id),
        )
        conn.commit()


# ---------------------------------------------------------------------
# Phase 6: Certificates (Coursera-style) - điểm khóa & chứng chỉ ≥ 80%.
# Điểm tổng & ngưỡng đạt được TÍNH/ÉP hoàn toàn trong database
# (fn_CourseFinalGrade, fn_HasPassedCourse, sp_IssueCertificate, CK_Cert_Pass).
# ---------------------------------------------------------------------

PASSING_THRESHOLD = 80  # chỉ để hiển thị; ngưỡng thật được ép trong DB


def get_course_final_grade(student_id: int, course_id: int):
    """Điểm tổng kết khóa (%, 0..100) qua fn_CourseFinalGrade; None nếu chưa có bài chấm."""
    return query_scalar(
        "SELECT dbo.fn_CourseFinalGrade(?, ?);", (student_id, course_id)
    )


def has_passed_course(student_id: int, course_id: int) -> bool:
    """Đã đạt ngưỡng (>=80%) chưa - qua fn_HasPassedCourse (BIT)."""
    return bool(query_scalar(
        "SELECT dbo.fn_HasPassedCourse(?, ?);", (student_id, course_id)
    ))


def get_certificate(student_id: int, course_id: int):
    """Chứng chỉ của 1 (sinh viên, khóa) nếu đã được cấp, kèm tên khóa & SV."""
    return query_one(
        """
        SELECT cert.CertificateID, cert.CertificateCode, cert.FinalScore, cert.IssuedAt,
               cert.StudentID, cert.CourseID,
               u.FullName  AS StudentName,
               c.CourseCode, c.Title AS CourseTitle,
               ins.FullName AS InstructorName
        FROM Certificates cert
        JOIN Users   u   ON u.UserID = cert.StudentID
        JOIN Courses c   ON c.CourseID = cert.CourseID
        JOIN Users   ins ON ins.UserID = c.InstructorID
        WHERE cert.StudentID = ? AND cert.CourseID = ?;
        """,
        (student_id, course_id),
    )


def get_student_certificates(student_id: int):
    """Tất cả chứng chỉ 1 sinh viên đã đạt được."""
    return query_all(
        """
        SELECT cert.CertificateID, cert.CertificateCode, cert.FinalScore, cert.IssuedAt,
               c.CourseID, c.CourseCode, c.Title AS CourseTitle,
               ins.FullName AS InstructorName
        FROM Certificates cert
        JOIN Courses c   ON c.CourseID = cert.CourseID
        JOIN Users   ins ON ins.UserID = c.InstructorID
        WHERE cert.StudentID = ?
        ORDER BY cert.IssuedAt DESC;
        """,
        (student_id,),
    )


def issue_certificate(student_id: int, course_id: int):
    """
    Cấp chứng chỉ qua sp_IssueCertificate. Procedure tự kiểm tra điểm >= 80%
    (nếu không sẽ THROW -> route hiển thị message). Trả về dict chứng chỉ.
    """
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("EXEC sp_IssueCertificate ?, ?", (student_id, course_id))
        row = None
        while True:
            if cursor.description:
                row = _rows_to_dicts(cursor)
                break
            if not cursor.nextset():
                break
        conn.commit()
        return row[0] if row else None
