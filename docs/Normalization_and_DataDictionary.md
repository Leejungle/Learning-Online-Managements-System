# Chuẩn hóa CSDL & Data Dictionary — LMS (DBI202)

Tài liệu này trình bày (A) quá trình chuẩn hóa cơ sở dữ liệu lên dạng **3NF**, và
(B) **từ điển dữ liệu** mô tả chi tiết từng bảng/cột. Sơ đồ quan hệ tổng thể xem ở
`docs/erd.png`.

![ERD](./erd.png)

---

## PHẦN A — CHUẨN HÓA (NORMALIZATION)

### A.0. Mô hình chưa chuẩn hóa (UNF) — xuất phát điểm

Giả sử ban đầu mọi dữ liệu nằm trong **một bảng phẳng** `EnrollmentSheet` (mô phỏng
một file Excel quản lý lớp học):

```
EnrollmentSheet (
    StudentID, StudentName, StudentEmail,
    CourseCode, CourseTitle, InstructorName, CategoryName,
    ModuleTitles,                         -- "M1; M2; M3"  (nhiều giá trị trong 1 ô)
    AssignmentTitle, Deadline,
    Score, Feedback, GradedByName
)
```

Bảng này vi phạm gần như tất cả các dạng chuẩn. Ta lần lượt đưa về 1NF → 2NF → 3NF.

---

### A.1. Dạng chuẩn 1 (1NF) — loại bỏ giá trị đa trị / nhóm lặp

**Quy tắc 1NF:** mỗi ô chỉ chứa một giá trị nguyên tử (atomic), không có nhóm lặp,
mỗi hàng được xác định bởi khóa chính.

- Cột `ModuleTitles = "M1; M2; M3"` là **đa trị** → vi phạm 1NF.
- Một sinh viên đăng ký nhiều khóa, mỗi khóa nhiều bài tập → nhóm lặp.

**Xử lý:** tách mỗi giá trị thành một hàng riêng và thêm khóa chính rõ ràng. Sau 1NF,
mỗi dòng mô tả đúng một (Student, Course, Assignment, Module) và không còn ô đa trị.

→ Kết quả: tất cả các bảng trong thiết kế cuối (`Users`, `Courses`, `Modules`,
`Materials`, `Enrollments`, `Assignments`, `Submissions`, `Grades`, …) đều có khóa
chính đơn (cột IDENTITY) và **không có cột đa trị** ⇒ **đạt 1NF**.

> Ví dụ minh họa: `ModuleTitles` đa trị được tách thành bảng `Modules` (mỗi module 1 hàng,
> tham chiếu `CourseID`), và `Materials` cho học liệu trong module.

---

### A.2. Dạng chuẩn 2 (2NF) — loại bỏ phụ thuộc hàm bộ phận

**Quy tắc 2NF:** đạt 1NF **và** mọi thuộc tính không khóa phụ thuộc vào **toàn bộ**
khóa chính (không phụ thuộc một phần khóa kép).

Xét bảng trung gian sau khi gộp đăng ký + điểm, với khóa kép **(StudentID, CourseID, AssignmentID)**:

```
(StudentID, CourseID, AssignmentID) →
    StudentName, StudentEmail,        -- chỉ phụ thuộc StudentID  (phụ thuộc bộ phận)
    CourseTitle, InstructorName,      -- chỉ phụ thuộc CourseID    (phụ thuộc bộ phận)
    AssignmentTitle, Deadline,        -- chỉ phụ thuộc AssignmentID (phụ thuộc bộ phận)
    Score, Feedback                   -- phụ thuộc toàn bộ khóa  (hợp lệ)
```

Các phụ thuộc bộ phận (partial dependency) vi phạm 2NF. **Xử lý:** tách thành các
bảng theo đúng "nguồn" của phụ thuộc:

| Phụ thuộc bộ phận | Bảng được tách ra |
|---|---|
| `StudentID → StudentName, Email` | **`Users`** |
| `CourseID → CourseTitle, InstructorID` | **`Courses`** |
| `AssignmentID → Title, Deadline` | **`Assignments`** |
| `(Student, Assignment) → Score, Feedback` | **`Submissions` + `Grades`** |
| Quan hệ N-N Student↔Course | **`Enrollments`** |

→ Sau khi tách, mỗi thuộc tính không khóa phụ thuộc **đầy đủ** vào khóa của bảng chứa nó
⇒ **đạt 2NF**.

---

### A.3. Dạng chuẩn 3 (3NF) — loại bỏ phụ thuộc bắc cầu

