# Online Learning Management System (LMS) — DBI202

Dự án cơ sở dữ liệu cho hệ thống quản lý học tập trực tuyến (LMS), xây dựng trên
**Microsoft SQL Server (T-SQL)**. Hệ thống quản lý người dùng, khóa học, nội dung
học liệu, bài tập/kiểm tra, chấm điểm, thảo luận, gợi ý khóa học (AI) và phân tích
hành vi học tập.

## 1. Cấu trúc thư mục

```
sql/
├── 01_schema.sql              -- Tạo database + bảng + khóa + ràng buộc
├── 02_triggers.sql            -- Trigger thực thi các quy tắc nghiệp vụ
├── 03_functions_views.sql     -- Hàm (function) và view phục vụ truy vấn/báo cáo
├── 04_procedures.sql          -- Stored procedure (đăng ký, nộp bài, chấm điểm, gợi ý...)
├── 05_sample_data.sql         -- Dữ liệu mẫu
├── 06_reports.sql             -- 6 truy vấn báo cáo/thống kê theo yêu cầu
├── 07_business_rule_tests.sql -- Kiểm thử các quy tắc nghiệp vụ (negative tests)
├── run_all.sql                -- Chạy tất cả theo thứ tự (đường dẫn TƯƠNG ĐỐI, SQLCMD mode)
└── run_all_local.sql          -- Chạy tất cả với đường dẫn TUYỆT ĐỐI (tiện chạy trong SSMS trên máy này)
docs/
├── erd.mmd / erd.png                    -- Sơ đồ ERD (mermaid source + ảnh)
├── block_diagram.mmd / block_diagram.png -- Sơ đồ khối kiến trúc hệ thống
├── flowchart_submission.mmd / .png      -- Lưu đồ quy trình nộp & chấm bài
└── Normalization_and_DataDictionary.md  -- Chuẩn hóa 1NF/2NF/3NF + Data dictionary
webapp/                          -- Web app demo (Flask + pyodbc) kết nối SQL Server thật
├── app.py                       -- Route Flask
├── db.py                        -- Lớp truy cập DB (parameterized, chỉ đọc/gọi SP có sẵn)
├── templates/                   -- Giao diện Jinja2 + Bootstrap
├── static/css/app.css           -- CSS tùy biến (giao diện academic)
├── requirements.txt             -- Thư viện Python
├── .env.example                 -- Mẫu biến môi trường (copy thành .env)
└── README.md                    -- Hướng dẫn riêng cho web app
README.md
```

> Tài liệu thiết kế chi tiết (chuẩn hóa 3NF & từ điển dữ liệu):
> [`docs/Normalization_and_DataDictionary.md`](docs/Normalization_and_DataDictionary.md).
> Sơ đồ ERD: [`docs/erd.png`](docs/erd.png).
> Hướng dẫn web app demo: [`webapp/README.md`](webapp/README.md).

## 2. Cách chạy database

> ⚠️ **Quan trọng:** `run_all.sql` / `run_all_local.sql` sẽ **DROP và tạo lại** database `LMS`
> (xem `01_schema.sql`: `ALTER DATABASE ... SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE LMS;`).
> Mọi dữ liệu trong `LMS` sẽ bị xóa và dựng lại từ đầu. **Hãy tắt web app trước khi chạy** (xem mục 2.3).

### 2.1. Cách A — SSMS (khuyến nghị `run_all_local.sql`)

1. Mở `sql/run_all_local.sql` (file này dùng **đường dẫn tuyệt đối** nên không bị lỗi
   "file not found" như `run_all.sql` dùng đường dẫn tương đối).
2. Bật **SQLCMD Mode**: menu `Query > SQLCMD Mode` (bắt buộc, để chạy được lệnh `:r`).
3. Đổi database trên thanh công cụ sang **`master`** (KHÔNG để là `LMS`). Vì script drop/tạo
   lại `LMS`, nếu cửa sổ query đang đứng trong `LMS` thì sẽ tự khóa chính mình → lỗi kết nối.
4. Nhấn **F5 (Execute)**. Tab *Messages* sẽ in lần lượt `... created successfully`,
   `Sample data inserted successfully`, các REPORT, và `TEST 1..10: PASS`.

> Nếu chạy trên máy khác: sửa đường dẫn trong `run_all_local.sql`, hoặc mở từng file
> `01 → 07` theo đúng thứ tự và Execute lần lượt (cách này không cần SQLCMD Mode).

