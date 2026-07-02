# Lab 1 — Study of Data Models

> **Course:** DBI202 — Database Systems
> **Lab:** 1 — Study of Data Models
> **Project:** Online Learning Management System (LMS)
> **Group:** [GROUP NAME]
> **Members:** [FULL NAME — STUDENT ID], [FULL NAME — STUDENT ID], [FULL NAME — STUDENT ID], [FULL NAME — STUDENT ID]
> **Class:** [CLASS CODE]
> **Date:** [SUBMISSION DATE]

---

## 1. Objective

The purpose of this lab is to explore and analyse the major data models used in database
systems, understanding for each model its **storage structure**, **constraints**, **data
manipulation operators**, **advantages**, **limitations**, and **suitable applications**.
Based on this analysis, the group justifies the choice of the **relational model** as the most
appropriate foundation for the group project — an **Online Learning Management System (LMS)**
implemented on Microsoft SQL Server.

---

## 2. Overview of Data Models

A *data model* is a collection of concepts that describe how data is structured, what
constraints hold over the data, and what operations are available to retrieve and manipulate it.
The following sections review the principal models in the order in which they historically
appeared and matured.

### 2.1. Hierarchical Model

| Aspect | Description |
|---|---|
| **Storage structure** | Data is organised as a **tree**: records are linked in parent→child relationships; each child has exactly **one** parent (1:N from parent to children). |
| **Constraints** | A child record cannot exist without its parent; relationships are fixed by the physical tree structure; only 1:N is naturally supported. |
| **Data manipulation** | Navigational access: `GET`, `GET NEXT`, `GET NEXT WITHIN PARENT` (e.g., IBM IMS DL/I). The programmer traverses pointers from the root downward. |
| **Advantages** | Simple, fast for predictable top-down access paths; efficient for naturally hierarchical data. |
| **Limitations** | Cannot represent **many-to-many** relationships directly; rigid structure; data redundancy when the same child belongs to several parents; queries require knowing the physical path. |
| **Suitable applications** | Legacy mainframe systems, file systems, organisation charts, bill-of-materials, XML-like document trees. |

### 2.2. Network Model

| Aspect | Description |
|---|---|
| **Storage structure** | A **graph** of records connected by named *sets* (owner→member links). A member record can belong to **several** owners, so M:N is expressible via linking record types. |
| **Constraints** | Set membership rules (e.g., automatic/manual, mandatory/optional); relationships are still defined by physical pointers (CODASYL/DBTG model). |
| **Data manipulation** | Navigational `FIND`, `FIND NEXT`, `CONNECT`, `DISCONNECT` over set occurrences. |
| **Advantages** | More flexible than hierarchical (handles M:N); efficient navigation along predefined sets. |
| **Limitations** | Very complex to design and maintain; programs are tightly coupled to the physical structure; schema changes are costly. |
| **Suitable applications** | Early enterprise transaction systems (banking, telecom) before the relational model became dominant. |

### 2.3. Relational Model

| Aspect | Description |
|---|---|
| **Storage structure** | Data is stored in **relations (tables)** of rows (tuples) and columns (attributes). Relationships are represented **logically by values** (primary key / foreign key) rather than by physical pointers. |
| **Constraints** | Rich declarative integrity: **domain** (data types, `CHECK`), **entity integrity** (`PRIMARY KEY`, `NOT NULL`), **referential integrity** (`FOREIGN KEY`), **uniqueness** (`UNIQUE`), and **default** values. |
| **Data manipulation** | **SQL** + relational algebra: selection, projection, join, union, intersection, difference, aggregation (`GROUP BY`/`HAVING`), nesting (subqueries), `EXISTS`/`IN`. Set-oriented, declarative. |
| **Advantages** | Strong data integrity; declarative querying; physical/logical independence; mature support for **transactions (ACID)**, views, indexes, stored procedures, functions and triggers; naturally supports M:N through junction tables. |
| **Limitations** | Impedance mismatch with object-oriented code; can be less convenient for highly variable or deeply nested/semi-structured data; horizontal scaling is harder than some NoSQL stores. |
| **Suitable applications** | Business/transactional systems requiring consistency and complex querying: ERP, banking, e-commerce, and **learning management systems**. |

### 2.4. Object-Oriented & Object-Relational Models

| Aspect | Description |
|---|---|
| **Storage structure** | Data stored as **objects** with attributes and methods (OO databases), or relational tables extended with **user-defined types, arrays, and nested structures** (object-relational, e.g., PostgreSQL/Oracle features). |
| **Constraints** | Class/type definitions, inheritance, encapsulation; relational constraints still apply in the object-relational variant. |
| **Data manipulation** | Object query languages (OQL) or SQL extended with type/array operators. |
| **Advantages** | Natural fit for complex objects and OO programming; reduces impedance mismatch. |
| **Limitations** | Less standardised; smaller ecosystem; added complexity over the pure relational model. |
| **Suitable applications** | CAD/CAM, multimedia, GIS, engineering and scientific data with complex structured types. |