**Quy tắc 3NF:** đạt 2NF **và** không có thuộc tính không khóa nào phụ thuộc bắc cầu
(transitive) vào khóa chính (tức không khóa → không khóa).

Xét bảng `Courses` còn chứa thông tin lặp:

```
CourseID → InstructorID → InstructorName, InstructorEmail   (bắc cầu)
CourseID → CategoryID   → CategoryName, CategoryDescription (bắc cầu)
```

`InstructorName` không phụ thuộc trực tiếp vào `CourseID` mà qua `InstructorID`
→ phụ thuộc bắc cầu, vi phạm 3NF (gây dư thừa & bất thường cập nhật).

**Xử lý:**
- Thông tin giảng viên chuyển hết về bảng **`Users`**; `Courses` chỉ giữ khóa ngoại `InstructorID`.
- Thông tin danh mục chuyển về bảng **`Categories`**; `Courses` chỉ giữ `CategoryID`.

Tương tự:
- `Submissions` chỉ giữ `AssignmentID`, không lặp lại `Deadline`/`MaxScore` (lấy từ `Assignments`).
- `Grades.GradedBy` là FK tới `Users` thay vì lưu `GradedByName`.

→ Sau bước này **không còn phụ thuộc bắc cầu** ⇒ toàn bộ schema **đạt 3NF**.

#### Bảng kiểm tra 3NF cho các bảng chính

| Bảng | Khóa chính | Phụ thuộc hàm xác định | 3NF? |
|---|---|---|---|
| `Users` | UserID | UserID → Username, Email, FullName, Role, Status | ✅ |
| `Categories` | CategoryID | CategoryID → CategoryName, Description | ✅ |
| `Courses` | CourseID | CourseID → CourseCode, Title, InstructorID, CategoryID, Level, Status | ✅ |
| `Modules` | ModuleID | ModuleID → CourseID, Title, OrderIndex | ✅ |
| `Materials` | MaterialID | MaterialID → ModuleID, Title, MaterialType, ContentURL | ✅ |
| `Enrollments` | EnrollmentID | EnrollmentID → StudentID, CourseID, Status, ProgressPercent | ✅ |
| `Assignments` | AssignmentID | AssignmentID → CourseID, Title, AType, MaxScore, Deadline, LatePolicy | ✅ |
| `Questions` | QuestionID | QuestionID → AssignmentID, QuestionText, Points | ✅ |
| `QuestionOptions` | OptionID | OptionID → QuestionID, OptionText, IsCorrect | ✅ |
| `Submissions` | SubmissionID | SubmissionID → AssignmentID, StudentID, SubmittedAt, IsLate, Status | ✅ |
| `StudentAnswers` | AnswerID | AnswerID → SubmissionID, QuestionID, SelectedOptionID | ✅ |
| `Grades` | GradeID | GradeID → SubmissionID, Score, Feedback, GradedBy, GradedAt | ✅ |
| `Recommendations` | RecommendationID | RecommendationID → StudentID, CourseID, Score, Status | ✅ |
| `InteractionLogs` | LogID | LogID → UserID, SessionID, ActionType, DurationSec, CreatedAt | ✅ |

> **Ghi chú BCNF:** các bảng đều có một khóa chính đơn và mọi định thức (determinant)
> đều là khóa dự tuyển, nên schema cũng thỏa **BCNF**. Riêng `Users` có ràng buộc
> `Username`/`Email` là khóa dự tuyển (UNIQUE), vẫn thỏa BCNF.

---

## PHẦN B — DATA DICTIONARY (TỪ ĐIỂN DỮ LIỆU)

Ký hiệu: **PK** = khóa chính, **FK** = khóa ngoại, **UK** = khóa duy nhất (UNIQUE),
**NN** = NOT NULL.

### B.1. `Users` — Người dùng
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| UserID | INT IDENTITY | PK | Định danh người dùng |
| Username | VARCHAR(50) | NN, UK, LEN≥3 | Tên đăng nhập |
| PasswordHash | VARCHAR(255) | NN | Mật khẩu đã băm |
| Email | VARCHAR(150) | NN, UK, định dạng email | Email |
| FullName | NVARCHAR(150) | NN | Họ tên |
| DateOfBirth | DATE | NULL | Ngày sinh |
| Role | VARCHAR(20) | NN, CHECK(Student/Instructor/Admin) | Vai trò |
| Status | VARCHAR(20) | NN, default 'Active' | Active/Inactive/Banned |
| CreatedAt | DATETIME2 | NN, default now | Thời điểm tạo |

