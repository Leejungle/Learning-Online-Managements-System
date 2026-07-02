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
import textwrap
import threading
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


# =====================================================================
# SQL Transparency: bắt LẠI đúng câu SQL mà mỗi request vừa chạy.
# Mục tiêu là để trang web hiển thị "đây chính là SQL gửi tới SQL Server",
# chứng minh database là source of truth. Dùng thread-local để gắn theo
# từng request (Flask dev server xử lý tuần tự / theo luồng).
# =====================================================================
_cap = threading.local()


def capture_begin():
    """Bắt đầu ghi SQL cho request hiện tại (gọi ở before_request)."""
    _cap.entries = []
    _cap.paused = False


def capture_pause():
    """Tạm dừng ghi (vd: khi nạp dữ liệu hạ tầng như danh sách user selector)."""
    _cap.paused = True


def capture_resume():
    """Tiếp tục ghi sau khi pause."""
    _cap.paused = False


def capture_get():
    """Lấy danh sách SQL đã ghi cho request hiện tại (list[dict])."""
    return getattr(_cap, "entries", None) or []


def _clean_sql(sql: str) -> str:
    """Bỏ thụt lề chung + khoảng trắng thừa để hiển thị gọn."""
    return textwrap.dedent(str(sql)).strip()


def _record(sql: str, params: tuple = ()):
    """Ghi 1 câu SQL vào log của request (nếu đang bật capture)."""
    entries = getattr(_cap, "entries", None)
    if entries is None or getattr(_cap, "paused", False):
        return
    entries.append(
        {
            "sql": _clean_sql(sql),
            "params": [("NULL" if p is None else str(p)) for p in params],
        }
    )


def query_all(sql: str, params: tuple = ()):
    """Chạy 1 câu SELECT, trả về list[dict]."""
    _record(sql, params)
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
    _record(sql, params)
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
    chosen = raw
    for c in candidates:
        if "Business rule" in c or "Invalid" in c or "already enrolled" in c:
            chosen = c
            break
    else:
        if candidates:
            chosen = candidates[-1]
    # Dịch sang tiếng Việt cho thân thiện khi demo (CHỈ ở tầng web, KHÔNG sửa DB).
    return localize_error(chosen)


# Bản dịch các thông điệp lỗi nghiệp vụ (nguyên văn do trigger/procedure/ràng
# buộc trả về) sang tiếng Việt. Chỉ phục vụ hiển thị demo; database vẫn là nơi
# thực thi và sinh ra message gốc (tiếng Anh). Khớp theo chuỗi con (substring).
_VI_MESSAGES = [
    # --- Trigger ---
    ("only users with role Student can enroll",
     "Chỉ người dùng có vai trò Student mới được đăng ký khóa học."),
    ("students can only enroll in Published courses",
     "Chỉ được đăng ký các khóa đã ở trạng thái Published."),
    ("a course must be managed by a user with role Instructor",
     "Mỗi khóa học phải do người dùng vai trò Instructor quản lý."),
    ("student is not enrolled in the course of this assignment",
     "Sinh viên chưa đăng ký khóa chứa bài đánh giá này nên không thể nộp bài."),
    ("a published course must keep at least one module",
     "Khóa đã Published phải còn ít nhất một module."),
    ("a course needs at least one module before it can be Published",
     "Khóa phải có ít nhất một module trước khi được Published."),
    ("GradedBy must be Instructor or Admin",
     "Người chấm điểm phải là Instructor hoặc Admin."),
    ("score exceeds the assignment MaxScore",
     "Điểm chấm vượt quá điểm tối đa (MaxScore) của bài."),
    ("selected option does not belong to the question",
     "Đáp án được chọn không thuộc câu hỏi tương ứng."),
    # --- Stored procedure ---
    ("already enrolled in this course",
     "Sinh viên đã đăng ký khóa học này rồi."),
    ("Submission not found",
     "Không tìm thấy bài nộp."),
    ("Related assignment not found",
     "Không tìm thấy bài đánh giá liên quan."),
    ("Auto-grading only supports Quiz/Exam",
     "Chấm tự động chỉ áp dụng cho bài dạng Quiz/Exam."),
    ("Recommendations can only be generated for Student",
     "Chỉ có thể tạo gợi ý cho người dùng vai trò Student."),
    ("Only Student users can earn a certificate",
     "Chỉ sinh viên (Student) mới được cấp chứng chỉ."),
    ("Student is not enrolled in this course",
     "Sinh viên chưa đăng ký khóa học này."),
    ("This course has no graded assignments yet",
     "Khóa học chưa có bài đánh giá nào được chấm điểm."),
    ("is below the passing threshold",
     "Điểm tổng kết chưa đạt ngưỡng 80% nên chưa thể cấp chứng chỉ."),
    # --- Ràng buộc (message gốc của SQL Server) ---
    ("UQ_Enroll",
     "Sinh viên đã đăng ký khóa học này rồi (trùng đăng ký)."),
    ("CK_Cert_Pass",
     "Điểm tổng kết phải ≥ 80% mới được cấp chứng chỉ (ràng buộc CK_Cert_Pass)."),
    ("CK_Users_Role",
     "Vai trò người dùng không hợp lệ (chỉ Student/Instructor/Admin)."),
]