### 2.2. Cách B — dòng lệnh (sqlcmd)

```powershell
cd sql
sqlcmd -S localhost -E -C -i 01_schema.sql -i 02_triggers.sql -i 03_functions_views.sql -i 04_procedures.sql -i 05_sample_data.sql -i 06_reports.sql -i 07_business_rule_tests.sql
```

> `-E` = Windows Authentication, `-C` = trust server certificate. Thay `-S` bằng
> tên instance của bạn (ví dụ `localhost\SQLEXPRESS`). Cách này luôn chạy ở context `master`.

### 2.3. Trình tự an toàn khi reset database

1. **Tắt web app** nếu đang chạy (Ctrl+C ở cửa sổ chạy Flask). Web app dùng pyodbc mở/đóng
   kết nối theo từng request nên thường không giữ `LMS`, nhưng tắt hẳn cho chắc.
2. Đóng các tab query SSMS đang nối vào `LMS` (hoặc chuyển chúng sang `master`).
3. Chạy `run_all_local.sql` (theo mục 2.1) → đợi `TEST 10: PASS`.
4. Bật lại web app khi cần demo.

> Các file SQL **phải chạy đúng thứ tự** `01 → 07` (qua runner script hoặc thủ công),
> vì file sau phụ thuộc object do file trước tạo.

## 2b. Vai trò của web app demo

- **SQL Server là dự án chính (core).** Toàn bộ logic nghiệp vụ nằm ở schema, ràng buộc,
  trigger, function, view, stored procedure và các truy vấn báo cáo.
- **`webapp/` chỉ là lớp demo/thuyết trình nhẹ.** Nó **không** chứa logic nghiệp vụ riêng;
  nó đọc dữ liệu và gọi các object có sẵn trong database.
- **Web app dùng dữ liệu SQL Server THẬT** (qua pyodbc + Windows Authentication), **không**
  dùng dữ liệu giả ở frontend, không mock, không JSON/SQLite/localStorage.
- Chi tiết cài đặt & cách chạy web app: xem [`webapp/README.md`](webapp/README.md).

## 3. Sơ đồ thực thể quan hệ (ERD)

![ERD](docs/erd.png)

<details><summary>Mã nguồn mermaid của ERD</summary>

```mermaid
erDiagram
    Users ||--o{ Courses : "teaches (Instructor)"
    Users ||--o{ Enrollments : "enrolls (Student)"
    Users ||--o{ Submissions : "submits"
    Users ||--o{ Grades : "grades"
    Categories ||--o{ Courses : "classifies"
    Courses ||--o{ Modules : "has"
    Courses ||--o{ Enrollments : "has"
    Courses ||--o{ Assignments : "has"
    Courses ||--o{ ForumThreads : "has"
    Modules ||--o{ Materials : "contains"
    Assignments ||--o{ Questions : "has"
    Assignments ||--o{ Submissions : "receives"
    Questions ||--o{ QuestionOptions : "has"
    Submissions ||--o{ StudentAnswers : "contains"
    Submissions ||--|| Grades : "evaluated by"
    QuestionOptions ||--o{ StudentAnswers : "chosen in"
    ForumThreads ||--o{ ForumPosts : "has"
    Users ||--o{ Recommendations : "receives"
    Courses ||--o{ Recommendations : "recommended"
    Users ||--o{ InteractionLogs : "generates"
    Users ||--o{ Certificates : "earns"
    Courses ||--o{ Certificates : "certified by"
```

</details>

## 4. Danh sách bảng

| Bảng | Vai trò |
|------|---------|
| `Users` | Người dùng + vai trò (Student/Instructor/Admin) |
| `Categories` | Danh mục khóa học |
| `Courses` | Khóa học, mỗi khóa do một giảng viên quản lý |
| `Modules` | Chương/mô-đun của khóa học |
| `Materials` | Học liệu (Document/Video/Link/Slide) |
| `Enrollments` | Đăng ký học (quan hệ N-N giữa Student và Course) |
| `Assignments` | Bài tập/Quiz/Exam (bắt buộc có deadline) |
| `Questions`, `QuestionOptions` | Câu hỏi trắc nghiệm + đáp án (chấm tự động) |
| `Submissions` | Bài nộp (1 student + 1 assignment) |
| `StudentAnswers` | Lựa chọn của sinh viên cho quiz |
| `Grades` | Điểm cho mỗi bài nộp đã chấm |
| `ForumThreads`, `ForumPosts` | Thảo luận/diễn đàn |
| `Recommendations` | Gợi ý khóa học (AI) + theo dõi hiệu quả |
| `InteractionLogs` | Nhật ký tương tác phục vụ phân tích |
| `Certificates` | Chứng chỉ hoàn thành khóa (chỉ cấp khi điểm tổng kết ≥ 80%) |

