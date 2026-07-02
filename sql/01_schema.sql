/* =====================================================================
   ONLINE LEARNING MANAGEMENT SYSTEM (LMS)
   File 01 - SCHEMA (DDL): databases, tables, keys & constraints
   DBMS: Microsoft SQL Server (T-SQL)
   ---------------------------------------------------------------------
   Run order: 01_schema -> 02_triggers -> 03_functions_views
              -> 04_procedures -> 05_sample_data -> 06_reports
   ===================================================================== */

IF DB_ID('LMS') IS NOT NULL
BEGIN
    ALTER DATABASE LMS SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LMS;
END
GO
CREATE DATABASE LMS;
GO
USE LMS;
GO

CREATE TABLE Users (
    UserID        INT IDENTITY(1,1) PRIMARY KEY,
    Username      VARCHAR(50)   NOT NULL,
    PasswordHash  VARCHAR(255)  NOT NULL,
    Email         VARCHAR(150)  NOT NULL,
    FullName      NVARCHAR(150) NOT NULL,
    DateOfBirth   DATE          NULL,
    Role          VARCHAR(20)   NOT NULL,
    Status        VARCHAR(20)   NOT NULL CONSTRAINT DF_Users_Status DEFAULT ('Active'),
    CreatedAt     DATETIME2     NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT CK_Users_Username_Length CHECK (LEN(Username) >= 3),
    CONSTRAINT UQ_Users_Username UNIQUE (Username),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT CK_Users_Role   CHECK (Role   IN ('Student','Instructor','Admin')),
    CONSTRAINT CK_Users_Status CHECK (Status IN ('Active','Inactive','Banned')),
    CONSTRAINT CK_Users_Email  CHECK (Email LIKE '%_@_%._%')
);
GO

CREATE TABLE Categories (
    CategoryID   INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(100) NOT NULL,
    Description  NVARCHAR(500) NULL,
    CONSTRAINT UQ_Categories_Name UNIQUE (CategoryName)
);
GO

CREATE TABLE Courses (
    CourseID     INT IDENTITY(1,1) PRIMARY KEY,
    CourseCode   VARCHAR(20)   NOT NULL,
    Title        NVARCHAR(200) NOT NULL,
    Description  NVARCHAR(MAX) NULL,
    InstructorID INT           NOT NULL,
    CategoryID   INT           NULL,
    Level        VARCHAR(20)   NOT NULL CONSTRAINT DF_Courses_Level DEFAULT ('Beginner'),
    Price        DECIMAL(10,2) NOT NULL CONSTRAINT DF_Courses_Price DEFAULT (0),
    Status       VARCHAR(20)   NOT NULL CONSTRAINT DF_Courses_Status DEFAULT ('Draft'),
    CreatedAt    DATETIME2     NOT NULL CONSTRAINT DF_Courses_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT UQ_Courses_Code UNIQUE (CourseCode),
    CONSTRAINT FK_Courses_Instructor FOREIGN KEY (InstructorID) REFERENCES Users(UserID),
    CONSTRAINT FK_Courses_Category   FOREIGN KEY (CategoryID)   REFERENCES Categories(CategoryID),
    CONSTRAINT CK_Courses_Level  CHECK (Level  IN ('Beginner','Intermediate','Advanced')),
    CONSTRAINT CK_Courses_Status CHECK (Status IN ('Draft','Published','Archived')),
    CONSTRAINT CK_Courses_Price  CHECK (Price >= 0)
);
GO

CREATE TABLE Modules (
    ModuleID    INT IDENTITY(1,1) PRIMARY KEY,
    CourseID    INT           NOT NULL,
    Title       NVARCHAR(200) NOT NULL,
    Description NVARCHAR(500) NULL,
    OrderIndex  INT           NOT NULL CONSTRAINT DF_Modules_Order DEFAULT (1),
    CONSTRAINT FK_Modules_Course FOREIGN KEY (CourseID)
        REFERENCES Courses(CourseID) ON DELETE CASCADE,
    CONSTRAINT UQ_Modules_Order UNIQUE (CourseID, OrderIndex)
);
GO

