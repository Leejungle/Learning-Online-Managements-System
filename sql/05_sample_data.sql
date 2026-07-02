/* =====================================================================
   File 05 - SAMPLE DATA
   Inserted in an order that satisfies all triggers:
     users -> categories -> courses(Draft) -> modules -> materials
     -> publish courses -> enrollments -> assignments/quizzes
     -> submissions (via SP) -> grades -> forums -> recommendations -> logs
   ===================================================================== */
USE LMS;
GO
SET NOCOUNT ON;

INSERT INTO Users (Username, PasswordHash, Email, FullName, DateOfBirth, Role) VALUES
('admin01', 'hash_admin', 'admin@lms.edu',     N'Nguyen Quan Tri',    '1985-02-10', 'Admin'),
('teacher_an',  'hash_t1', 'an.le@lms.edu',     N'Le Van An',          '1982-05-21', 'Instructor'),
('teacher_binh','hash_t2', 'binh.tran@lms.edu', N'Tran Thi Binh',      '1988-09-12', 'Instructor'),
('teacher_cuong','hash_t3','cuong.pham@lms.edu',N'Pham Van Cuong',     '1979-11-30', 'Instructor'),
('sv_dung',  'hash_s1', 'dung@student.lms.edu',  N'Hoang Van Dung',    '2003-01-15', 'Student'),
('sv_giang', 'hash_s2', 'giang@student.lms.edu', N'Do Thi Giang',      '2004-03-22', 'Student'),
('sv_hai',   'hash_s3', 'hai@student.lms.edu',   N'Vu Van Hai',        '2003-07-08', 'Student'),
('sv_lan',   'hash_s4', 'lan@student.lms.edu',   N'Ngo Thi Lan',       '2004-12-01', 'Student'),
('sv_minh',  'hash_s5', 'minh@student.lms.edu',  N'Bui Van Minh',      '2002-06-18', 'Student'),
('sv_nga',   'hash_s6', 'nga@student.lms.edu',   N'Dang Thi Nga',      '2005-04-09', 'Student'),
('sv_phuc',  'hash_s7', 'phuc@student.lms.edu',  N'Ly Van Phuc',       '2003-10-25', 'Student'),
('sv_quyen', 'hash_s8', 'quyen@student.lms.edu', N'Ho Thi Quyen',      '2004-08-14', 'Student'),
('teacher_dao',  'hash_t4', 'dao.nguyen@lms.edu', N'Nguyen Thi Dao',  '1986-04-17', 'Instructor'),
('teacher_khoa', 'hash_t5', 'khoa.vo@lms.edu',    N'Vo Dang Khoa',     '1984-08-03', 'Instructor'),
('teacher_lien', 'hash_t6', 'lien.dinh@lms.edu',  N'Dinh Thi Lien',    '1990-01-26', 'Instructor'),
('teacher_son',  'hash_t7', 'son.truong@lms.edu', N'Truong Van Son',   '1983-12-11', 'Instructor'),
('teacher_tuan', 'hash_t8', 'tuan.nguyen@lms.edu',N'Nguyen Minh Tuan', '1987-03-19', 'Instructor'),
('teacher_haa',  'hash_t9', 'ha.tran@lms.edu',    N'Tran Thu Ha',      '1991-07-05', 'Instructor'),
('teacher_long', 'hash_t10','long.le@lms.edu',    N'Le Hoang Long',    '1985-10-22', 'Instructor'),
('teacher_maii', 'hash_t11','mai.pham@lms.edu',   N'Pham Thi Mai',     '1989-12-02', 'Instructor');
GO

INSERT INTO Categories (CategoryName, Description) VALUES
(N'Programming',          N'Software development & coding'),
(N'Database',             N'Databases and data management'),
(N'Data Science',         N'Data analysis, ML & AI'),
(N'Design',               N'UI/UX and graphic design'),
(N'Mathematics',          N'Foundational and applied mathematics'),
(N'Computer Science',     N'Core computer science fundamentals'),
(N'Artificial Intelligence', N'Machine learning, deep learning, CV & NLP'),
(N'Software Engineering', N'Software process, design & project management'),
(N'Soft Skills',          N'Communication, teamwork, ethics & career skills');
GO