## 5. Quy tắc nghiệp vụ và nơi thực thi

| Business Rule | Cơ chế thực thi |
|---------------|-----------------|
| Mỗi user có tài khoản & vai trò duy nhất | `UNIQUE(Username/Email)` + `CHECK CK_Users_Role` |
| Student–Course là quan hệ N-N | Bảng `Enrollments` + `UNIQUE(StudentID, CourseID)` |
| Mỗi khóa do **một** giảng viên quản lý | FK + trigger `trg_Courses_InstructorRole` |
| Bài tập/đánh giá phải có deadline | `Deadline DATETIME2 NOT NULL` |
| Nộp trễ → đánh dấu late / từ chối theo policy | trigger `trg_Submissions_Policy` |
| Nộp trễ cũng xử lý khi cập nhật bài nộp | trigger `trg_Submissions_Policy` (AFTER INSERT, UPDATE) |
| Mỗi bài nộp gắn 1 student + 1 assignment | FK + `UNIQUE(AssignmentID, StudentID, Attempt)` |
| Phải có điểm cho mỗi bài đã chấm | bảng `Grades` + trigger `trg_Grades_MarkGraded` |
| Người chấm phải là Instructor/Admin (NULL = hệ thống tự chấm) | trigger `trg_Grades_MarkGraded` |
| Đáp án sinh viên chọn phải thuộc đúng câu hỏi | trigger `trg_StudentAnswers_OptionMatchesQuestion` |
| Sinh viên chỉ truy cập khóa đã đăng ký | hàm `fn_CanAccessCourse`, `fn_AccessibleMaterials`, chặn nộp bài khi chưa đăng ký |
| Khóa `Published` phải có ≥ 1 module (cả khi INSERT lẫn UPDATE) | trigger `trg_Courses_PublishNeedsModule`, `trg_Modules_KeepAtLeastOne` |
| Chứng chỉ chỉ cấp khi điểm tổng kết khóa ≥ 80% (Coursera-style) | `CHECK CK_Cert_Pass` + `sp_IssueCertificate` + `fn_CourseFinalGrade` |

## 6. Tính năng AI / xử lý dữ liệu

- `sp_RecommendCourses` — gợi ý khóa học theo danh mục sinh viên đang học (content-based), lưu lại để đo hiệu quả.
- `sp_AutoGradeQuiz` — tự động chấm quiz/exam trắc nghiệm, quy đổi về thang điểm `MaxScore`.
- `InteractionLogs` — ghi nhận hành vi để phân tích (active users, session duration).
- **Chứng chỉ (Coursera-style):** `fn_CourseFinalGrade` tính điểm tổng kết khóa (%), `fn_HasPassedCourse` xác định đạt ≥ 80%; `sp_IssueCertificate` cấp chứng chỉ và đánh dấu hoàn thành khóa. Ngưỡng 80% được khóa cứng bởi `CHECK CK_Cert_Pass` trên bảng `Certificates`.

## 7. Báo cáo (`06_reports.sql`)

1. Báo cáo kết quả học tập của sinh viên (điểm, tiến độ)
2. Tỷ lệ đăng ký & hoàn thành theo khóa học
3. Hoạt động giảng viên & hiệu quả khóa học
4. Thống kê nộp bài đúng hạn vs trễ hạn
5. Phân tích sử dụng hệ thống (người dùng hoạt động, thời lượng phiên)
6. Hiệu quả gợi ý của AI (CTR, tỷ lệ chuyển đổi)

## 8. Ghi chú thiết kế: mô hình vai trò đơn giản hóa (Role model)

Triển khai này **cố ý** dùng mô hình phân quyền đơn giản hóa để phù hợp phạm vi DBI202:

- **`Users.Role`** lưu trực tiếp một trong ba giá trị: `Student`, `Instructor`, `Admin`
  (ràng buộc bởi `CHECK CK_Users_Role`). **Không** tách thành các bảng
  `Roles` / `Actions` / `Role_Actions`.
