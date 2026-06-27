"""
Web app demo cho đồ án DBI202 - Online Learning Management System (LMS).

Đây là lớp DEMO mỏng trên nền database SQL Server đã hoàn chỉnh.
Database là core; app chỉ đọc dữ liệu + gọi stored procedure có sẵn.

Phase 0: route /health kiểm tra kết nối.
Phase 1: layout Bootstrap + demo user selector + Course Catalog (vw_CourseCatalog).
Phase 2: Course detail (Modules/Materials) + Student dashboard
         (vw_Gradebook + fn_CourseProgress + fn_CanAccessCourse).
Phase 3: Reports / Statistics (6 báo cáo từ 06_reports.sql).
Phase 4: Actions - Enroll (sp_EnrollStudent), Recommend (sp_RecommendCourses)
         + Business-rule showcase (hiển thị nguyên văn lỗi trigger/procedure).
Phase 5: Submit (sp_SubmitAssignment, OUTPUT), Grading (sp_GradeSubmission),
         Forum (ForumThreads/ForumPosts).
"""

import os
from flask import (
    Flask,
    abort,
    jsonify,
    render_template,
    request,
    redirect,
    url_for,
    session,
    flash,
)
from dotenv import load_dotenv

import db

load_dotenv()

app = Flask(__name__)
app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "dev-secret")


# ---------------------------------------------------------------------
# Demo user selector: lưu UserID đang "đóng vai" trong session.
# Đây KHÔNG phải auth thật - chỉ để demo dữ liệu theo từng user.
# ---------------------------------------------------------------------
@app.before_request
def _start_sql_capture():
    """Bắt đầu ghi lại các câu SQL mà request này sẽ chạy (SQL Transparency)."""
    db.capture_begin()


@app.context_processor
def inject_globals():
    """Bơm danh sách user + user hiện tại + SQL của trang vào mọi template."""
    # Tạm dừng ghi SQL khi nạp dữ liệu hạ tầng (user selector) để panel
    # "SQL của trang" chỉ chứa truy vấn nghiệp vụ thật sự của trang.
    db.capture_pause()
    current_user = None
    user_id = session.get("user_id")
    if user_id:
        current_user = db.get_user(user_id)
    try:
        all_users = db.get_all_users()
    except Exception:  # noqa: BLE001
        all_users = []
    db.capture_resume()
    return {
        "all_users": all_users,
        "current_user": current_user,
        "page_sql": db.capture_get(),
    }


@app.route("/select-user", methods=["POST"])
def select_user():
    """Đặt user đang đóng vai (từ dropdown trên navbar)."""
    user_id = request.form.get("user_id", type=int)
    if user_id and db.get_user(user_id):
        session["user_id"] = user_id
    else:
        session.pop("user_id", None)
    # Quay lại trang trước đó nếu có
    return redirect(request.referrer or url_for("catalog"))


# ---------------------------------------------------------------------
# Trang chính
# ---------------------------------------------------------------------
@app.route("/")
def index():
    return redirect(url_for("catalog"))


@app.route("/catalog")
def catalog():
    """Danh mục khóa học (đọc từ view vw_CourseCatalog), có lọc/tìm kiếm."""
    search = request.args.get("q", "").strip() or None
    level = request.args.get("level", "").strip() or None
    category = request.args.get("category", "").strip() or None
    status = request.args.get("status", "").strip() or None

    courses = db.get_course_catalog(
        search=search, level=level, category=category, status=status
    )
    categories = db.get_catalog_categories()

    return render_template(
        "catalog.html",
        courses=courses,
        categories=categories,
        filters={
            "q": search or "",
            "level": level or "",
            "category": category or "",
            "status": status or "",
        },
    )


@app.route("/courses/<int:course_id>")
def course_detail(course_id):
    """
    Chi tiết khóa học: thông tin tổng quan + outline Module -> Materials.
    Học liệu chỉ hiện link khi user đang đóng vai là Student ĐÃ đăng ký
    (kiểm tra bằng fn_CanAccessCourse); chưa đăng ký vẫn thấy tên + badge.
    """
    course = db.get_course_header(course_id)
    if not course:
        abort(404)

    modules = db.get_course_modules(course_id)

    current = None
    user_id = session.get("user_id")
    if user_id:
        current = db.get_user(user_id)

    can_access = False
    student_id = None
    final_grade = None
    passed = False
    certificate = None
    if current and current["Role"] == "Student":
        can_access = db.can_access_course(current["UserID"], course_id)
        student_id = current["UserID"]
        if can_access:
            final_grade = db.get_course_final_grade(student_id, course_id)
            passed = db.has_passed_course(student_id, course_id)
            certificate = db.get_certificate(student_id, course_id)

    assignments = db.get_course_assignments(course_id, student_id)

    threads = db.get_forum_threads(course_id)
    forum = [
        {"thread": t, "posts": db.get_forum_posts(t["ThreadID"])} for t in threads
    ]

    return render_template(
        "course_detail.html",
        course=course,
        modules=modules,
        can_access=can_access,
        assignments=assignments,
        forum=forum,
        final_grade=final_grade,
        passed=passed,
        certificate=certificate,
        passing_threshold=db.PASSING_THRESHOLD,
    )