INSERT INTO Courses (CourseCode, Title, Description, InstructorID, CategoryID, Level, Price, Status) VALUES
('PFP191', N'Programming Fundamental with Python',     N'Programming fundamentals using Python.',        2,  1, 'Beginner',     0,  'Draft'),
('DBI202', N'Database Systems',                        N'Relational database design, ER modeling & SQL.', 3,  2, 'Intermediate', 49, 'Draft'),
('DS301',  N'Data Science Foundations',                N'Statistics, pandas, ML basics.',                 4,  3, 'Advanced',     79, 'Draft'),
('WD110',  N'Web Development Basics',                   N'HTML, CSS, JavaScript.',                         2,  1, 'Beginner',     0,  'Draft'),
('UX150',  N'UI/UX Design Principles',                  N'Designing usable interfaces.',                   3,  4, 'Beginner',     29, 'Draft'),
('CSI106', N'Introduction to Computer Science',         N'Overview of computer science concepts.',         4,  6, 'Beginner',     0,  'Draft'),
('MAD101', N'Discrete Mathematics',                     N'Logic, sets, relations, graphs & combinatorics.', 13, 5, 'Intermediate', 0,  'Draft'),
('MAE101', N'Mathematics for Engineering',              N'Calculus and algebra for engineering.',          14, 5, 'Beginner',     0,  'Draft'),
('CSD201', N'Data Structures and Algorithms with C',    N'DSA implemented in the C language.',             15, 6, 'Intermediate', 0,  'Draft'),
('CSD203', N'Data Structures and Algorithms with Python',N'DSA implemented in Python.',                    16, 1, 'Intermediate', 0,  'Draft'),
('CEA201', N'Computer Organization and Architecture',   N'CPU, memory and computer architecture.',         13, 6, 'Intermediate', 0,  'Draft'),
('ADY201m',N'AI, Data Science with Python & SQL',       N'Foundations of AI & data science with Python and SQL.', 13, 3, 'Intermediate', 0, 'Draft'),
('ITE303c',N'Ethics in IT',                             N'Ethical, legal and social issues in information technology.', 20, 9, 'Beginner',    0, 'Draft'),
('MAI391', N'Mathematics for Machine Learning',         N'Linear algebra, calculus & probability for ML.',  15, 5, 'Intermediate', 0, 'Draft'),
('MAS291', N'Statistics & Probability',                 N'Probability theory and statistical inference.',   14, 5, 'Intermediate', 0, 'Draft'),
('AIL303m',N'Machine Learning',                         N'Supervised & unsupervised learning, model evaluation.', 17, 7, 'Advanced',  0, 'Draft'),
('CPV301', N'Computer Vision',                          N'Image processing, features, detection & deep CV.', 18, 7, 'Advanced',     0, 'Draft'),
('DAP391m',N'AI-DS Project',                            N'End-to-end applied AI / data science project.',   17, 7, 'Advanced',      0, 'Draft'),
('SWE201c',N'Introduction to Software Engineering',     N'SDLC, requirements, design, testing & DevOps.',   19, 8, 'Intermediate',  0, 'Draft'),
('SSG105', N'Communication and In-Group Working Skills',N'Communication, teamwork and collaboration skills.', 20, 9, 'Beginner',    0, 'Draft'),
('DPL302m',N'Deep Learning',                            N'Neural networks, CNNs, RNNs, transformers.',      18, 7, 'Advanced',      0, 'Draft'),
('DWP301c',N'Web Development with Python',              N'Building web apps with Python and Flask.',         2,  1, 'Intermediate', 0, 'Draft'),
('OJT202', N'On the Job Training',                      N'Supervised industry internship and reporting.',   19, 9, 'Advanced',      0, 'Draft'),
('NLP301c',N'Natural Language Processing',              N'Text processing, embeddings & language models.',  17, 7, 'Advanced',      0, 'Draft'),
('PMG201c',N'Project Management',                       N'Project life cycle, scope, schedule, cost & risk.', 19, 8, 'Intermediate', 0, 'Draft'),
('DAT301m',N'AI Development with TensorFlow',           N'Building and deploying models with TensorFlow.',  18, 7, 'Advanced',      0, 'Draft');
GO

