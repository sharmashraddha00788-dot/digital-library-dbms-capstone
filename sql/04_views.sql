-- =====================================================================
-- File 04: Views (saved queries that behave like virtual tables)
-- =====================================================================
USE digital_library;

-- View 1 : all books that are currently overdue (not returned, past due date)
CREATE OR REPLACE VIEW overdue_books_view AS
SELECT  i.issue_id,
        m.member_id,
        m.full_name        AS member_name,
        b.title            AS book_title,
        i.issue_date,
        i.due_date,
        DATEDIFF(CURDATE(), i.due_date)        AS days_overdue,
        DATEDIFF(CURDATE(), i.due_date) * 5    AS fine_so_far
FROM issue_records i
JOIN members m ON i.member_id = m.member_id
JOIN books   b ON i.book_id   = b.book_id
WHERE i.return_date IS NULL
  AND i.due_date < CURDATE();

-- View 2 : complete borrowing history of every member
CREATE OR REPLACE VIEW member_history_view AS
SELECT  m.member_id,
        m.full_name        AS member_name,
        b.title            AS book_title,
        i.issue_date,
        i.due_date,
        i.return_date,
        i.status
FROM members m
JOIN issue_records i ON m.member_id = i.member_id
JOIN books b         ON i.book_id   = b.book_id;

-- View 3 : library utilization summary, category by category
CREATE OR REPLACE VIEW library_utilization_view AS
SELECT  c.category_name,
        COUNT(DISTINCT b.book_id)               AS titles,
        SUM(b.total_copies)                     AS total_copies,
        SUM(b.available_copies)                 AS available_copies,
        SUM(b.total_copies - b.available_copies) AS copies_on_loan,
        ROUND(SUM(b.total_copies - b.available_copies) * 100 / SUM(b.total_copies), 1)
                                                AS utilization_percent
FROM categories c
JOIN books b ON c.category_id = b.category_id
GROUP BY c.category_name;

-- View 4 : books that can be issued right now
CREATE OR REPLACE VIEW available_books_view AS
SELECT  b.book_id, b.title, c.category_name, b.available_copies, b.shelf_location
FROM books b
JOIN categories c ON b.category_id = c.category_id
WHERE b.available_copies > 0;