CREATE TABLE Materials (
    MaterialID  INT IDENTITY(1,1) PRIMARY KEY,
    ModuleID    INT           NOT NULL,
    Title       NVARCHAR(200) NOT NULL,
    MaterialType VARCHAR(20)  NOT NULL,
    ContentURL  NVARCHAR(500) NOT NULL,
    OrderIndex  INT           NOT NULL CONSTRAINT DF_Materials_Order DEFAULT (1),
    CreatedAt   DATETIME2     NOT NULL CONSTRAINT DF_Materials_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Materials_Module FOREIGN KEY (ModuleID)
        REFERENCES Modules(ModuleID) ON DELETE CASCADE,
    CONSTRAINT CK_Materials_Type CHECK (MaterialType IN ('Document','Video','Link','Slide'))
);
GO

CREATE TABLE Enrollments (
    EnrollmentID     INT IDENTITY(1,1) PRIMARY KEY,
    StudentID        INT          NOT NULL,
    CourseID         INT          NOT NULL,
    EnrollDate       DATETIME2    NOT NULL CONSTRAINT DF_Enroll_Date DEFAULT (SYSDATETIME()),
    Status           VARCHAR(20)  NOT NULL CONSTRAINT DF_Enroll_Status DEFAULT ('Active'),
    ProgressPercent  DECIMAL(5,2) NOT NULL CONSTRAINT DF_Enroll_Progress DEFAULT (0),
    CompletedAt      DATETIME2    NULL,
    CONSTRAINT FK_Enroll_Student FOREIGN KEY (StudentID) REFERENCES Users(UserID),
    CONSTRAINT FK_Enroll_Course  FOREIGN KEY (CourseID)  REFERENCES Courses(CourseID),
    CONSTRAINT UQ_Enroll UNIQUE (StudentID, CourseID),
    CONSTRAINT CK_Enroll_Status   CHECK (Status IN ('Active','Completed','Dropped')),
    CONSTRAINT CK_Enroll_Progress CHECK (ProgressPercent BETWEEN 0 AND 100)
);
GO

CREATE TABLE Assignments (
    AssignmentID INT IDENTITY(1,1) PRIMARY KEY,
    CourseID     INT           NOT NULL,
    Title        NVARCHAR(200) NOT NULL,
    Description  NVARCHAR(MAX) NULL,
    Atype        VARCHAR(20)   NOT NULL,
    MaxScore     DECIMAL(5,2)  NOT NULL CONSTRAINT DF_Assign_Max DEFAULT (10),
    Deadline     DATETIME2     NOT NULL,
    LatePolicy   VARCHAR(20)   NOT NULL CONSTRAINT DF_Assign_Late DEFAULT ('AcceptLate'),
    PenaltyPct   DECIMAL(5,2)  NOT NULL CONSTRAINT DF_Assign_Penalty DEFAULT (0),
    CreatedAt    DATETIME2     NOT NULL CONSTRAINT DF_Assign_Created DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Assign_Course FOREIGN KEY (CourseID)
        REFERENCES Courses(CourseID) ON DELETE CASCADE,
    CONSTRAINT CK_Assign_Type    CHECK (AType IN ('Assignment','Quiz','Exam')),
    CONSTRAINT CK_Assign_Late    CHECK (LatePolicy IN ('AcceptLate','RejectLate','Penalty')),
    CONSTRAINT CK_Assign_Max     CHECK (MaxScore > 0),
    CONSTRAINT CK_Assign_Penalty CHECK (PenaltyPct BETWEEN 0 AND 100)
);
GO

CREATE TABLE Questions (
    QuestionID   INT IDENTITY(1,1) PRIMARY KEY,
    AssignmentID INT           NOT NULL,
    QuestionText NVARCHAR(MAX) NOT NULL,
    Points       DECIMAL(5,2)  NOT NULL CONSTRAINT DF_Q_Points DEFAULT (1),
    CONSTRAINT FK_Questions_Assignment FOREIGN KEY (AssignmentID)
        REFERENCES Assignments(AssignmentID) ON DELETE CASCADE,
    CONSTRAINT CK_Q_Points CHECK (Points > 0)
);
GO

