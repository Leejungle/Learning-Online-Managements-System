/* =====================================================================
   MASTER SCRIPT - run everything in order.
   Requires SQLCMD mode (in SSMS: Query > SQLCMD Mode), or run with:
       sqlcmd -S localhost -E -C -i run_all.sql
   ===================================================================== */
:on error exit
:r 01_schema.sql
:r 02_triggers.sql
:r 03_functions_views.sql
:r 04_procedures.sql
:r 05_sample_data.sql
:r 06_reports.sql
:r 07_business_rule_tests.sql