### B.2. `Categories` — Danh mục khóa học
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| CategoryID | INT IDENTITY | PK | Định danh danh mục |
| CategoryName | NVARCHAR(100) | NN, UK | Tên danh mục |
| Description | NVARCHAR(500) | NULL | Mô tả |

### B.3. `Courses` — Khóa học
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| CourseID | INT IDENTITY | PK | Định danh khóa học |
| CourseCode | VARCHAR(20) | NN, UK | Mã khóa học |
| Title | NVARCHAR(200) | NN | Tên khóa học |
| Description | NVARCHAR(MAX) | NULL | Mô tả |
| InstructorID | INT | NN, FK→Users | Giảng viên quản lý (phải Role=Instructor) |
| CategoryID | INT | FK→Categories | Danh mục |
| Level | VARCHAR(20) | CHECK(Beginner/Intermediate/Advanced) | Cấp độ |
| Price | DECIMAL(10,2) | CHECK ≥0 | Học phí |
| Status | VARCHAR(20) | CHECK(Draft/Published/Archived) | Trạng thái |
| CreatedAt | DATETIME2 | NN, default now | Ngày tạo |

### B.4. `Modules` — Mô-đun/Chương
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| ModuleID | INT IDENTITY | PK | Định danh module |
| CourseID | INT | NN, FK→Courses (CASCADE) | Khóa học chứa module |
| Title | NVARCHAR(200) | NN | Tên module |
| Description | NVARCHAR(500) | NULL | Mô tả |
| OrderIndex | INT | NN, UK(CourseID,OrderIndex) | Thứ tự trong khóa |

### B.5. `Materials` — Học liệu
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| MaterialID | INT IDENTITY | PK | Định danh học liệu |
| ModuleID | INT | NN, FK→Modules (CASCADE) | Module chứa học liệu |
| Title | NVARCHAR(200) | NN | Tiêu đề |
| MaterialType | VARCHAR(20) | CHECK(Document/Video/Link/Slide) | Loại học liệu |
| ContentURL | NVARCHAR(500) | NN | Đường dẫn nội dung |
| OrderIndex | INT | NN | Thứ tự |
| CreatedAt | DATETIME2 | NN, default now | Ngày tạo |

### B.6. `Enrollments` — Đăng ký học (N-N Student↔Course)
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| EnrollmentID | INT IDENTITY | PK | Định danh đăng ký |
| StudentID | INT | NN, FK→Users | Sinh viên (phải Role=Student) |
| CourseID | INT | NN, FK→Courses | Khóa học |
| EnrollDate | DATETIME2 | NN, default now | Ngày đăng ký |
| Status | VARCHAR(20) | CHECK(Active/Completed/Dropped) | Trạng thái |
| ProgressPercent | DECIMAL(5,2) | CHECK 0..100 | Tiến độ |
| CompletedAt | DATETIME2 | NULL | Thời điểm hoàn thành |
| | | **UK(StudentID, CourseID)** | Không trùng đăng ký |

### B.7. `Assignments` — Bài tập/Quiz/Exam
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| AssignmentID | INT IDENTITY | PK | Định danh bài tập |
| CourseID | INT | NN, FK→Courses (CASCADE) | Khóa học |
| Title | NVARCHAR(200) | NN | Tiêu đề |
| Description | NVARCHAR(MAX) | NULL | Mô tả |
| AType | VARCHAR(20) | CHECK(Assignment/Quiz/Exam) | Loại đánh giá |
| MaxScore | DECIMAL(5,2) | CHECK >0 | Điểm tối đa |
| Deadline | DATETIME2 | **NN** | Hạn nộp (bắt buộc) |
| LatePolicy | VARCHAR(20) | CHECK(AcceptLate/RejectLate/Penalty) | Chính sách nộp trễ |
| PenaltyPct | DECIMAL(5,2) | CHECK 0..100 | % trừ điểm khi trễ |
| CreatedAt | DATETIME2 | NN, default now | Ngày tạo |

### B.8. `Questions` — Câu hỏi trắc nghiệm
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| QuestionID | INT IDENTITY | PK | Định danh câu hỏi |
| AssignmentID | INT | NN, FK→Assignments (CASCADE) | Quiz/Exam chứa câu hỏi |
| QuestionText | NVARCHAR(MAX) | NN | Nội dung câu hỏi |
| Points | DECIMAL(5,2) | CHECK >0 | Điểm câu hỏi |

### B.9. `QuestionOptions` — Đáp án lựa chọn
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| OptionID | INT IDENTITY | PK | Định danh đáp án |
| QuestionID | INT | NN, FK→Questions (CASCADE) | Câu hỏi |
| OptionText | NVARCHAR(500) | NN | Nội dung đáp án |
| IsCorrect | BIT | NN, default 0 | Là đáp án đúng? |