@app.route("/dashboard")
def dashboard():
    """
    Bảng điều khiển sinh viên: điểm (vw_Gradebook) + tiến độ theo khóa đã
    đăng ký (Enrollments + fn_CourseProgress). Chỉ có nghĩa khi đóng vai
    Student; ngược lại hiển thị hướng dẫn (không lỗi).
    """
    current = None
    user_id = session.get("user_id")
    if user_id:
        current = db.get_user(user_id)

    if not current or current["Role"] != "Student":
        return render_template("dashboard.html", is_student=False, student=current)

    grades = db.get_student_grades(current["UserID"])
    progress = db.get_student_progress(current["UserID"])
    # Gắn điểm tổng kết + trạng thái đạt cho mỗi khóa đã đăng ký
    for p in progress:
        p["FinalGrade"] = db.get_course_final_grade(current["UserID"], p["CourseID"])
        p["Passed"] = db.has_passed_course(current["UserID"], p["CourseID"])
    certificates = db.get_student_certificates(current["UserID"])
    return render_template(
        "dashboard.html",
        is_student=True,
        student=current,
        grades=grades,
        progress=progress,
        certificates=certificates,
        passing_threshold=db.PASSING_THRESHOLD,
    )


@app.route("/reports")
def reports():
    """
    Trang Báo cáo / Thống kê: 6 báo cáo phân tích lấy thẳng từ các truy vấn
    trong sql/06_reports.sql (chạy từng SELECT độc lập qua db.py). Read-only.
    """
    data = {
        "student_performance": db.report_student_performance(),
        "course_completion": db.report_course_completion(),
        "instructor_activity": db.report_instructor_activity(),
        "assignment_submission": db.report_assignment_submission(),
        "usage_daily": db.report_usage_daily(),
        "usage_sessions": db.report_usage_sessions(),
        "rec_overall": db.report_recommendation_overall(),
        "rec_by_course": db.report_recommendation_by_course(),
    }
    return render_template("reports.html", **data)


def _current_user():
    """Tiện ích: lấy user đang đóng vai từ session (hoặc None)."""
    user_id = session.get("user_id")
    return db.get_user(user_id) if user_id else None


@app.route("/enroll", methods=["POST"])
def enroll():
    """
    Hành động đăng ký khóa học (happy path) bằng sp_EnrollStudent.
    Dùng user đang đóng vai làm sinh viên. Lỗi vi phạm quy tắc (đã đăng ký,
    không phải Student, khóa chưa Published) được hiển thị nguyên văn.
    """
    course_id = request.form.get("course_id", type=int)
    current = _current_user()
    if not current:
        flash("Hãy đóng vai một người dùng trước khi đăng ký.", "warning")
        return redirect(request.referrer or url_for("catalog"))
    if not course_id:
        flash("Thiếu thông tin khóa học.", "warning")
        return redirect(request.referrer or url_for("catalog"))
    try:
        db.enroll_student(current["UserID"], course_id)
        flash("Đăng ký thành công! (qua sp_EnrollStudent)", "success")
    except Exception as exc:  # noqa: BLE001
        flash("Không thể đăng ký — " + db.sql_error_message(exc), "danger")
    return redirect(request.referrer or url_for("course_detail", course_id=course_id))


@app.route("/recommendations")
def recommendations():
    """Trang gợi ý AI cho sinh viên đang đóng vai (đọc bảng Recommendations)."""
    current = _current_user()
    is_student = bool(current and current["Role"] == "Student")
    recs = db.get_recommendations(current["UserID"]) if is_student else []
    return render_template(
        "recommendations.html", student=current, is_student=is_student, recs=recs
    )