INSERT INTO Modules (CourseID, Title, OrderIndex) VALUES
(1, N'Getting Started with Python',                 1),
(1, N'Control Flow & Functions',                    2),
(1, N'Variables, Numbers & Strings',                3),
(1, N'Operators & Expressions',                     4),
(1, N'Lists, Tuples & Sets',                        5),
(1, N'Dictionaries & Comprehensions',               6),
(1, N'Functions, Scope & Recursion',                7),
(1, N'File Input/Output',                           8),
(1, N'Error & Exception Handling',                  9),
(1, N'Modules, Packages & Standard Library',        10),
(1, N'Object-Oriented Programming Basics',          11),
(2, N'ER Modeling',                                 1),
(2, N'SQL Querying',                                2),
(2, N'The World of Database Systems & DBMS',        3),
(2, N'The Relational Model & Keys',                 4),
(2, N'Relational Algebra',                          5),
(2, N'Mapping ERD to Relational Schema',            6),
(2, N'Functional Dependencies & Normalization',     7),
(2, N'Joins, Subqueries & Aggregation',             8),
(2, N'Stored Procedures, Functions & Triggers',     9),
(2, N'Transactions & Concurrency (ACID)',           10),
(2, N'Indexes, Views & Query Performance',          11),
(3, N'Python for Data',                             1),
(3, N'NumPy & Numerical Computing',                 2),
(3, N'Data Wrangling with Pandas',                  3),
(3, N'Data Cleaning & Preparation',                 4),
(3, N'Descriptive Statistics & Probability',        5),
(3, N'Data Visualization',                          6),
(3, N'Exploratory Data Analysis',                   7),
(3, N'Introduction to Machine Learning',            8),
(3, N'Regression & Classification',                 9),
(3, N'Model Evaluation & Capstone',                 10),
(4, N'HTML & CSS',                                  1),
(4, N'HTML5 Semantic Structure',                    2),
(4, N'CSS Layout: Flexbox & Grid',                  3),
(4, N'Responsive & Mobile-First Design',            4),
(4, N'JavaScript Fundamentals',                     5),
(4, N'The DOM & Event Handling',                    6),
(4, N'Forms & Validation',                          7),
(4, N'Asynchronous JS & Fetch API',                 8),
(4, N'Version Control with Git',                    9),
(4, N'Capstone: Portfolio Website',                 10),
(5, N'Design Thinking',                             1),
(5, N'Fundamentals of UX',                          2),
(5, N'User Research & Personas',                    3),
(5, N'Information Architecture',                     4),
(5, N'Wireframing & Prototyping',                   5),
(5, N'Interaction Design Patterns',                 6),
(5, N'Visual Design: Color & Typography',           7),
(5, N'Prototyping with Figma',                      8),
(5, N'Usability Testing & Heuristics',              9),
(5, N'Design Handoff & Case Study',                 10),
(6, N'What is Computer Science?',                   1),
(6, N'Number Systems & Data Representation',        2),
(6, N'Boolean Logic & Gates',                       3),
(6, N'Computer Hardware & the CPU',                 4),
(6, N'Operating Systems Basics',                    5),
(6, N'Programming Concepts & Algorithms',           6),
(6, N'Data Structures Overview',                    7),
(6, N'Databases & Information Management',          8),
(6, N'Computer Networks & the Internet',            9),
(6, N'Security, Ethics & Emerging Trends',          10),
(7, N'Logic & Set Theory',                          1),
(7, N'Propositional Logic & Proofs',                2),
(7, N'Predicates & Quantifiers',                    3),
(7, N'Sets, Functions & Sequences',                 4),
(7, N'Algorithms & Complexity',                     5),
(7, N'Number Theory & Cryptography',                6),
(7, N'Mathematical Induction & Recursion',          7),
(7, N'Counting & Combinatorics',                    8),
(7, N'Recurrence Relations',                        9),
(7, N'Relations & Their Properties',                10),
(7, N'Graphs & Trees',                              11),
(8, N'Limits & Derivatives',                        1),
(8, N'Functions & Graphs',                          2),
(8, N'Continuity',                                  3),
(8, N'Differentiation Rules',                       4),
(8, N'Applications of Derivatives',                 5),
(8, N'The Definite Integral',                       6),
(8, N'Techniques of Integration',                   7),
(8, N'Sequences & Series',                          8),
(8, N'Matrices & Linear Algebra',                   9),
(8, N'Vectors & Multivariable Basics',              10),
(9, N'Arrays, Lists & Pointers in C',               1),
(9, N'Algorithm Analysis & Big-O',                  2),
(9, N'Linked Lists',                                3),
(9, N'Stacks & Queues',                             4),
(9, N'Recursion',                                   5),
(9, N'Trees & Binary Search Trees',                 6),
(9, N'Heaps & Priority Queues',                     7),
(9, N'Hash Tables',                                 8),
(9, N'Sorting Algorithms',                          9),
(9, N'Searching Algorithms',                        10),
(9, N'Graphs & Graph Traversal',                    11),
(10, N'Lists, Stacks & Queues in Python',           1),
(10, N'Algorithm Analysis & Big-O',                 2),
(10, N'Recursion & Backtracking',                   3),
(10, N'Linked Lists in Python',                     4),
(10, N'Trees & Binary Search Trees',                5),
(10, N'Heaps & Priority Queues',                    6),
(10, N'Hashing & Dictionaries',                     7),
(10, N'Sorting Algorithms',                         8),
(10, N'Searching Algorithms',                       9),
(10, N'Graph Algorithms',                           10),
(10, N'Dynamic Programming',                        11),
(11, N'CPU & Memory Organization',                  1),
(11, N'Data Representation & Number Systems',       2),
(11, N'Digital Logic & Boolean Algebra',            3),
(11, N'Combinational & Sequential Circuits',        4),
(11, N'The von Neumann Model',                      5),
(11, N'Instruction Sets & Addressing Modes',        6),
(11, N'Assembly Language Programming',              7),
(11, N'Processor Structure & Function',             8),
(11, N'Cache Memory & Hierarchy',                   9),
(11, N'Internal & External Memory',                 10),
(11, N'Parallel Processing & Multicore',            11),
(12, N'Introduction to AI & Data Science',          1),
(12, N'Python for Data Science',                    2),
(12, N'Working with NumPy',                         3),
(12, N'Data Manipulation with Pandas',              4),
(12, N'Relational Databases & SQL Basics',          5),
(12, N'Advanced SQL Queries & Joins',               6),
(12, N'Connecting Python to Databases',             7),
(12, N'Data Cleaning & Transformation',             8),
(12, N'Exploratory Data Analysis & Visualization',  9),
(12, N'Mini Data Science Project',                  10),
(13, N'Introduction to IT Ethics',                  1),
(13, N'Ethical Theories & Frameworks',              2),
(13, N'Privacy & Data Protection',                  3),
(13, N'Intellectual Property & Copyright',          4),
(13, N'Cybersecurity Ethics',                       5),
(13, N'Professional Codes of Conduct',              6),
(13, N'Social Media & Digital Citizenship',         7),
(13, N'AI Ethics & Algorithmic Bias',               8),
(13, N'Cybercrime & Law',                           9),
(13, N'Case Studies in IT Ethics',                  10),
(14, N'Linear Algebra Foundations',                 1),
(14, N'Vectors & Vector Spaces',                    2),
(14, N'Matrices & Linear Transformations',          3),
(14, N'Eigenvalues & Eigenvectors',                 4),
(14, N'Calculus & Derivatives',                     5),
(14, N'Multivariate Calculus & Gradients',          6),
(14, N'Optimization & Gradient Descent',            7),
(14, N'Probability Foundations',                    8),
(14, N'Statistics for Machine Learning',            9),
(14, N'Principal Component Analysis',               10),
(15, N'Descriptive Statistics',                     1),
(15, N'Probability Fundamentals',                   2),
(15, N'Conditional Probability & Bayes'' Theorem',  3),
(15, N'Random Variables',                           4),
(15, N'Discrete Probability Distributions',         5),
(15, N'Continuous Probability Distributions',       6),
(15, N'Sampling & Sampling Distributions',          7),
(15, N'Confidence Intervals',                       8),
(15, N'Hypothesis Testing',                         9),
(15, N'Correlation & Regression',                   10),
(16, N'Introduction to Machine Learning',           1),
(16, N'Exploratory Data Analysis',                  2),
(16, N'Data Preprocessing & Feature Engineering',   3),
(16, N'Supervised Learning: Linear Regression',     4),
(16, N'Supervised Learning: Logistic Regression',   5),
(16, N'K-Nearest Neighbors & Decision Trees',       6),
(16, N'Support Vector Machines',                    7),
(16, N'Unsupervised Learning: K-Means & Clustering',8),
(16, N'Hierarchical Clustering & DBSCAN',           9),
(16, N'Ensemble Learning',                          10),
(16, N'Model Evaluation & Selection',               11),
(17, N'Introduction to Computer Vision',            1),
(17, N'Image Formation & Representation',           2),
(17, N'Geometric Primitives & Transformations',     3),
(17, N'Image Processing & Filtering',               4),
(17, N'Histogram & Color Processing',               5),
(17, N'Feature Detection & Matching',               6),
(17, N'Feature-Based Alignment (RANSAC)',           7),
(17, N'Object Detection (Haar Cascades)',           8),
(17, N'Image Segmentation & Motion',                9),
(17, N'Deep Learning for Computer Vision',          10),
(18, N'Project Scoping & Problem Definition',       1),
(18, N'Data Collection & Sourcing',                 2),
(18, N'Data Preprocessing & EDA',                   3),
(18, N'Model Selection & Baseline',                 4),
(18, N'Model Training & Tuning',                    5),
(18, N'Evaluation & Validation',                    6),
(18, N'Deployment & Presentation',                  7),
(18, N'Final Report & Demo',                        8),
(19, N'Introduction to Software Engineering',       1),
(19, N'Software Development Life Cycle',            2),
(19, N'Agile & Scrum',                              3),
(19, N'Requirements Engineering',                   4),
(19, N'Software Design & Architecture',             5),
(19, N'UML & Modeling',                             6),
(19, N'Implementation & Coding Standards',          7),
(19, N'Software Testing & QA',                      8),
(19, N'Configuration Management & DevOps',          9),
(19, N'Software Maintenance & Project Wrap-up',     10),
(20, N'Introduction to Soft Skills',                1),
(20, N'Effective Communication',                    2),
(20, N'Active Listening',                           3),
(20, N'Presentation Skills',                        4),
(20, N'Teamwork & Collaboration',                   5),
(20, N'Conflict Resolution',                        6),
(20, N'Time Management',                            7),
(20, N'Leadership Basics',                          8),
(20, N'Professional Etiquette',                     9),
(21, N'Introduction to Deep Learning',              1),
(21, N'Neural Network Fundamentals',                2),
(21, N'Forward & Backpropagation',                  3),
(21, N'Activation Functions & Loss',                4),
(21, N'Optimization & Gradient Descent',            5),
(21, N'Regularization & Weight Decay',              6),
(21, N'Convolutional Neural Networks',              7),
(21, N'Recurrent Neural Networks & LSTM',           8),
(21, N'Attention & Transformers',                   9),
(21, N'Generative Models',                          10),
(21, N'Model Deployment & Error Analysis',          11),
(22, N'Introduction to Web Development with Python', 1),
(22, N'HTTP & Web Fundamentals',                    2),
(22, N'Flask Framework Basics',                     3),
(22, N'Routing & Templates (Jinja2)',               4),
(22, N'Forms & User Input',                         5),
(22, N'Working with Databases (SQLAlchemy)',        6),
(22, N'REST APIs with Python',                      7),
(22, N'Authentication & Sessions',                  8),
(22, N'Deployment & Web Servers',                   9),
(22, N'Capstone Web Application',                   10),
(23, N'Internship Orientation',                     1),
(23, N'Workplace Professionalism',                  2),
(23, N'Company Tools & Workflow',                   3),
(23, N'Assigned Project Work',                      4),
(23, N'Mentorship & Feedback',                      5),
(23, N'Weekly Progress Reporting',                  6),
(23, N'Final Internship Report',                    7),
(23, N'Performance Evaluation',                     8),
(24, N'Introduction to NLP',                        1),
(24, N'Text Preprocessing & Normalization',         2),
(24, N'Tokenization & Lemmatization',               3),
(24, N'Part-of-Speech Tagging',                     4),
(24, N'Syntactic Parsing',                          5),
(24, N'TF-IDF & Bag of Words',                      6),
(24, N'Word Embeddings',                            7),
(24, N'Text Classification & Sentiment Analysis',   8),
(24, N'Language Modeling',                          9),
(24, N'Sequence Labeling & Applications',           10),
(25, N'Introduction to Project Management',         1),
(25, N'Project Life Cycle',                         2),
(25, N'Project Initiation & Charter',               3),
(25, N'Scope Management',                           4),
(25, N'Schedule & Time Management',                 5),
(25, N'Cost & Budget Management',                   6),
(25, N'Risk Management',                            7),
(25, N'Quality & Resource Management',              8),
(25, N'Agile Project Management',                   9),
(25, N'Project Closure & Case Study',               10),
(26, N'Introduction to TensorFlow',                 1),
(26, N'Tensors & Operations',                       2),
(26, N'Building Models with Keras',                 3),
(26, N'Training & Evaluation Workflow',             4),
(26, N'Convolutional Networks in TensorFlow',       5),
(26, N'Working with Image Data',                    6),
(26, N'Sequence Models & Text',                     7),
(26, N'Transfer Learning',                          8),
(26, N'Saving, Loading & TensorFlow Serving',       9),
(26, N'Capstone: Deploying an AI Model',            10);
GO