def localize_error(msg: str) -> str:
    """Đổi thông điệp lỗi nghiệp vụ sang tiếng Việt; giữ nguyên nếu không có bản dịch."""
    if not msg:
        return msg
    low = msg.lower()
    for needle, vi in _VI_MESSAGES:
        if needle.lower() in low:
            return vi
    return msg


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


def get_popular_courses(top_n: int = 4):
    """
    'Khóa học phổ biến nhất' kiểu Coursera: các khóa Published có lượt đăng ký
    cao nhất. Đây KHÔNG phải gợi ý cá nhân hóa — chỉ xếp hạng theo độ phổ biến
    thực tế (COUNT đăng ký) lấy từ view vw_CourseCatalog. Dùng để showcase ngay
    đầu trang danh mục.
    """
    return query_all(
        """
        SELECT TOP (?) CourseID, CourseCode, Title, Level, CategoryName,
               InstructorName, EnrolledStudents, ModuleCount
        FROM vw_CourseCatalog
        WHERE Status = 'Published' AND EnrolledStudents > 0
        ORDER BY EnrolledStudents DESC, CourseCode;
        """,
        (top_n,),
    )


def has_recommendations(student_id: int) -> bool:
    """Sinh viên đã có gợi ý đang hiển thị (Shown/Clicked) hay chưa."""
    n = query_scalar(
        """
        SELECT COUNT(*) FROM Recommendations
        WHERE StudentID = ? AND Status IN ('Shown','Clicked');
        """,
        (student_id,),
    )
    return (n or 0) > 0


def recommend_courses(student_id: int, top_n: int = 4):
    """
    Gọi sp_RecommendCourses: SINH gợi ý cá nhân hóa (content-based theo danh
    mục SV đang học) và trả về danh sách 'Shown'. Idempotent: SP tự bỏ qua khóa
    đã được gợi ý/đăng ký. Có thể raise nếu user không phải Student.
    """
    _record("EXEC sp_RecommendCourses @StudentID=?, @TopN=?;", (student_id, top_n))
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("EXEC sp_RecommendCourses ?, ?", (student_id, top_n))
        rows = _rows_to_dicts(cursor) if cursor.description else []
        conn.commit()
        return rows


def get_recommended_courses(student_id: int, top_n: int = 4):
    """
    'Gợi ý cho bạn' (cá nhân hóa): các khóa được sp_RecommendCourses gợi ý cho
    sinh viên, lấy từ bảng Recommendations (chỉ trạng thái còn hiệu lực). Kèm
    thông tin khóa từ view vw_CourseCatalog để render card như Coursera.
    """
    return query_all(
        """
        SELECT TOP (?) v.CourseID, v.CourseCode, v.Title, v.Level, v.CategoryName,
               v.InstructorName, v.EnrolledStudents, v.ModuleCount,
               r.Score, r.Reason
        FROM Recommendations r
        JOIN vw_CourseCatalog v ON v.CourseID = r.CourseID
        WHERE r.StudentID = ? AND r.Status IN ('Shown','Clicked')
        ORDER BY r.Score DESC, v.CourseCode;
        """,
        (top_n, student_id),
    )


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
    _record("EXEC sp_EnrollStudent @StudentID=?, @CourseID=?;", (student_id, course_id))
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("EXEC sp_EnrollStudent ?, ?", (student_id, course_id))
        conn.commit()


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
    _record(
        "DECLARE @sid INT;\n"
        "EXEC sp_SubmitAssignment @AssignmentID=?, @StudentID=?, "
        "@ContentURL=?, @SubmissionID=@sid OUTPUT;\n"
        "SELECT @sid AS SubmissionID, s.Status, s.IsLate\n"
        "FROM Submissions s WHERE s.SubmissionID = @sid;",
        (assignment_id, student_id, content_url),
    )
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
    _record(
        "EXEC sp_GradeSubmission @SubmissionID=?, @Score=?, @Feedback=?, @GradedBy=?;",
        (submission_id, score, feedback, graded_by),
    )
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
    _record("EXEC sp_IssueCertificate @StudentID=?, @CourseID=?;", (student_id, course_id))
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


