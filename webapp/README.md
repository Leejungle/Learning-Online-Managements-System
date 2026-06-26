# LMS Web App Demo (DBI202)

Lớp **demo/thuyết trình** cho đồ án cơ sở dữ liệu LMS. Web app này đặt **trên nền
database SQL Server đã hoàn chỉnh** ở thư mục [`../sql`](../sql) và dùng dữ liệu **thật**
từ database, không dùng dữ liệu giả.

## 1. Mục đích

- Chứng minh database SQL Server hoạt động trong một ứng dụng thật.
- Mỗi tính năng web ánh xạ tới một object thật trong DB (view / function / stored procedure / bảng).
- Phục vụ phần **Demonstration** và lấy **điểm cộng web app** của rubric DBI202.

> SQL Server là **dự án chính**. Web app **không** chứa logic nghiệp vụ riêng — mọi ràng
> buộc/nghiệp vụ vẫn nằm trong database (schema, trigger, procedure, view).

## 2. Tech stack

| Thành phần | Lựa chọn | Lý do |
|---|---|---|
| Ngôn ngữ | Python 3 | Có sẵn trên máy |
| Web framework | Flask | Nhẹ, render server-side đơn giản |
| Kết nối DB | pyodbc + ODBC Driver 18 | Hỗ trợ **Windows Authentication** ngay (SQL Server đang ở chế độ chỉ Windows Auth) |
| Giao diện | Jinja2 + Bootstrap (CDN) | Nhanh, đẹp, sẵn sàng chụp screenshot |

## 3. Yêu cầu trước khi chạy

- Python 3 đã cài.
- SQL Server đang chạy, database `LMS` đã được dựng (chạy `../sql/run_all_local.sql` — xem [README gốc](../README.md) mục 2).
- ODBC Driver 18 for SQL Server đã cài (đi kèm SSMS/SQL Server).

## 4. Cài đặt

```powershell
cd webapp
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
copy .env.example .env
```

## 5. Biến môi trường

Cấu hình trong file `.env` (copy từ `.env.example`). Vì dùng **Windows Authentication**
nên **không có mật khẩu** nào được lưu.

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `DB_DRIVER` | `ODBC Driver 18 for SQL Server` | Tên ODBC driver |
| `DB_SERVER` | `localhost` | Tên SQL Server instance |
| `DB_NAME` | `LMS` | Tên database |
| `DB_TRUSTED_CONNECTION` | `yes` | Dùng Windows Authentication |
| `DB_TRUST_SERVER_CERTIFICATE` | `yes` | Bỏ qua kiểm tra SSL self-signed (cần cho ODBC 18) |
| `FLASK_DEBUG` | `1` | `0` khi demo cho ổn định |
| `SECRET_KEY` | (placeholder) | Khóa session Flask, đổi thành chuỗi ngẫu nhiên của bạn |

> File `.env` đã được `.gitignore` loại trừ — không commit lên git. Chỉ commit `.env.example`.

## 6. Chạy app

```powershell
cd webapp
.\.venv\Scripts\python.exe app.py
```

Mở trình duyệt: <http://127.0.0.1:5000>

## 7. Bản đồ route ↔ object SQL

Mỗi trang web ánh xạ trực tiếp tới một object thật trong database:

| Đường dẫn | Chức năng | Object SQL tái dùng |
|---|---|---|
| `/health` | Kiểm tra kết nối DB (JSON) | `SELECT COUNT(*) FROM Users` |
| `/catalog` | Danh mục khóa học + lọc (tên/level/category/status) | view `vw_CourseCatalog` |
| `/courses/<id>` | Chi tiết khóa: outline module/material, đăng ký, nộp bài, thảo luận | `Modules`, `Materials`, `fn_CanAccessCourse`, `sp_EnrollStudent`, `sp_SubmitAssignment`, `ForumThreads/Posts` |
| `/dashboard` | Điểm + tiến độ của sinh viên đang đóng vai | view `vw_Gradebook`, hàm `fn_CourseProgress` |
| `/reports` | 6 báo cáo phân tích (tabs) | các SELECT trong `06_reports.sql` |
| `/recommendations` | Gợi ý khóa học (AI) cho sinh viên | `sp_RecommendCourses`, bảng `Recommendations` |
| `/grading` | Instructor/Admin chấm điểm bài nộp | `sp_GradeSubmission`, trigger `trg_Grades_MarkGraded` |
| `/business-rules` | Showcase: cố tình vi phạm để DB chặn & hiện nguyên văn lỗi | trigger + `sp_EnrollStudent` |

**Đối chiếu tính đúng:** mở SSMS chạy `SELECT * FROM vw_CourseCatalog;` và so với trang
`/catalog` — số liệu phải khớp (bằng chứng web đọc dữ liệu thật từ SQL Server).

## 8. Tắt app trước khi reset database

`../sql/run_all_local.sql` sẽ **DROP và tạo lại** database `LMS`. Trước khi chạy nó:

1. Dừng web app: nhấn **Ctrl+C** ở cửa sổ đang chạy `app.py`.
2. Đảm bảo không còn tiến trình Python nào của app giữ kết nối.
3. Chạy lại runner (xem [README gốc](../README.md) mục 2.3).

> App dùng pyodbc mở/đóng kết nối theo từng request (không giữ connection pool lâu),
> nên thường không khóa `LMS`; nhưng vẫn nên tắt hẳn cho chắc khi reset.

## 9. Tiến độ các phase

**Đã hoàn thành toàn bộ:**
- **Phase 0** — Khởi tạo project + route `/health` kiểm tra kết nối DB.
- **Phase 1** — Layout Bootstrap + demo user selector + Course Catalog (`vw_CourseCatalog`).
- **Phase 2** — Course detail (modules/materials, ẩn link học liệu khi chưa đăng ký) + Student dashboard (`vw_Gradebook`, `fn_CourseProgress`, `fn_CanAccessCourse`).
- **UI polish** — Bộ giao diện academic (custom `static/css/app.css`, Google Fonts) cho toàn bộ trang.
- **Phase 3** — Trang Reports/Statistics: 6 báo cáo (tabs) từ `06_reports.sql`, chạy từng SELECT độc lập.
- **Phase 4** — Enroll (`sp_EnrollStudent`) + Recommend (`sp_RecommendCourses`) + Business-rule showcase (hiện nguyên văn lỗi trigger/procedure).
- **Phase 5** — Submission (`sp_SubmitAssignment`, OUTPUT param) + Grading (`sp_GradeSubmission`) + Forum (`ForumThreads`/`ForumPosts`).

**Tùy chọn (chờ duyệt):** đổi tên `sp_` → `usp_` đồng bộ để tránh tái phát sự cố "procedure ma" trong `master`.

## 10. Ghi chú demo

Demo user selector trên navbar cho phép "đóng vai" một user (không phải đăng nhập thật) —
đủ để minh họa dữ liệu theo từng vai trò mà không cần xây authentication.