@app.route("/recommendations/generate", methods=["POST"])
def generate_recommendations():
    """Sinh gợi ý bằng sp_RecommendCourses cho sinh viên đang đóng vai."""
    current = _current_user()
    if not current:
        flash("Hãy đóng vai một sinh viên trước.", "warning")
        return redirect(url_for("recommendations"))
    try:
        shown = db.recommend_courses(current["UserID"], 5)
        flash(
            f"Đã chạy sp_RecommendCourses — hiện có {len(shown)} gợi ý đang hiển thị.",
            "success",
        )
    except Exception as exc:  # noqa: BLE001
        flash("Không tạo được gợi ý — " + db.sql_error_message(exc), "danger")
    return redirect(url_for("recommendations"))


@app.route("/business-rules")
def business_rules():
    """
    Showcase quy tắc nghiệp vụ: chọn (user, course) rồi thử đăng ký để xem
    database CHẶN và trả về nguyên văn message từ trigger/procedure.
    """
    return render_template(
        "business_rules.html",
        users=db.get_all_users(),
        courses=db.get_courses_brief(),
    )


@app.route("/business-rules/try-enroll", methods=["POST"])
def br_try_enroll():
    """Thử đăng ký 1 cặp (user, course) bất kỳ để minh họa kiểm soát ở DB."""
    user_id = request.form.get("user_id", type=int)
    course_id = request.form.get("course_id", type=int)
    if not user_id or not course_id:
        flash("Vui lòng chọn cả người dùng và khóa học.", "warning")
        return redirect(url_for("business_rules"))
    try:
        db.enroll_student(user_id, course_id)
        flash("Thành công: DB chấp nhận đăng ký (không vi phạm quy tắc nào).", "success")
    except Exception as exc:  # noqa: BLE001
        flash("DB từ chối (đúng như mong đợi) — " + db.sql_error_message(exc), "danger")
    return redirect(url_for("business_rules"))


@app.route("/submit", methods=["POST"])
def submit():
    """Nộp bài qua sp_SubmitAssignment (OUTPUT param). Dùng student đang đóng vai."""
    assignment_id = request.form.get("assignment_id", type=int)
    course_id = request.form.get("course_id", type=int)
    content_url = (request.form.get("content_url") or "").strip() or None
    current = _current_user()
    if not current or current["Role"] != "Student":
        flash("Hãy đóng vai một sinh viên để nộp bài.", "warning")
        return redirect(request.referrer or url_for("catalog"))
    if not assignment_id:
        flash("Thiếu thông tin bài đánh giá.", "warning")
        return redirect(request.referrer or url_for("catalog"))
    try:
        res = db.submit_assignment(assignment_id, current["UserID"], content_url)
        if res and res.get("SubStatus") == "Rejected":
            flash(
                f"Đã nộp (SubmissionID={res['SubmissionID']}) nhưng bị "
                f"TỪ CHỐI do trễ hạn (chính sách RejectLate).",
                "warning",
            )
        elif res and res.get("IsLate"):
            flash(
                f"Nộp thành công (SubmissionID={res['SubmissionID']}) — "
                f"bị đánh dấu TRỄ HẠN bởi trigger.",
                "warning",
            )
        else:
            flash(
                f"Nộp bài thành công (SubmissionID={res['SubmissionID'] if res else '?'}).",
                "success",
            )
    except Exception as exc:  # noqa: BLE001
        flash("Không nộp được — " + db.sql_error_message(exc), "danger")
    return redirect(request.referrer or url_for("course_detail", course_id=course_id))


@app.route("/grading")
def grading():
    """Trang chấm điểm cho Instructor (bài thuộc khóa mình dạy) / Admin (tất cả)."""
    current = _current_user()
    role = current["Role"] if current else None
    can_grade = role in ("Instructor", "Admin")
    submissions = []
    if can_grade:
        instructor_id = None if role == "Admin" else current["UserID"]
        submissions = db.get_gradable_submissions(instructor_id)
    return render_template(
        "grading.html", grader=current, can_grade=can_grade, submissions=submissions
    )


@app.route("/grading/submit", methods=["POST"])
def grading_submit():
    """Ghi điểm qua sp_GradeSubmission (GradedBy = người đang đóng vai)."""
    submission_id = request.form.get("submission_id", type=int)
    score = request.form.get("score", type=float)
    feedback = (request.form.get("feedback") or "").strip() or None
    current = _current_user()
    if not current or current["Role"] not in ("Instructor", "Admin"):
        flash("Chỉ Instructor/Admin mới được chấm điểm.", "warning")
        return redirect(url_for("grading"))
    if submission_id is None or score is None:
        flash("Thiếu mã bài nộp hoặc điểm.", "warning")
        return redirect(url_for("grading"))
    try:
        db.grade_submission(submission_id, score, feedback, current["UserID"])
        flash(f"Đã chấm bài #{submission_id}: {score} điểm.", "success")
    except Exception as exc:  # noqa: BLE001
        flash("Không chấm được — " + db.sql_error_message(exc), "danger")
    return redirect(url_for("grading"))