CREATE TABLE QuestionOptions (
    OptionID   INT IDENTITY(1,1) PRIMARY KEY,
    QuestionID INT           NOT NULL,
    OptionText NVARCHAR(500) NOT NULL,
    IsCorrect  BIT           NOT NULL CONSTRAINT DF_Opt_Correct DEFAULT (0),
    CONSTRAINT FK_Options_Question FOREIGN KEY (QuestionID)
        REFERENCES Questions(QuestionID) ON DELETE CASCADE
);
GO

CREATE TABLE Submissions (
    SubmissionID INT IDENTITY(1,1) PRIMARY KEY,
    AssignmentID INT           NOT NULL,
    StudentID    INT           NOT NULL,
    SubmittedAt  DATETIME2     NOT NULL CONSTRAINT DF_Sub_At DEFAULT (SYSDATETIME()),
    ContentURL   NVARCHAR(500) NULL,
    IsLate       BIT           NOT NULL CONSTRAINT DF_Sub_Late DEFAULT (0),
    Status       VARCHAR(20)   NOT NULL CONSTRAINT DF_Sub_Status DEFAULT ('Submitted'),
    Attempt      INT           NOT NULL CONSTRAINT DF_Sub_Attempt DEFAULT (1),
    CONSTRAINT FK_Sub_Assignment FOREIGN KEY (AssignmentID) REFERENCES Assignments(AssignmentID),
    CONSTRAINT FK_Sub_Student    FOREIGN KEY (StudentID)    REFERENCES Users(UserID),
    CONSTRAINT UQ_Sub UNIQUE (AssignmentID, StudentID, Attempt),
    CONSTRAINT CK_Sub_Status CHECK (Status IN ('Submitted','Graded','Rejected'))
);
GO

CREATE TABLE StudentAnswers (
    AnswerID         INT IDENTITY(1,1) PRIMARY KEY,
    SubmissionID     INT NOT NULL,
    QuestionID       INT NOT NULL,
    SelectedOptionID INT NULL,
    CONSTRAINT FK_Ans_Submission FOREIGN KEY (SubmissionID)
        REFERENCES Submissions(SubmissionID) ON DELETE CASCADE,
    CONSTRAINT FK_Ans_Question FOREIGN KEY (QuestionID)   REFERENCES Questions(QuestionID),
    CONSTRAINT FK_Ans_Option   FOREIGN KEY (SelectedOptionID) REFERENCES QuestionOptions(OptionID),
    CONSTRAINT UQ_Ans UNIQUE (SubmissionID, QuestionID)
);
GO

CREATE TABLE Grades (
    GradeID      INT IDENTITY(1,1) PRIMARY KEY,
    SubmissionID INT           NOT NULL,
    Score        DECIMAL(5,2)  NOT NULL,
    Feedback     NVARCHAR(MAX) NULL,
    GradedBy     INT           NULL,
    GradedAt     DATETIME2     NOT NULL CONSTRAINT DF_Grade_At DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Grade_Submission FOREIGN KEY (SubmissionID)
        REFERENCES Submissions(SubmissionID) ON DELETE CASCADE,
    CONSTRAINT FK_Grade_GradedBy FOREIGN KEY (GradedBy) REFERENCES Users(UserID),
    CONSTRAINT UQ_Grade UNIQUE (SubmissionID),
    CONSTRAINT CK_Grade_Score CHECK (Score >= 0)
);
GO

CREATE TABLE ForumThreads (
    ThreadID  INT IDENTITY(1,1) PRIMARY KEY,
    CourseID  INT           NOT NULL,
    CreatedBy INT           NOT NULL,
    Title     NVARCHAR(200) NOT NULL,
    CreatedAt DATETIME2     NOT NULL CONSTRAINT DF_Thread_At DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Thread_Course FOREIGN KEY (CourseID)  REFERENCES Courses(CourseID) ON DELETE CASCADE,
    CONSTRAINT FK_Thread_User   FOREIGN KEY (CreatedBy) REFERENCES Users(UserID)
);
GO