INSERT INTO Materials (ModuleID, Title, MaterialType, ContentURL, OrderIndex)
SELECT  m.ModuleID,
        t.Prefix + N': ' + m.Title,
        t.MType,
        'https://lms.edu/course/' + CAST(m.CourseID AS VARCHAR(10))
            + '/module/' + CAST(m.ModuleID AS VARCHAR(10)) + '/' + t.Slug,
        t.Ord
FROM Modules m
CROSS JOIN (VALUES
    (1, N'Lecture Slides',    'Slide',    'slides'),
    (2, N'Reading Material',  'Document', 'reading'),
    (3, N'Video Lecture',     'Video',    'video'),
    (4, N'Practice Exercises','Document', 'exercises'),
    (5, N'Reference Link',    'Link',     'reference')
) AS t(Ord, Prefix, MType, Slug);
GO

UPDATE Courses SET Status='Published';
GO

EXEC sp_EnrollStudent @StudentID=5,  @CourseID=1;
EXEC sp_EnrollStudent @StudentID=5,  @CourseID=2;
EXEC sp_EnrollStudent @StudentID=6,  @CourseID=1;
EXEC sp_EnrollStudent @StudentID=6,  @CourseID=3;
EXEC sp_EnrollStudent @StudentID=7,  @CourseID=1;
EXEC sp_EnrollStudent @StudentID=7,  @CourseID=2;
EXEC sp_EnrollStudent @StudentID=8,  @CourseID=2;
EXEC sp_EnrollStudent @StudentID=9,  @CourseID=4;
EXEC sp_EnrollStudent @StudentID=10, @CourseID=1;
EXEC sp_EnrollStudent @StudentID=10, @CourseID=5;
EXEC sp_EnrollStudent @StudentID=11, @CourseID=2;
EXEC sp_EnrollStudent @StudentID=12, @CourseID=3;
GO