@app.route("/forum/thread", methods=["POST"])
def forum_thread():
    """Tạo chủ đề thảo luận mới + bài viết đầu tiên."""
    course_id = request.form.get("course_id", type=int)
    title = (request.form.get("title") or "").strip()
    content = (request.form.get("content") or "").strip()
    current = _current_user()
    if not current:
        flash("Hãy đóng vai một người dùng để tạo chủ đề.", "warning")
        return redirect(request.referrer or url_for("course_detail", course_id=course_id))
    if not title or not content:
        flash("Vui lòng nhập tiêu đề và nội dung.", "warning")
        return redirect(request.referrer or url_for("course_detail", course_id=course_id))
    try:
        db.add_forum_thread(course_id, current["UserID"], title, content)
        flash("Đã tạo chủ đề thảo luận mới.", "success")
    except Exception as exc:  # noqa: BLE001
        flash("Không tạo được chủ đề — " + db.sql_error_message(exc), "danger")
    return redirect(request.referrer or url_for("course_detail", course_id=course_id))


@app.route("/forum/post", methods=["POST"])
def forum_post():
    """Trả lời 1 chủ đề (thêm bài viết)."""
    thread_id = request.form.get("thread_id", type=int)
    course_id = request.form.get("course_id", type=int)
    content = (request.form.get("content") or "").strip()
    current = _current_user()
    if not current:
        flash("Hãy đóng vai một người dùng để trả lời.", "warning")
        return redirect(request.referrer or url_for("course_detail", course_id=course_id))
    if not thread_id or not content:
        flash("Vui lòng nhập nội dung trả lời.", "warning")
        return redirect(request.referrer or url_for("course_detail", course_id=course_id))
    try:
        db.add_forum_post(thread_id, current["UserID"], content)
        flash("Đã gửi trả lời.", "success")
    except Exception as exc:  # noqa: BLE001
        flash("Không gửi được — " + db.sql_error_message(exc), "danger")
    return redirect(request.referrer or url_for("course_detail", course_id=course_id))


@app.route("/certificate/claim", methods=["POST"])
def claim_certificate():
    """
    Nhận chứng chỉ khóa học (Coursera-style) qua sp_IssueCertificate.
    DB tự kiểm tra điểm tổng kết >= 80%; nếu chưa đạt sẽ trả lỗi nguyên văn.
    """
    course_id = request.form.get("course_id", type=int)
    current = _current_user()
    if not current or current["Role"] != "Student":
        flash("Hãy đóng vai một sinh viên để nhận chứng chỉ.", "warning")
        return redirect(request.referrer or url_for("catalog"))
    if not course_id:
        flash("Thiếu thông tin khóa học.", "warning")
        return redirect(request.referrer or url_for("catalog"))
    try:
        cert = db.issue_certificate(current["UserID"], course_id)
        if cert:
            flash(
                f"Chúc mừng! Bạn đã đạt {cert['FinalScore']}% và nhận chứng chỉ "
                f"{cert['CertificateCode']}.",
                "success",
            )
    except Exception as exc:  # noqa: BLE001
        flash("Chưa thể cấp chứng chỉ — " + db.sql_error_message(exc), "danger")
    return redirect(request.referrer or url_for("course_detail", course_id=course_id))


@app.route("/certificates")
def certificates():
    """Danh sách chứng chỉ của sinh viên đang đóng vai."""
    current = _current_user()
    is_student = bool(current and current["Role"] == "Student")
    certs = db.get_student_certificates(current["UserID"]) if is_student else []
    return render_template(
        "certificates.html", student=current, is_student=is_student, certs=certs
    )


@app.route("/certificate/<int:course_id>")
def certificate_view(course_id):
    """Xem (và in) chứng chỉ của sinh viên đang đóng vai cho 1 khóa."""
    current = _current_user()
    if not current or current["Role"] != "Student":
        abort(404)
    cert = db.get_certificate(current["UserID"], course_id)
    if not cert:
        abort(404)
    return render_template("certificate.html", cert=cert)


