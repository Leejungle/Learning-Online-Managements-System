/* =====================================================================
   LOCAL MASTER SCRIPT (absolute paths) - for THIS machine only.
   How to run in SSMS:
     1) Menu: Query > SQLCMD Mode  (must be ON)
     2) Press F5
   NOTE: paths are hard-coded to this PC. If another teammate runs it,
         they must change the folder below OR just run files 01..07 one
         by one (no SQLCMD mode needed).
   ===================================================================== */
:on error exit
:r "g:\Summer_2026\DBI202\Learning-Online-Managements-System\sql\01_schema.sql"
:r "g:\Summer_2026\DBI202\Learning-Online-Managements-System\sql\02_triggers.sql"
:r "g:\Summer_2026\DBI202\Learning-Online-Managements-System\sql\03_functions_views.sql"
:r "g:\Summer_2026\DBI202\Learning-Online-Managements-System\sql\04_procedures.sql"
:r "g:\Summer_2026\DBI202\Learning-Online-Managements-System\sql\05_sample_data.sql"
:r "g:\Summer_2026\DBI202\Learning-Online-Managements-System\sql\06_reports.sql"
:r "g:\Summer_2026\DBI202\Learning-Online-Managements-System\sql\07_business_rule_tests.sql"