# ---------------------------------------------------------------------
# Phase: SQL Transparency - đọc metadata LIVE từ system catalog SQL Server.
# Toàn bộ định nghĩa (CREATE ...) được lấy thẳng từ sys.sql_modules /
# OBJECT_DEFINITION nên luôn khớp 100% với database thực tế đang chạy.
# Chỉ đọc (read-only), không nhận tham số người dùng -> không rủi ro.
# ---------------------------------------------------------------------

def _format_column_type(row) -> str:
    """Dựng chuỗi kiểu dữ liệu dễ đọc (vd NVARCHAR(100), DECIMAL(5,2))."""
    t = (row["DataType"] or "").upper()
    ml = row["MaxLength"]
    pr = row["Precision"]
    sc = row["Scale"]
    if t in ("NVARCHAR", "NCHAR"):
        length = "MAX" if ml == -1 else int(ml / 2)
        return f"{t}({length})"
    if t in ("VARCHAR", "CHAR", "VARBINARY", "BINARY"):
        length = "MAX" if ml == -1 else ml
        return f"{t}({length})"
    if t in ("DECIMAL", "NUMERIC"):
        return f"{t}({pr},{sc})"
    return t


def get_schema_overview():
    """
    Tổng quan các bảng người dùng: mỗi bảng kèm cột + ràng buộc + số dòng thật.
    Trả về list[dict]: {SchemaName, TableName, RowCount, columns[], constraints[]}.
    """
    tables = query_all(
        """
        SELECT  t.object_id              AS ObjectId,
                s.name                    AS SchemaName,
                t.name                    AS TableName,
                SUM(p.rows)               AS [RowCount]
        FROM sys.tables t
        JOIN sys.schemas s    ON s.schema_id = t.schema_id
        JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
        GROUP BY t.object_id, s.name, t.name
        ORDER BY t.name;
        """
    )

    columns = query_all(
        """
        SELECT  c.object_id          AS ObjectId,
                c.column_id          AS ColumnId,
                c.name               AS ColumnName,
                ty.name              AS DataType,
                c.max_length         AS MaxLength,
                c.precision          AS Precision,
                c.scale              AS Scale,
                c.is_nullable        AS IsNullable,
                c.is_identity        AS IsIdentity,
                dc.definition        AS DefaultDefinition
        FROM sys.columns c
        JOIN sys.types ty
             ON ty.user_type_id = c.user_type_id
        LEFT JOIN sys.default_constraints dc
             ON dc.object_id = c.default_object_id
        ORDER BY c.object_id, c.column_id;
        """
    )

    constraints = query_all(
        """
        SELECT kc.parent_object_id AS ObjectId, kc.name AS Name,
               kc.type_desc AS Kind, NULL AS Detail
        FROM sys.key_constraints kc                 -- PRIMARY KEY / UNIQUE
        UNION ALL
        SELECT fk.parent_object_id, fk.name,
               'FOREIGN KEY',
               'references ' + OBJECT_NAME(fk.referenced_object_id)
        FROM sys.foreign_keys fk
        UNION ALL
        SELECT cc.parent_object_id, cc.name, 'CHECK', cc.definition
        FROM sys.check_constraints cc
        ORDER BY ObjectId, Kind;
        """
    )

    cols_by_table = {}
    for c in columns:
        cols_by_table.setdefault(c["ObjectId"], []).append(
            {
                "ColumnName": c["ColumnName"],
                "TypeText": _format_column_type(c),
                "IsNullable": bool(c["IsNullable"]),
                "IsIdentity": bool(c["IsIdentity"]),
                "Default": c["DefaultDefinition"],
            }
        )

    cons_by_table = {}
    for c in constraints:
        cons_by_table.setdefault(c["ObjectId"], []).append(
            {"Name": c["Name"], "Kind": c["Kind"], "Detail": c["Detail"]}
        )

    for t in tables:
        oid = t["ObjectId"]
        t["columns"] = cols_by_table.get(oid, [])
        t["constraints"] = cons_by_table.get(oid, [])
    return tables