CREATE TABLE ForumPosts (
    PostID       INT IDENTITY(1,1) PRIMARY KEY,
    ThreadID     INT           NOT NULL,
    UserID       INT           NOT NULL,
    Content      NVARCHAR(MAX) NOT NULL,
    ParentPostID INT           NULL,
    CreatedAt    DATETIME2     NOT NULL CONSTRAINT DF_Post_At DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Post_Thread FOREIGN KEY (ThreadID) REFERENCES ForumThreads(ThreadID) ON DELETE CASCADE,
    CONSTRAINT FK_Post_User   FOREIGN KEY (UserID)   REFERENCES Users(UserID),
    CONSTRAINT FK_Post_Parent FOREIGN KEY (ParentPostID) REFERENCES ForumPosts(PostID)
);
GO

CREATE TABLE Recommendations (
    RecommendationID INT IDENTITY(1,1) PRIMARY KEY,
    StudentID   INT           NOT NULL,
    CourseID    INT           NOT NULL,
    Reason      NVARCHAR(300) NULL,
    Score       DECIMAL(5,4)  NOT NULL CONSTRAINT DF_Rec_Score DEFAULT (0),
    Status      VARCHAR(20)   NOT NULL CONSTRAINT DF_Rec_Status DEFAULT ('Shown'),
    CreatedAt   DATETIME2     NOT NULL CONSTRAINT DF_Rec_At DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Rec_Student FOREIGN KEY (StudentID) REFERENCES Users(UserID),
    CONSTRAINT FK_Rec_Course  FOREIGN KEY (CourseID)  REFERENCES Courses(CourseID),
    CONSTRAINT CK_Rec_Status CHECK (Status IN ('Shown','Clicked','Enrolled','Ignored')),
    CONSTRAINT CK_Rec_Score  CHECK (Score BETWEEN 0 AND 1)
);
GO

CREATE TABLE InteractionLogs (
    LogID      BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserID     INT          NULL,
    SessionID  UNIQUEIDENTIFIER NOT NULL,
    ActionType VARCHAR(50)  NOT NULL,
    EntityType VARCHAR(50)  NULL,
    EntityID   INT          NULL,
    DurationSec INT         NULL,
    CreatedAt  DATETIME2    NOT NULL CONSTRAINT DF_Log_At DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_Log_User FOREIGN KEY (UserID) REFERENCES Users(UserID)
);
GO

CREATE TABLE Certificates (
    CertificateID INT IDENTITY(1,1) PRIMARY KEY,
    StudentID     INT          NOT NULL,
    CourseID      INT          NOT NULL,
    FinalScore    DECIMAL(5,2) NOT NULL,
    IssuedAt      DATETIME2    NOT NULL CONSTRAINT DF_Cert_At DEFAULT (SYSDATETIME()),
    CertificateCode AS ('LMS-CERT-' + RIGHT('00000' + CAST(CertificateID AS VARCHAR(10)), 5)),
    CONSTRAINT FK_Cert_Student FOREIGN KEY (StudentID) REFERENCES Users(UserID),
    CONSTRAINT FK_Cert_Course  FOREIGN KEY (CourseID)  REFERENCES Courses(CourseID),
    CONSTRAINT UQ_Cert UNIQUE (StudentID, CourseID),
    CONSTRAINT CK_Cert_Pass  CHECK (FinalScore >= 80.0),
    CONSTRAINT CK_Cert_Range CHECK (FinalScore BETWEEN 0 AND 100)
);
GO

CREATE INDEX IX_Courses_Instructor ON Courses(InstructorID);
CREATE INDEX IX_Enroll_Course      ON Enrollments(CourseID);
CREATE INDEX IX_Enroll_Student     ON Enrollments(StudentID);
CREATE INDEX IX_Sub_Student        ON Submissions(StudentID);
CREATE INDEX IX_Sub_Assignment     ON Submissions(AssignmentID);
CREATE INDEX IX_Log_User_Time      ON InteractionLogs(UserID, CreatedAt);
GO

PRINT 'Schema created successfully.';
GO