UPDATE Enrollments SET Status='Completed', ProgressPercent=100, CompletedAt=SYSDATETIME()
WHERE StudentID=5 AND CourseID=1;
UPDATE Enrollments SET Status='Dropped'
WHERE StudentID=9 AND CourseID=4;
GO

INSERT INTO Assignments (CourseID, Title, Description, AType, MaxScore, Deadline, LatePolicy, PenaltyPct) VALUES
(1, N'Python Basics Assignment', N'Write 3 small scripts', 'Assignment', 10, '2026-06-10 23:59', 'AcceptLate', 10),
(1, N'Python Quiz 1',            N'MCQ on syntax',         'Quiz',       10, '2026-06-15 23:59', 'RejectLate', 0),
(2, N'SQL SELECT Exercise',      N'Write 5 queries',       'Assignment', 10, '2026-06-12 23:59', 'Penalty',    20),
(2, N'Database Quiz',            N'MCQ on ER & SQL',       'Quiz',       10, '2026-07-01 23:59', 'AcceptLate', 0);
GO

INSERT INTO Questions (AssignmentID, QuestionText, Points) VALUES
(2, N'Which keyword defines a function in Python?', 1),
(2, N'What is the output of print(2 ** 3)?',        1),
(2, N'Which type is immutable?',                    1);
GO
INSERT INTO QuestionOptions (QuestionID, OptionText, IsCorrect) VALUES
(1, N'func',  0), (1, N'def', 1), (1, N'function', 0), (1, N'lambda', 0);
INSERT INTO QuestionOptions (QuestionID, OptionText, IsCorrect) VALUES
(2, N'6', 0), (2, N'8', 1), (2, N'9', 0), (2, N'23', 0);
INSERT INTO QuestionOptions (QuestionID, OptionText, IsCorrect) VALUES
(3, N'list', 0), (3, N'dict', 0), (3, N'tuple', 1), (3, N'set', 0);
GO