- **Quyền theo vai trò** (ví dụ: ai được VIEW/EDIT khóa học, ai được chấm điểm,
  ai được nhận gợi ý) được biểu diễn ở **tầng business-rule / stored procedure /
  trigger**, thay vì bảng phân quyền riêng. Ví dụ:
  - `trg_Courses_InstructorRole`: chỉ `Instructor` mới sở hữu khóa học.
  - `trg_Enroll_Validate`: chỉ `Student` mới ghi danh.
  - `trg_Grades_MarkGraded`: chỉ `Instructor`/`Admin` (hoặc hệ thống = `NULL`) mới chấm điểm.
  - `sp_RecommendCourses`: chỉ sinh ra gợi ý cho `Student`.
- Lựa chọn này giúp schema gọn, dễ trình bày và đủ thể hiện đầy đủ nghiệp vụ
  multi-role mà không cần mô hình RBAC đầy đủ.

### Bản đồ ERD thực tế (khớp schema đã hiện thực)

- **`Users`** — gộp cả ba vai trò vào một bảng qua cột `Role` (không có bảng `Roles` riêng).
- **`Assignments`** — đại diện cho cả `Assignment` / `Quiz` / `Exam` thông qua cột `AType`.
- **`Questions`, `QuestionOptions`, `StudentAnswers`** — hỗ trợ câu hỏi trắc nghiệm
  khách quan và **chấm tự động** (`sp_AutoGradeQuiz`).
- **`ForumThreads`, `ForumPosts`** — hỗ trợ thảo luận diễn đàn và trả lời lồng nhau
  (`ForumPosts.ParentPostID` tự tham chiếu).
- **`Recommendations`** — lưu gợi ý khóa học do module AI sinh ra + trạng thái để đo hiệu quả.
- **`InteractionLogs`** — lưu hành vi người dùng phục vụ phân tích (active users, session duration).

## 9. Xử lý sự cố (Troubleshooting)

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `Msg 102: Incorrect syntax near ':'` khi chạy runner | Chưa bật **SQLCMD Mode** | Menu `Query > SQLCMD Mode`, rồi chạy lại |
| `The file specified for :r command was not found` | `run_all.sql` dùng đường dẫn **tương đối**, SSMS không tìm thấy | Dùng `run_all_local.sql` (đường dẫn tuyệt đối), hoặc sửa lại đường dẫn cho đúng máy |
| Lỗi `connection broken / unrecoverable`, DB hiện **`LMS (Single User)`** | Cửa sổ query đang đứng trong `LMS` khi script `DROP DATABASE LMS` → tự khóa chính mình | Đổi database trên thanh công cụ sang **`master`** rồi chạy lại. Nếu vẫn kẹt Single User: chạy `ALTER DATABASE LMS SET MULTI_USER;` từ một cửa sổ nối vào `master` |
| `Msg 208: Invalid object name 'sp_...'` khi tạo procedure | Có procedure tên `sp_...` bị lỡ tạo trong database `master` (do từng chạy lẻ đoạn `CREATE PROCEDURE` khi đang đứng ở `master`); tên `sp_` được SQL Server tra ở `master` trước | Xóa proc "ma" trong `master`: `DROP PROCEDURE IF EXISTS dbo.sp_EnrollStudent, dbo.sp_SubmitAssignment, dbo.sp_GradeSubmission, dbo.sp_AutoGradeQuiz, dbo.sp_RecommendCourses;` (chạy ở `master`), rồi chạy lại runner. **Phòng ngừa:** luôn chạy nguyên file (đã có `USE LMS;`), không bôi đen chạy lẻ khi đứng ở `master` |
| Reset database báo lỗi đang bị dùng / kẹt Single User | Web app hoặc tab SSMS đang giữ kết nối tới `LMS` | **Tắt web app** (Ctrl+C) và đóng/đổi tab SSMS sang `master` trước khi chạy runner (xem mục 2.3) |
| Web app `/health` trả lỗi kết nối | Sai tên ODBC driver, hoặc thiếu `TrustServerCertificate` | Kiểm tra `webapp/.env` đúng `DB_DRIVER=ODBC Driver 18 for SQL Server` và `DB_TRUST_SERVER_CERTIFICATE=yes` |
