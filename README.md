# Digital Library and Resource Circulation Management System
DBMS Capstone Project (Project #7) | MySQL 8.0

## Project Summary
The Digital Library and Resource Circulation Management System is a comprehensive relational database system designed in MySQL 8.0 to manage catalog inventory, memberships, borrowing transactions, and financial penalties. Built on a fully normalized 3NF schema comprising 9 tables, the system enforces automated stock updates, borrowing limits, reservation workflows, and overdue fine calculations through database triggers, stored procedures, and functions. It includes 4 analytical views, 25 production queries, and full transaction rollback support to guarantee complete data integrity and institutional circulation reporting.

## Folder contents
| File / Folder | What it is |
|---|---|
| `DBMS_Capstone_Report_Digital_Library_FINAL.docx` | Final comprehensive project report (English) with student title page details and all 16 execution output screenshots |
| `DBMS_Capstone_Report_Digital_Library_FINAL.pdf` | Submission-ready PDF export of the final project report (20 pages, fully formatted) |
| `DBMS_Capstone_Report_Digital_Library.docx` | Base project report template: abstract, ER diagram, schema, normalization, code, outputs, testing, conclusion |
| `ER_Diagram.png` | Complete Entity-Relationship (ER) diagram image (Crow's Foot notation) |
| `library_db_full.sql` | ALL SQL in one file. Run this single script to build schema, triggers, sample data, views, queries, and demos |
| `screenshots/` | Folder containing 16 clean, terminal-rendered PNG screenshots of actual MySQL 8.0 query outputs |
| `sql/01_schema.sql` | Database creation, 9 normalized tables, integrity constraints, and foreign key indexes |
| `sql/02_function_triggers_procedures.sql` | Fine calculation function, 4 automated circulation triggers, and 3 stored procedures |
| `sql/03_sample_data.sql` | Realistic sample dataset (13 books, 16 authors, 10 members, 17 circulation issues, fines, reservations) |
| `sql/04_views.sql` | 4 reporting views: available books, overdue books, member history, and library utilization |
| `sql/05_queries.sql` | 25 practical administrative and analytical queries covering joins, aggregations, subqueries, and updates |
| `sql/06_procedure_and_transaction_demo.sql` | Step-by-step verification demo for stored procedures, functions, triggers, and ACID transactions (ROLLBACK & COMMIT) |
| `outputs/` | Verified text outputs from the real MySQL execution of all 25 queries and the transaction demo |

## How to run
1. Open MySQL Workbench (or MySQL Command Line Client) and connect to your local MySQL 8.0 server.
2. File > Open SQL Script > `library_db_full.sql`, then click the Execute (lightning bolt) button.
3. Run `USE digital_library;` and then any query, e.g. `SELECT * FROM overdue_books_view;`

Running file 01 or `library_db_full.sql` drops and recreates the database, resetting all data to a clean baseline state.
Sample dates are relative to today (`CURDATE()`), so day counts dynamically reflect the current calendar day.