INSERT INTO Questions (AssignmentID, QuestionText, Points) VALUES
(4, N'A primary key must be ...', 1),
(4, N'Which JOIN keeps unmatched left rows?', 1);
GO
INSERT INTO QuestionOptions (QuestionID, OptionText, IsCorrect) VALUES
(4, N'Unique and not null', 1), (4, N'Nullable', 0), (4, N'Always numeric', 0),
(5, N'INNER JOIN', 0), (5, N'LEFT JOIN', 1), (5, N'CROSS JOIN', 0);
GO

DECLARE @sid INT;

EXEC sp_SubmitAssignment @AssignmentID=1, @StudentID=5,  @ContentURL='https://lms.edu/sub/5_1.zip',  @SubmissionID=@sid OUTPUT;
EXEC sp_SubmitAssignment @AssignmentID=1, @StudentID=6,  @ContentURL='https://lms.edu/sub/6_1.zip',  @SubmissionID=@sid OUTPUT;
EXEC sp_SubmitAssignment @AssignmentID=1, @StudentID=7,  @ContentURL='https://lms.edu/sub/7_1.zip',  @SubmissionID=@sid OUTPUT;

EXEC sp_SubmitAssignment @AssignmentID=3, @StudentID=5,  @ContentURL='https://lms.edu/sub/5_3.sql',  @SubmissionID=@sid OUTPUT;
EXEC sp_SubmitAssignment @AssignmentID=3, @StudentID=8,  @ContentURL='https://lms.edu/sub/8_3.sql',  @SubmissionID=@sid OUTPUT;