### B.10. `Submissions` — Bài nộp
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| SubmissionID | INT IDENTITY | PK | Định danh bài nộp |
| AssignmentID | INT | NN, FK→Assignments | Bài tập |
| StudentID | INT | NN, FK→Users | Sinh viên nộp |
| SubmittedAt | DATETIME2 | NN, default now | Thời điểm nộp |
| ContentURL | NVARCHAR(500) | NULL | Đường dẫn bài nộp |
| IsLate | BIT | NN, default 0 | Nộp trễ? (trigger tự set) |
| Status | VARCHAR(20) | CHECK(Submitted/Graded/Rejected) | Trạng thái |
| Attempt | INT | NN, default 1 | Lần nộp |
| | | **UK(AssignmentID,StudentID,Attempt)** | Không trùng lần nộp |

### B.11. `StudentAnswers` — Câu trả lời của sinh viên
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| AnswerID | INT IDENTITY | PK | Định danh câu trả lời |
| SubmissionID | INT | NN, FK→Submissions (CASCADE) | Bài nộp quiz |
| QuestionID | INT | NN, FK→Questions | Câu hỏi |
| SelectedOptionID | INT | FK→QuestionOptions | Đáp án đã chọn |
| | | **UK(SubmissionID,QuestionID)** | Mỗi câu 1 lựa chọn |

### B.12. `Grades` — Điểm
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| GradeID | INT IDENTITY | PK | Định danh điểm |
| SubmissionID | INT | NN, FK→Submissions (CASCADE), **UK** | Bài nộp được chấm (1-1) |
| Score | DECIMAL(5,2) | CHECK ≥0, ≤MaxScore (trigger) | Điểm số |
| Feedback | NVARCHAR(MAX) | NULL | Phản hồi |
| GradedBy | INT | FK→Users | Người chấm (NULL=hệ thống tự chấm) |
| GradedAt | DATETIME2 | NN, default now | Thời điểm chấm |

### B.13. `ForumThreads` — Chủ đề thảo luận
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| ThreadID | INT IDENTITY | PK | Định danh chủ đề |
| CourseID | INT | NN, FK→Courses (CASCADE) | Khóa học |
| CreatedBy | INT | NN, FK→Users | Người tạo |
| Title | NVARCHAR(200) | NN | Tiêu đề |
| CreatedAt | DATETIME2 | NN, default now | Ngày tạo |

### B.14. `ForumPosts` — Bài viết thảo luận
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| PostID | INT IDENTITY | PK | Định danh bài viết |
| ThreadID | INT | NN, FK→ForumThreads (CASCADE) | Chủ đề |
| UserID | INT | NN, FK→Users | Người viết |
| Content | NVARCHAR(MAX) | NN | Nội dung |
| ParentPostID | INT | FK→ForumPosts (tự tham chiếu) | Trả lời bài nào |
| CreatedAt | DATETIME2 | NN, default now | Ngày viết |

### B.15. `Recommendations` — Gợi ý khóa học (AI)
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| RecommendationID | INT IDENTITY | PK | Định danh gợi ý |
| StudentID | INT | NN, FK→Users | Sinh viên nhận gợi ý |
| CourseID | INT | NN, FK→Courses | Khóa học gợi ý |
| Reason | NVARCHAR(300) | NULL | Lý do gợi ý |
| Score | DECIMAL(5,4) | CHECK 0..1 | Độ tin cậy |
| Status | VARCHAR(20) | CHECK(Shown/Clicked/Enrolled/Ignored) | Trạng thái (đo hiệu quả) |
| CreatedAt | DATETIME2 | NN, default now | Thời điểm gợi ý |

### B.16. `InteractionLogs` — Nhật ký tương tác
| Cột | Kiểu | Ràng buộc | Mô tả |
|---|---|---|---|
| LogID | BIGINT IDENTITY | PK | Định danh log |
| UserID | INT | FK→Users | Người dùng |
| SessionID | UNIQUEIDENTIFIER | NN | Định danh phiên |
| ActionType | VARCHAR(50) | NN | Loại hành động (Login, ViewMaterial...) |
| EntityType | VARCHAR(50) | NULL | Loại đối tượng |
| EntityID | INT | NULL | Định danh đối tượng |
| DurationSec | INT | NULL | Thời lượng (giây) |
| CreatedAt | DATETIME2 | NN, default now | Thời điểm |