### 2.5. Semi-structured Model (XML / JSON)

| Aspect | Description |
|---|---|
| **Storage structure** | **Self-describing**, tree/document structures (XML, JSON) where structure is carried with the data (tags/keys) rather than a fixed schema. |
| **Constraints** | Optional schemas (XML Schema/DTD, JSON Schema); structure can vary from record to record. |
| **Data manipulation** | XPath/XQuery (XML), JSON path expressions; SQL engines also expose JSON functions (e.g., SQL Server `OPENJSON`, `JSON_VALUE`). |
| **Advantages** | Flexible/evolving structure; ideal for document exchange and APIs; no rigid schema required. |
| **Limitations** | Weaker global integrity enforcement; querying/joining across documents is less efficient; validation is optional and easy to omit. |
| **Suitable applications** | Web APIs, configuration files, data interchange, content/document storage. |

### 2.6. NoSQL Models

NoSQL is a family of non-relational stores optimised for scale, availability, and flexible schemas.

| Sub-type | Storage structure | Manipulation | Advantages | Limitations | Applications |
|---|---|---|---|---|---|
| **Key–Value** | Hash map of key→opaque value (Redis, DynamoDB) | `GET`/`PUT`/`DELETE` by key | Extremely fast, simple, horizontally scalable | No rich queries/joins; value opaque | Caching, sessions, counters |
| **Document** | Collections of JSON/BSON documents (MongoDB) | Query by fields, document APIs | Flexible schema, nested data | Weaker cross-document integrity, eventual consistency | Catalogs, content, profiles |
| **Column-family** | Sparse wide rows grouped by column families (Cassandra, HBase) | CQL / column-range scans | Massive write throughput, scale | Limited ad-hoc joins; denormalised | Time-series, IoT, big data |
| **Graph** | Nodes + edges with properties (Neo4j) | Traversal languages (Cypher) | Excellent for relationship traversal | Not ideal for tabular aggregation; smaller ecosystem | Social networks, recommendations, fraud |

**Common constraints/trade-off:** most NoSQL systems favour availability and partition tolerance
(BASE / eventual consistency) over the strict ACID guarantees of relational databases, and they
typically push integrity rules into the **application layer** rather than the database engine.

---

## 3. Comparative Summary

| Criterion | Hierarchical | Network | **Relational** | Object/OR | Semi-structured | NoSQL |
|---|---|---|---|---|---|---|
| M:N relationships | No (direct) | Yes (complex) | **Yes (junction table)** | Yes | Limited | Varies |
| Declarative query language | No | No | **Yes (SQL)** | Partial | Partial | Varies |
| Strong integrity constraints | Weak | Medium | **Strong (PK/FK/UNIQUE/CHECK)** | Strong | Weak | App-level |
| ACID transactions | Limited | Limited | **Yes** | Yes | Limited | Often relaxed |
| Schema rigidity | Rigid | Rigid | Structured (flexible enough) | Structured | Flexible | Flexible |
| Best for | Tree data | Legacy OLTP | **Consistent transactional apps** | Complex objects | Documents/APIs | Scale/variety |

---

## 4. Justification: Why the Relational Model Fits the LMS Project

The LMS domain manages users, courses, modules, learning materials, enrolments, assessments,
submissions, grades, discussions, recommendations, interaction logs, and completion certificates.
The relational model is the best fit for the following project-specific reasons. *(All artefacts
referenced below exist in the repository under `sql/` and `docs/`.)*

1. **Many-to-many relationships are first-class.**
   A student may enrol in many courses, and a course has many students. In the relational model
   this M:N relationship is resolved cleanly with a **junction table** `Enrollments`, with a
   composite uniqueness rule `CONSTRAINT UQ_Enroll UNIQUE (StudentID, CourseID)` preventing
   duplicate enrolment (`sql/01_schema.sql`). Hierarchical/document models cannot express this as
   naturally.

2. **Strong, declarative data integrity.**
   The project relies on the engine — not application code — to guarantee correctness:
   - Entity integrity: surrogate `PRIMARY KEY`s on every table.
   - Referential integrity: foreign keys such as `FK_Courses_Instructor`, `FK_Enroll_Course`,
     `FK_Sub_Assignment`, `FK_Grade_Submission`.
   - Domain/value rules: `CHECK` constraints such as `CK_Users_Role`, `CK_Enroll_Progress`
     (0–100), `CK_Cert_Pass` (final score ≥ 80), and `CK_Users_Username_Length`.
   - Natural uniqueness: `UNIQUE(Username)`, `UNIQUE(Email)`, `UNIQUE(CourseCode)`.
   These declarative guarantees are a core strength of the relational model and are central to the
   project's correctness.