EXEC sp_SubmitAssignment @AssignmentID=2, @StudentID=5,  @ContentURL=NULL, @SubmissionID=@sid OUTPUT;
GO

DECLARE @subQuiz INT;
EXEC sp_SubmitAssignment @AssignmentID=4, @StudentID=8, @ContentURL=NULL, @SubmissionID=@subQuiz OUTPUT;

INSERT INTO StudentAnswers (SubmissionID, QuestionID, SelectedOptionID)
SELECT @subQuiz, 4, (SELECT OptionID FROM QuestionOptions WHERE QuestionID=4 AND OptionText=N'Unique and not null');
INSERT INTO StudentAnswers (SubmissionID, QuestionID, SelectedOptionID)
SELECT @subQuiz, 5, (SELECT OptionID FROM QuestionOptions WHERE QuestionID=5 AND OptionText=N'LEFT JOIN');

EXEC sp_AutoGradeQuiz @SubmissionID=@subQuiz;
GO

EXEC sp_GradeSubmission @SubmissionID=1, @Score=8.5, @Feedback=N'Good work, minor style issues', @GradedBy=2;
EXEC sp_GradeSubmission @SubmissionID=2, @Score=7.0, @Feedback=N'Needs better comments',          @GradedBy=2;
EXEC sp_GradeSubmission @SubmissionID=3, @Score=9.0, @Feedback=N'Excellent',                      @GradedBy=2;
EXEC sp_GradeSubmission @SubmissionID=4, @Score=6.5, @Feedback=N'Late: penalty applied',          @GradedBy=3;
EXEC sp_GradeSubmission @SubmissionID=5, @Score=8.0, @Feedback=N'Well structured',                @GradedBy=3;
GO