@app.route("/portal")
def portal():
    """Cổng theo vai trò: điều hướng người dùng tới trang chủ đúng với Role."""
    current = _current_user()
    if not current:
        flash("Hãy đóng vai một người dùng để vào cổng theo vai trò.", "warning")
        return redirect(url_for("catalog"))
    role = current["Role"]
    if role == "Student":
        return redirect(url_for("dashboard"))
    if role == "Instructor":
        return redirect(url_for("instructor_portal"))
    if role == "Admin":
        return redirect(url_for("admin_portal"))
    return redirect(url_for("catalog"))


@app.route("/instructor")
def instructor_portal():
    """
    Cổng giảng viên: khóa mình phụ trách (sĩ số, hoàn thành, số bài đánh giá),
    chỉ số tổng hợp (report_instructor_activity) và số bài đang chờ chấm.
    """
    current = _current_user()
    is_instructor = bool(current and current["Role"] == "Instructor")
    if not is_instructor:
        return render_template(
            "instructor.html", is_instructor=False, instructor=current
        )

    iid = current["UserID"]
    courses = db.get_instructor_courses(iid)
    submissions = db.get_gradable_submissions(iid)
    pending = sum(
        1 for s in submissions if s["Score"] is None and s["Status"] == "Submitted"
    )
    activity = next(
        (
            r
            for r in db.report_instructor_activity()
            if r["InstructorID"] == iid
        ),
        None,
    )
    return render_template(
        "instructor.html",
        is_instructor=True,
        instructor=current,
        courses=courses,
        pending=pending,
        activity=activity,
    )


@app.route("/admin")
def admin_portal():
    """Cổng quản trị: tổng quan toàn hệ thống + top khóa + chứng chỉ gần đây."""
    current = _current_user()
    is_admin = bool(current and current["Role"] == "Admin")
    if not is_admin:
        return render_template("admin.html", is_admin=False, admin=current)

    return render_template(
        "admin.html",
        is_admin=True,
        admin=current,
        overview=db.get_admin_overview(),
        users_by_role=db.get_users_by_role(),
        top_courses=db.get_top_courses(8),
        recent_certs=db.get_recent_certificates(8),
    )


@app.route("/sql-objects")
def sql_objects():
    """
    SQL Transparency: liệt kê toàn bộ đối tượng database (bảng + cột + ràng
    buộc + số dòng thật, và định nghĩa nguyên văn của view/function/
    procedure/trigger) đọc TRỰC TIẾP từ system catalog của SQL Server.
    Bằng chứng database là source of truth.
    """
    tables = db.get_schema_overview()
    objects = db.get_programmable_objects()

    groups = {"VIEW": [], "FUNCTION": [], "PROCEDURE": [], "TRIGGER": []}
    for o in objects:
        # sys.objects.type là char(2) -> có thể kèm khoảng trắng đuôi ('V ', 'P ')
        code = (o["TypeCode"] or "").strip()
        if code == "V":
            groups["VIEW"].append(o)
        elif code in ("FN", "IF", "TF"):
            groups["FUNCTION"].append(o)
        elif code == "P":
            groups["PROCEDURE"].append(o)
        elif code == "TR":
            groups["TRIGGER"].append(o)

    stats = {
        "tables": len(tables),
        "views": len(groups["VIEW"]),
        "functions": len(groups["FUNCTION"]),
        "procedures": len(groups["PROCEDURE"]),
        "triggers": len(groups["TRIGGER"]),
        "rows": sum((t["RowCount"] or 0) for t in tables),
    }
    return render_template(
        "sql_objects.html", tables=tables, groups=groups, stats=stats
    )


@app.route("/health")
def health():
    """Kiểm tra kết nối DB: đếm số bản ghi trong bảng Users."""
    try:
        user_count = db.query_scalar("SELECT COUNT(*) FROM Users;")
        return jsonify(
            status="ok",
            database=db.DB_NAME,
            server=db.DB_SERVER,
            driver=db.DB_DRIVER,
            users_count=user_count,
        )
    except Exception as exc:  # noqa: BLE001
        return jsonify(status="error", message=str(exc)), 500


if __name__ == "__main__":
    debug = os.getenv("FLASK_DEBUG", "0") == "1"
    # use_reloader=False: trên Windows, tiến trình con do reloader spawn ra bị
    # mất ngữ cảnh Windows Authentication (SSPI) -> kết nối SQL Server thất bại
    # với lỗi "Login failed". Tắt reloader để giữ Trusted_Connection hoạt động.
    app.run(host="127.0.0.1", port=5000, debug=debug, use_reloader=False)