def get_programmable_objects():
    """
    Định nghĩa nguyên văn của view / function / procedure / trigger
    (lấy từ sys.sql_modules). Trả về list[dict] gồm cả mã nguồn T-SQL.
    """
    return query_all(
        """
        SELECT  o.type                                   AS TypeCode,
                o.type_desc                              AS TypeDesc,
                o.name                                   AS ObjectName,
                m.definition                             AS Definition,
                o.modify_date                            AS ModifiedAt,
                CASE WHEN o.type = 'TR'
                     THEN OBJECT_NAME(tr.parent_id) END  AS ParentTable
        FROM sys.objects o
        JOIN sys.sql_modules m   ON m.object_id = o.object_id
        LEFT JOIN sys.triggers tr ON tr.object_id = o.object_id
        WHERE o.is_ms_shipped = 0
          AND o.type IN ('V', 'P', 'FN', 'IF', 'TF', 'TR')
        ORDER BY CASE o.type
                     WHEN 'V'  THEN 1
                     WHEN 'FN' THEN 2
                     WHEN 'IF' THEN 2
                     WHEN 'TF' THEN 2
                     WHEN 'P'  THEN 3
                     WHEN 'TR' THEN 4
                     ELSE 5 END,
                 o.name;
        """
    )


# ---------------------------------------------------------------------
# Phase: Role Portal - dữ liệu cho cổng theo vai trò (Instructor / Admin).
# Tất cả chỉ đọc, dùng các bảng/quan hệ sẵn có. Student đã có /dashboard.
# ---------------------------------------------------------------------

def get_instructor_courses(instructor_id: int):
    """
    Các khóa do 1 giảng viên phụ trách + sĩ số, số hoàn thành, số bài đánh giá.
    Chỉ JOIN Enrollments (tránh nhân bản hàng); số bài đánh giá tính bằng subquery.
    """
    return query_all(
        """
        SELECT c.CourseID, c.CourseCode, c.Title, c.Status,
               COUNT(e.EnrollmentID)                                  AS Enrollments,
               SUM(CASE WHEN e.Status='Completed' THEN 1 ELSE 0 END)  AS Completed,
               (SELECT COUNT(*) FROM Assignments a WHERE a.CourseID=c.CourseID) AS Assignments
        FROM Courses c
        LEFT JOIN Enrollments e ON e.CourseID = c.CourseID
        WHERE c.InstructorID = ?
        GROUP BY c.CourseID, c.CourseCode, c.Title, c.Status
        ORDER BY c.CourseCode;
        """,
        (instructor_id,),
    )


def get_admin_overview():
    """Số liệu toàn hệ thống (1 dòng) cho cổng quản trị."""
    return query_one(
        """
        SELECT
            (SELECT COUNT(*) FROM Users WHERE Role='Student')        AS Students,
            (SELECT COUNT(*) FROM Users WHERE Role='Instructor')     AS Instructors,
            (SELECT COUNT(*) FROM Users WHERE Role='Admin')          AS Admins,
            (SELECT COUNT(*) FROM Courses)                           AS Courses,
            (SELECT COUNT(*) FROM Courses WHERE Status='Published')  AS Published,
            (SELECT COUNT(*) FROM Enrollments)                       AS Enrollments,
            (SELECT COUNT(*) FROM Submissions)                       AS Submissions,
            (SELECT COUNT(*) FROM Certificates)                      AS Certificates;
        """
    )


def get_users_by_role():
    """Phân bổ người dùng theo vai trò (cho biểu đồ/bảng quản trị)."""
    return query_all(
        """
        SELECT Role, COUNT(*) AS Total
        FROM Users
        GROUP BY Role
        ORDER BY Total DESC;
        """
    )


def get_top_courses(top_n: int = 8):
    """Top khóa học theo lượt đăng ký (cho cổng quản trị)."""
    return query_all(
        """
        SELECT TOP (?) c.CourseCode, c.Title, u.FullName AS Instructor,
               COUNT(e.EnrollmentID)                                  AS Enrollments,
               SUM(CASE WHEN e.Status='Completed' THEN 1 ELSE 0 END)  AS Completed
        FROM Courses c
        JOIN Users u ON u.UserID = c.InstructorID
        LEFT JOIN Enrollments e ON e.CourseID = c.CourseID
        GROUP BY c.CourseCode, c.Title, u.FullName
        ORDER BY COUNT(e.EnrollmentID) DESC, c.CourseCode;
        """,
        (top_n,),
    )


def get_recent_certificates(top_n: int = 8):
    """Các chứng chỉ mới cấp gần đây trên toàn hệ thống."""
    return query_all(
        """
        SELECT TOP (?) cert.CertificateCode, cert.FinalScore, cert.IssuedAt,
               u.FullName AS StudentName, c.Title AS CourseTitle
        FROM Certificates cert
        JOIN Users   u ON u.UserID = cert.StudentID
        JOIN Courses c ON c.CourseID = cert.CourseID
        ORDER BY cert.IssuedAt DESC;
        """,
        (top_n,),
    )