3. **Complex querying, analytics and reporting.**
   The course requires six analytical reports (`sql/06_reports.sql`) that depend on multi-table
   **joins**, **`GROUP BY`/`HAVING`** aggregation, and computed rates (enrolment/completion,
   on-time vs late submission, system usage). SQL expresses these declaratively and efficiently —
   a capability the navigational and key–value models lack.

4. **Normalization to remove redundancy.**
   The schema is normalised to **3NF** (documented in `docs/Normalization_and_DataDictionary.md`):
   for example, category names are factored into `Categories` rather than repeated in `Courses`,
   and instructor details live in `Users` (referenced by `Courses.InstructorID`). The relational
   model is precisely the model for which normalization theory was developed.

5. **Transactions for reliable multi-step operations.**
   Operations such as enrolment, submission, grading and certificate issuance must be atomic.
   Stored procedures (`sql/04_procedures.sql`) wrap these in `BEGIN TRANSACTION … COMMIT/ROLLBACK`
   with `TRY/CATCH` (e.g., `sp_IssueCertificate` both inserts the certificate and marks the
   enrolment completed atomically). ACID transactions are a relational strength.

6. **Server-side business-rule enforcement.**
   Rules that go beyond simple constraints are enforced by **triggers** (`sql/02_triggers.sql`),
   e.g., `trg_Enroll_Validate` (only `Student` role may enrol; only `Published` courses),
   `trg_Grades_MarkGraded` (grade ≤ MaxScore; grader must be Instructor/Admin). Centralising rules
   in the database guarantees they hold regardless of which client connects.

7. **Reliable rules for grades and certificates.**
   A certificate may be issued only when the computed final grade ≥ 80%. This rule is enforced at
   two layers — the function `fn_CourseFinalGrade` + procedure `sp_IssueCertificate`, and the
   table-level `CHECK CK_Cert_Pass` — so even a direct `INSERT` cannot create an invalid
   certificate. Such guaranteed, value-based rules are natural in the relational model.

8. **Views, indexes, functions, procedures, triggers — a complete programmable layer.**
   The project uses 2 views, 6 indexes, 5 functions, 6 stored procedures and 7 triggers, all
   standard relational features supported by SQL Server. This breadth is exactly what DBI202 aims
   to teach and demonstrate.

> **Note on the recommendation feature.** The project includes a course recommender
> (`sp_RecommendCourses`). It is a **lightweight, SQL-based content-based** procedure (it ranks
> not-yet-enrolled published courses in the categories a student already studies). It is **not** a
> trained machine-learning model; it is implemented entirely in T-SQL and is included purely as a
> database demonstration.

---

## 5. Conclusion and Reflection

After comparing the hierarchical, network, relational, object/object-relational, semi-structured
and NoSQL models, the group concludes that the **relational model** is the most appropriate
foundation for the LMS project. The LMS is a **consistency-critical, transactional** application
with many **many-to-many** relationships, strong **integrity** requirements, and a need for
**complex analytical queries** — all of which the relational model, via SQL Server, supports
natively through primary/foreign keys, `CHECK`/`UNIQUE`/`DEFAULT` constraints, normalization,
ACID transactions, views, indexes, functions, stored procedures and triggers.

Models such as NoSQL document or key–value stores would offer easier horizontal scaling and
schema flexibility, but at the cost of the declarative integrity and rich querying the LMS
depends on. Therefore the relational model is the correct engineering choice for this project,
and the remaining labs build directly on it: entity & functional-dependency analysis (Lab 2),
normalization (Lab 3), the full design process (Lab 4), and SQL programming (Lab 5).

---

## Appendix — Repository Evidence Referenced

| Claim in this report | Evidence file |
|---|---|
| Tables, keys, constraints (`UQ_Enroll`, `CK_Cert_Pass`, `CK_Users_Role`, …) | `sql/01_schema.sql` |
| Trigger-based business rules | `sql/02_triggers.sql` |
| Functions & views (`fn_CourseFinalGrade`, `vw_Gradebook`) | `sql/03_functions_views.sql` |
| Transaction-managed procedures (`sp_IssueCertificate`, …) | `sql/04_procedures.sql` |
| Six analytical reports (joins, GROUP BY/HAVING) | `sql/06_reports.sql` |
| 3NF normalization & data dictionary | `docs/Normalization_and_DataDictionary.md` |