EXEC sp_IssueCertificate @StudentID=8, @CourseID=2;
GO

INSERT INTO ForumThreads (CourseID, CreatedBy, Title) VALUES
(1, 5, N'How to fix IndentationError?'),
(2, 8, N'Difference between WHERE and HAVING?');
GO
INSERT INTO ForumPosts (ThreadID, UserID, Content, ParentPostID) VALUES
(1, 5, N'I keep getting an IndentationError, any tips?', NULL),
(1, 2, N'Make sure you use consistent spaces (4) for each block.', 1),
(1, 6, N'Configuring your editor to show whitespace helps a lot.', 1),
(2, 8, N'When should I use HAVING instead of WHERE?', NULL),
(2, 3, N'Use WHERE before grouping, HAVING to filter aggregates.', 4);
GO

EXEC sp_RecommendCourses @StudentID=5, @TopN=3;
EXEC sp_RecommendCourses @StudentID=7, @TopN=3;
UPDATE TOP (1) Recommendations SET Status='Clicked' WHERE StudentID=5 AND Status='Shown';
UPDATE TOP (1) Recommendations SET Status='Ignored' WHERE StudentID=7 AND Status='Shown';
GO

DECLARE @s1 UNIQUEIDENTIFIER = NEWID(), @s2 UNIQUEIDENTIFIER = NEWID(), @s3 UNIQUEIDENTIFIER = NEWID();
INSERT INTO InteractionLogs (UserID, SessionID, ActionType, EntityType, EntityID, DurationSec, CreatedAt) VALUES
(5,  @s1, 'Login',        NULL,         NULL, NULL, '2026-06-20 08:00'),
(5,  @s1, 'ViewMaterial', 'Material',   1,    120,  '2026-06-20 08:02'),
(5,  @s1, 'ViewMaterial', 'Material',   2,    300,  '2026-06-20 08:05'),
(5,  @s1, 'Submit',       'Assignment', 1,    45,   '2026-06-20 08:20'),
(6,  @s2, 'Login',        NULL,         NULL, NULL, '2026-06-20 09:00'),
(6,  @s2, 'ViewMaterial', 'Material',   1,    90,   '2026-06-20 09:01'),
(8,  @s3, 'Login',        NULL,         NULL, NULL, '2026-06-21 10:00'),
(8,  @s3, 'ViewMaterial', 'Material',   4,    200,  '2026-06-21 10:03'),
(8,  @s3, 'Submit',       'Assignment', 4,    600,  '2026-06-21 10:15');
GO

PRINT 'Sample data inserted successfully.';
GO
