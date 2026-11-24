-- ====== DIGITAL LIBRARY MANAGEMENT SYSTEM : FULL SCRIPT (run this one file to build everything) ======

-- >>>>>>>>>> 01_schema.sql <<<<<<<<<<
-- =====================================================================
-- DIGITAL LIBRARY AND RESOURCE CIRCULATION MANAGEMENT SYSTEM
-- DBMS Capstone Project | MySQL 8
-- File 01: Database and Tables (with constraints and indexes)
-- =====================================================================

DROP DATABASE IF EXISTS digital_library;
CREATE DATABASE digital_library;
USE digital_library;

-- ---------------------------------------------------------------------
-- 1. CATEGORIES : subjects/genres of books
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    category_id    INT AUTO_INCREMENT PRIMARY KEY,
    category_name  VARCHAR(50) NOT NULL UNIQUE,
    description    VARCHAR(150)
);

-- ---------------------------------------------------------------------
-- 2. PUBLISHERS : companies that publish the books
-- ---------------------------------------------------------------------
CREATE TABLE publishers (
    publisher_id    INT AUTO_INCREMENT PRIMARY KEY,
    publisher_name  VARCHAR(80) NOT NULL UNIQUE,
    city            VARCHAR(50),
    phone           VARCHAR(15)
);

-- ---------------------------------------------------------------------
-- 3. AUTHORS : people who write the books
-- ---------------------------------------------------------------------
CREATE TABLE authors (
    author_id    INT AUTO_INCREMENT PRIMARY KEY,
    author_name  VARCHAR(80) NOT NULL,
    country      VARCHAR(50)
);

-- ---------------------------------------------------------------------
-- 4. BOOKS : every title available in the library
-- ---------------------------------------------------------------------
CREATE TABLE books (
    book_id           INT AUTO_INCREMENT PRIMARY KEY,
    isbn              VARCHAR(17) NOT NULL UNIQUE,
    title             VARCHAR(120) NOT NULL,
    publisher_id      INT NOT NULL,
    category_id       INT NOT NULL,
    publication_year  INT,
    price             DECIMAL(8,2) DEFAULT 0.00,
    total_copies      INT NOT NULL DEFAULT 1,
    available_copies  INT NOT NULL DEFAULT 1,
    shelf_location    VARCHAR(20),
    CONSTRAINT chk_total_copies  CHECK (total_copies >= 0),
    CONSTRAINT chk_avail_copies  CHECK (available_copies >= 0 AND available_copies <= total_copies),
    CONSTRAINT fk_books_publisher FOREIGN KEY (publisher_id) REFERENCES publishers(publisher_id),
    CONSTRAINT fk_books_category  FOREIGN KEY (category_id)  REFERENCES categories(category_id)
);

-- ---------------------------------------------------------------------
-- 5. BOOK_AUTHORS : links books and authors (many-to-many)
-- ---------------------------------------------------------------------
CREATE TABLE book_authors (
    book_id    INT NOT NULL,
    author_id  INT NOT NULL,
    PRIMARY KEY (book_id, author_id),
    CONSTRAINT fk_ba_book   FOREIGN KEY (book_id)   REFERENCES books(book_id)     ON DELETE CASCADE,
    CONSTRAINT fk_ba_author FOREIGN KEY (author_id) REFERENCES authors(author_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- 6. MEMBERS : students, faculty and staff who borrow books
-- ---------------------------------------------------------------------
CREATE TABLE members (
    member_id    INT AUTO_INCREMENT PRIMARY KEY,
    full_name    VARCHAR(80) NOT NULL,
    email        VARCHAR(100) NOT NULL UNIQUE,
    phone        VARCHAR(15),
    member_type  ENUM('Student','Faculty','Staff') NOT NULL DEFAULT 'Student',
    join_date    DATE NOT NULL,
    status       ENUM('Active','Suspended') NOT NULL DEFAULT 'Active',
    max_books    INT NOT NULL DEFAULT 3,
    CONSTRAINT chk_max_books CHECK (max_books BETWEEN 1 AND 10)
);

-- ---------------------------------------------------------------------
-- 7. ISSUE_RECORDS : one row every time a book is issued
--    return_date stays NULL until the book is returned
-- ---------------------------------------------------------------------
CREATE TABLE issue_records (
    issue_id     INT AUTO_INCREMENT PRIMARY KEY,
    book_id      INT NOT NULL,
    member_id    INT NOT NULL,
    issue_date   DATE NOT NULL,
    due_date     DATE NOT NULL,
    return_date  DATE NULL,
    status       ENUM('Issued','Returned') NOT NULL DEFAULT 'Issued',
    CONSTRAINT chk_due_date CHECK (due_date >= issue_date),
    CONSTRAINT fk_issue_book   FOREIGN KEY (book_id)   REFERENCES books(book_id),
    CONSTRAINT fk_issue_member FOREIGN KEY (member_id) REFERENCES members(member_id)
);

-- ---------------------------------------------------------------------
-- 8. RESERVATIONS : a member reserves a book that is not available
-- ---------------------------------------------------------------------
CREATE TABLE reservations (
    reservation_id    INT AUTO_INCREMENT PRIMARY KEY,
    book_id           INT NOT NULL,
    member_id         INT NOT NULL,
    reservation_date  DATE NOT NULL,
    status            ENUM('Pending','Fulfilled','Cancelled') NOT NULL DEFAULT 'Pending',
    CONSTRAINT fk_res_book   FOREIGN KEY (book_id)   REFERENCES books(book_id),
    CONSTRAINT fk_res_member FOREIGN KEY (member_id) REFERENCES members(member_id)
);

-- ---------------------------------------------------------------------
-- 9. FINES : created automatically when a book is returned late
-- ---------------------------------------------------------------------
CREATE TABLE fines (
    fine_id      INT AUTO_INCREMENT PRIMARY KEY,
    issue_id     INT NOT NULL UNIQUE,
    fine_amount  DECIMAL(8,2) NOT NULL,
    fine_date    DATE NOT NULL,
    paid_status  ENUM('Paid','Unpaid') NOT NULL DEFAULT 'Unpaid',
    paid_date    DATE NULL,
    CONSTRAINT chk_fine_amount CHECK (fine_amount > 0),
    CONSTRAINT fk_fine_issue FOREIGN KEY (issue_id) REFERENCES issue_records(issue_id)
);

-- ---------------------------------------------------------------------
-- INDEXES : make frequently used searches faster
-- (primary keys and foreign keys already get indexes automatically)
-- ---------------------------------------------------------------------
CREATE INDEX idx_books_title      ON books(title);
CREATE INDEX idx_members_name     ON members(full_name);
CREATE INDEX idx_issue_status_due ON issue_records(status, due_date);
CREATE INDEX idx_res_status       ON reservations(status);
CREATE INDEX idx_fines_paid       ON fines(paid_status);

-- >>>>>>>>>> 02_function_triggers_procedures.sql <<<<<<<<<<
-- =====================================================================
-- File 02: Function, Triggers and Stored Procedures
-- NOTE: Run this file as a whole. DELIMITER lets MySQL read multi-line
--       code blocks that contain semicolons.
-- =====================================================================
USE digital_library;

DELIMITER $$

-- ---------------------------------------------------------------------
-- FUNCTION : fn_calculate_fine
-- Rule: Rs 5 for every day after the due date. No fine if returned on time.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_calculate_fine(p_due_date DATE, p_return_date DATE)
RETURNS DECIMAL(8,2)
DETERMINISTIC
BEGIN
    DECLARE late_days INT;
    SET late_days = DATEDIFF(p_return_date, p_due_date);
    IF late_days > 0 THEN
        RETURN late_days * 5.00;
    END IF;
    RETURN 0.00;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 1 : block issuing when no copy is available
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_before_issue
BEFORE INSERT ON issue_records
FOR EACH ROW
BEGIN
    DECLARE copies INT;
    IF NEW.return_date IS NULL THEN
        SELECT available_copies INTO copies FROM books WHERE book_id = NEW.book_id;
        IF copies <= 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Book cannot be issued: no copies are available.';
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 2 : reduce available copies after a book is issued
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_after_issue
AFTER INSERT ON issue_records
FOR EACH ROW
BEGIN
    IF NEW.return_date IS NULL THEN
        UPDATE books
        SET available_copies = available_copies - 1
        WHERE book_id = NEW.book_id;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 3 : mark the record as 'Returned' once a return date is set
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_before_return
BEFORE UPDATE ON issue_records
FOR EACH ROW
BEGIN
    IF OLD.return_date IS NULL AND NEW.return_date IS NOT NULL THEN
        SET NEW.status = 'Returned';
    END IF;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER 4 : increase available copies and create a fine if late
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_after_return
AFTER UPDATE ON issue_records
FOR EACH ROW
BEGIN
    DECLARE fine_value DECIMAL(8,2);
    IF OLD.return_date IS NULL AND NEW.return_date IS NOT NULL THEN
        UPDATE books
        SET available_copies = available_copies + 1
        WHERE book_id = NEW.book_id;

        SET fine_value = fn_calculate_fine(NEW.due_date, NEW.return_date);
        IF fine_value > 0 THEN
            INSERT INTO fines (issue_id, fine_amount, fine_date, paid_status)
            VALUES (NEW.issue_id, fine_value, NEW.return_date, 'Unpaid');
        END IF;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- PROCEDURE 1 : sp_issue_book(member, book, number of days)
-- Checks: member active, book copies available, borrowing limit,
--         and no unpaid fines. Then issues the book.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_issue_book(IN p_member_id INT, IN p_book_id INT, IN p_days INT)
BEGIN
    DECLARE v_status VARCHAR(10);
    DECLARE v_max INT;
    DECLARE v_current INT;
    DECLARE v_copies INT;
    DECLARE v_unpaid INT;

    SELECT status, max_books INTO v_status, v_max
    FROM members WHERE member_id = p_member_id;

    SELECT available_copies INTO v_copies
    FROM books WHERE book_id = p_book_id;

    SELECT COUNT(*) INTO v_current
    FROM issue_records
    WHERE member_id = p_member_id AND status = 'Issued';

    SELECT COUNT(*) INTO v_unpaid
    FROM fines f
    JOIN issue_records i ON f.issue_id = i.issue_id
    WHERE i.member_id = p_member_id AND f.paid_status = 'Unpaid';

    IF v_status IS NULL THEN
        SELECT 'FAILED: Member not found.' AS message;
    ELSEIF v_copies IS NULL THEN
        SELECT 'FAILED: Book not found.' AS message;
    ELSEIF v_status <> 'Active' THEN
        SELECT 'FAILED: Member account is suspended.' AS message;
    ELSEIF v_unpaid > 0 THEN
        SELECT 'FAILED: Member has unpaid fines.' AS message;
    ELSEIF v_current >= v_max THEN
        SELECT 'FAILED: Borrowing limit reached.' AS message;
    ELSEIF v_copies <= 0 THEN
        SELECT 'FAILED: No copies available. Please reserve the book.' AS message;
    ELSE
        INSERT INTO issue_records (book_id, member_id, issue_date, due_date)
        VALUES (p_book_id, p_member_id, CURDATE(), DATE_ADD(CURDATE(), INTERVAL p_days DAY));
        SELECT CONCAT('SUCCESS: Book issued. Due date is ',
                      DATE_ADD(CURDATE(), INTERVAL p_days DAY)) AS message;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- PROCEDURE 2 : sp_return_book(issue id, return date)
-- The triggers update the stock and create the fine automatically.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_return_book(IN p_issue_id INT, IN p_return_date DATE)
BEGIN
    DECLARE v_return_date DATE;
    DECLARE v_due DATE;
    DECLARE v_found INT;

    SELECT COUNT(*), MAX(return_date), MAX(due_date)
    INTO v_found, v_return_date, v_due
    FROM issue_records WHERE issue_id = p_issue_id;

    IF v_found = 0 THEN
        SELECT 'FAILED: Issue record not found.' AS message;
    ELSEIF v_return_date IS NOT NULL THEN
        SELECT 'FAILED: This book is already returned.' AS message;
    ELSE
        UPDATE issue_records
        SET return_date = p_return_date
        WHERE issue_id = p_issue_id;
        SELECT CONCAT('SUCCESS: Book returned. Fine = Rs ',
                      fn_calculate_fine(v_due, p_return_date)) AS message;
    END IF;
END$$

-- ---------------------------------------------------------------------
-- PROCEDURE 3 : sp_reserve_book(member, book)
-- A book can be reserved only when no copy is available.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_reserve_book(IN p_member_id INT, IN p_book_id INT)
BEGIN
    DECLARE v_copies INT;
    DECLARE v_member INT;
    DECLARE v_existing INT;

    SELECT available_copies INTO v_copies FROM books WHERE book_id = p_book_id;
    SELECT COUNT(*) INTO v_member FROM members WHERE member_id = p_member_id;
    SELECT COUNT(*) INTO v_existing
    FROM reservations
    WHERE member_id = p_member_id AND book_id = p_book_id AND status = 'Pending';

    IF v_copies IS NULL OR v_member = 0 THEN
        SELECT 'FAILED: Member or book not found.' AS message;
    ELSEIF v_copies > 0 THEN
        SELECT 'FAILED: Copies are available, you can issue the book directly.' AS message;
    ELSEIF v_existing > 0 THEN
        SELECT 'FAILED: You already have a pending reservation for this book.' AS message;
    ELSE
        INSERT INTO reservations (book_id, member_id, reservation_date)
        VALUES (p_book_id, p_member_id, CURDATE());
        SELECT 'SUCCESS: Book reserved.' AS message;
    END IF;
END$$

DELIMITER ;

-- >>>>>>>>>> 03_sample_data.sql <<<<<<<<<<
-- =====================================================================
-- File 03: Sample Data
-- Dates are written relative to today (CURDATE()), so the demo always
-- shows a mix of returned, currently issued and overdue books.
-- The triggers from File 02 adjust available_copies and create fines
-- automatically, so we never type those values by hand.
-- =====================================================================
USE digital_library;

-- 6 categories
INSERT INTO categories (category_name, description) VALUES
('Computer Science', 'Programming, databases, algorithms and computer systems'),
('Mathematics',      'Engineering and discrete mathematics'),
('Fiction',          'Novels, poetry and short stories'),
('History',          'Indian and world history'),
('Science',          'General and popular science'),
('Biography',        'Life stories of famous people');

-- 4 publishers
INSERT INTO publishers (publisher_name, city, phone) VALUES
('McGraw Hill Education',    'New Delhi', '011-23456789'),
('Pearson India',            'Noida',     '0120-4567890'),
('Oxford University Press', 'New Delhi', '011-26789012'),
('Penguin Random House',     'Gurugram',  '0124-3456789');

-- 16 authors
INSERT INTO authors (author_name, country) VALUES
('Abraham Silberschatz', 'USA'),       -- 1
('Henry F. Korth',       'USA'),       -- 2
('S. Sudarshan',         'India'),     -- 3
('Ramez Elmasri',        'USA'),       -- 4
('Shamkant Navathe',     'USA'),       -- 5
('Thomas H. Cormen',     'USA'),       -- 6
('B. S. Grewal',         'India'),     -- 7
('A. P. J. Abdul Kalam', 'India'),     -- 8
('Jawaharlal Nehru',     'India'),     -- 9
('Stephen Hawking',      'UK'),        -- 10
('R. K. Narayan',        'India'),     -- 11
('Peter B. Galvin',      'USA'),       -- 12
('Yashavant Kanetkar',   'India'),     -- 13
('Kenneth H. Rosen',     'USA'),       -- 14
('Rabindranath Tagore',  'India'),     -- 15
('William Stallings',    'USA');       -- 16

-- 13 books (available_copies starts equal to total_copies)
INSERT INTO books (isbn, title, publisher_id, category_id, publication_year, price, total_copies, available_copies, shelf_location) VALUES
('978-0-07-802215-9', 'Database System Concepts',                 1, 1, 2019, 850.00, 3, 3, 'CS-A1'),
('978-0-13-397077-7', 'Fundamentals of Database Systems',         2, 1, 2016, 790.00, 2, 2, 'CS-A2'),
('978-0-26-204630-5', 'Introduction to Algorithms',               1, 1, 2022, 920.00, 2, 2, 'CS-A3'),
('978-81-7409-123-4', 'Higher Engineering Mathematics',           3, 2, 2020, 650.00, 3, 3, 'MA-B1'),
('978-81-7371-146-9', 'Wings of Fire',                            4, 6, 1999, 299.00, 2, 2, 'BI-C1'),
('978-0-19-562-1',    'The Discovery of India',                   3, 4, 2004, 450.00, 2, 2, 'HI-D1'),
('978-0-55-338016-3', 'A Brief History of Time',                  4, 5, 1988, 399.00, 2, 2, 'SC-E1'),
('978-0-14-303-9',    'The Guide',                                4, 3, 2006, 275.00, 2, 2, 'FI-F1'),
('978-1-11-980-3',    'Operating System Concepts',                1, 1, 2018, 880.00, 2, 2, 'CS-A4'),
('978-81-8333-123-0', 'Let Us C',                                 2, 1, 2020, 420.00, 4, 4, 'CS-A5'),
('978-1-26-007-5',    'Discrete Mathematics and Its Applications',1, 2, 2019, 780.00, 2, 2, 'MA-B2'),
('978-0-14-118-0',    'Gitanjali',                                4, 3, 2011, 199.00, 1, 1, 'FI-F2'),
('978-0-13-496-1',    'Computer Organization and Architecture',   2, 1, 2021, 720.00, 2, 2, 'CS-A6');

-- Book <-> Author links (many-to-many)
INSERT INTO book_authors (book_id, author_id) VALUES
(1,1),(1,2),(1,3),
(2,4),(2,5),
(3,6),
(4,7),
(5,8),
(6,9),
(7,10),
(8,11),
(9,1),(9,12),
(10,13),
(11,14),
(12,15),
(13,16);

-- 10 members (the last one is suspended)
INSERT INTO members (full_name, email, phone, member_type, join_date, status, max_books) VALUES
('Aarav Sharma',        'aarav.sharma@college.edu',  '9810000001', 'Student', '2025-07-15', 'Active',    3),
('Priya Verma',         'priya.verma@college.edu',   '9810000002', 'Student', '2025-07-15', 'Active',    3),
('Rohan Gupta',         'rohan.gupta@college.edu',   '9810000003', 'Student', '2025-07-16', 'Active',    3),
('Neha Singh',          'neha.singh@college.edu',    '9810000004', 'Student', '2025-07-16', 'Active',    3),
('Kabir Mehta',         'kabir.mehta@college.edu',   '9810000005', 'Student', '2025-07-18', 'Active',    3),
('Ananya Joshi',        'ananya.joshi@college.edu',  '9810000006', 'Student', '2025-07-18', 'Active',    3),
('Vikram Rao',          'vikram.rao@college.edu',    '9810000007', 'Student', '2025-07-20', 'Active',    3),
('Sneha Patel',         'sneha.patel@college.edu',   '9810000008', 'Student', '2025-07-21', 'Active',    3),
('Dr. Rakesh Malhotra', 'rakesh.malhotra@college.edu','9810000009','Faculty', '2024-01-10', 'Active',    5),
('Arjun Yadav',         'arjun.yadav@college.edu',   '9810000010', 'Student', '2025-07-22', 'Suspended', 3);

-- 17 issue records. First every book is issued (return_date = NULL),
-- then returned books are updated. This lets the triggers do their job.
INSERT INTO issue_records (book_id, member_id, issue_date, due_date) VALUES
(1 , 1 , CURDATE() - INTERVAL 40 DAY, CURDATE() - INTERVAL 26 DAY),  -- 1
(2 , 2 , CURDATE() - INTERVAL 35 DAY, CURDATE() - INTERVAL 21 DAY),  -- 2
(10, 3 , CURDATE() - INTERVAL 30 DAY, CURDATE() - INTERVAL 16 DAY),  -- 3
(4 , 4 , CURDATE() - INTERVAL 28 DAY, CURDATE() - INTERVAL 14 DAY),  -- 4
(7 , 5 , CURDATE() - INTERVAL 45 DAY, CURDATE() - INTERVAL 31 DAY),  -- 5
(3 , 6 , CURDATE() - INTERVAL 50 DAY, CURDATE() - INTERVAL 36 DAY),  -- 6
(9 , 7 , CURDATE() - INTERVAL 33 DAY, CURDATE() - INTERVAL 19 DAY),  -- 7
(1 , 3 , CURDATE() - INTERVAL 22 DAY, CURDATE() - INTERVAL 8  DAY),  -- 8
(8 , 1 , CURDATE() - INTERVAL 60 DAY, CURDATE() - INTERVAL 46 DAY),  -- 9
(1 , 1 , CURDATE() - INTERVAL 5  DAY, CURDATE() + INTERVAL 9  DAY),  -- 10 (current)
(5 , 2 , CURDATE() - INTERVAL 20 DAY, CURDATE() - INTERVAL 6  DAY),  -- 11 (overdue)
(8 , 8 , CURDATE() - INTERVAL 25 DAY, CURDATE() - INTERVAL 11 DAY),  -- 12 (overdue)
(3 , 4 , CURDATE() - INTERVAL 18 DAY, CURDATE() - INTERVAL 4  DAY),  -- 13 (overdue)
(6 , 9 , CURDATE() - INTERVAL 10 DAY, CURDATE() + INTERVAL 4  DAY),  -- 14 (current)
(10, 10, CURDATE() - INTERVAL 16 DAY, CURDATE() - INTERVAL 2  DAY),  -- 15 (overdue)
(12, 5 , CURDATE() - INTERVAL 3  DAY, CURDATE() + INTERVAL 11 DAY),  -- 16 (current)
(9 , 9 , CURDATE() - INTERVAL 8  DAY, CURDATE() + INTERVAL 6  DAY);  -- 17 (current)

-- Now return the books that are already back (fines are created by trigger)
UPDATE issue_records SET return_date = CURDATE() - INTERVAL 28 DAY WHERE issue_id = 1;  -- on time
UPDATE issue_records SET return_date = CURDATE() - INTERVAL 22 DAY WHERE issue_id = 2;  -- on time
UPDATE issue_records SET return_date = CURDATE() - INTERVAL 18 DAY WHERE issue_id = 3;  -- on time
UPDATE issue_records SET return_date = CURDATE() - INTERVAL 15 DAY WHERE issue_id = 4;  -- on time
UPDATE issue_records SET return_date = CURDATE() - INTERVAL 25 DAY WHERE issue_id = 5;  -- 6 days late
UPDATE issue_records SET return_date = CURDATE() - INTERVAL 26 DAY WHERE issue_id = 6;  -- 10 days late
UPDATE issue_records SET return_date = CURDATE() - INTERVAL 12 DAY WHERE issue_id = 7;  -- 7 days late
UPDATE issue_records SET return_date = CURDATE() - INTERVAL 5  DAY WHERE issue_id = 8;  -- 3 days late
UPDATE issue_records SET return_date = CURDATE() - INTERVAL 47 DAY WHERE issue_id = 9;  -- on time

-- Two of the fines have already been paid
UPDATE fines SET paid_status = 'Paid', paid_date = CURDATE() - INTERVAL 20 DAY
WHERE issue_id = 5;
UPDATE fines SET paid_status = 'Paid', paid_date = CURDATE() - INTERVAL 24 DAY
WHERE issue_id = 6;

-- 4 reservations (Gitanjali has no copy left, so people reserve it)
INSERT INTO reservations (book_id, member_id, reservation_date, status) VALUES
(12, 6, CURDATE() - INTERVAL 1  DAY, 'Pending'),
(12, 7, CURDATE() - INTERVAL 2  DAY, 'Pending'),
(1,  4, CURDATE() - INTERVAL 30 DAY, 'Fulfilled'),
(5,  6, CURDATE() - INTERVAL 10 DAY, 'Cancelled');

-- >>>>>>>>>> 04_views.sql <<<<<<<<<<
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

-- >>>>>>>>>> 05_queries.sql <<<<<<<<<<
-- =====================================================================
-- File 05: 25 Queries (SELECT, WHERE, ORDER BY, GROUP BY, HAVING,
--          JOINs, subqueries, aggregates, UPDATE, DELETE)
-- =====================================================================
USE digital_library;

-- Q1. SELECT + WHERE : all books of the Computer Science category
SELECT b.title, b.publication_year, b.available_copies
FROM books b
JOIN categories c ON b.category_id = c.category_id
WHERE c.category_name = 'Computer Science';

-- Q2. ORDER BY : books sorted by price, costliest first
SELECT title, price FROM books ORDER BY price DESC;

-- Q3. Available books list (uses a view)
SELECT * FROM available_books_view;

-- Q4. Overdue books list (uses a view)
SELECT * FROM overdue_books_view ORDER BY days_overdue DESC;

-- Q5. Borrowing history of one member (member_id = 1)
SELECT * FROM member_history_view WHERE member_id = 1 ORDER BY issue_date;

-- Q6. GROUP BY + COUNT : category-wise book count
SELECT c.category_name, COUNT(b.book_id) AS number_of_titles
FROM categories c
LEFT JOIN books b ON c.category_id = b.category_id
GROUP BY c.category_name
ORDER BY number_of_titles DESC;

-- Q7. Most issued books (top 5)
SELECT b.title, COUNT(i.issue_id) AS times_issued
FROM books b
JOIN issue_records i ON b.book_id = i.book_id
GROUP BY b.title
ORDER BY times_issued DESC
LIMIT 5;

-- Q8. Total fine collected (only paid fines)
SELECT SUM(fine_amount) AS total_fine_collected
FROM fines WHERE paid_status = 'Paid';

-- Q9. Members with pending (unpaid) fines
SELECT m.full_name, SUM(f.fine_amount) AS pending_fine
FROM fines f
JOIN issue_records i ON f.issue_id = i.issue_id
JOIN members m       ON i.member_id = m.member_id
WHERE f.paid_status = 'Unpaid'
GROUP BY m.full_name;

-- Q10. LEFT JOIN : books that were never issued
SELECT b.book_id, b.title
FROM books b
LEFT JOIN issue_records i ON b.book_id = i.book_id
WHERE i.issue_id IS NULL;

-- Q11. Subquery : members who have borrowed more than the average number of books
SELECT m.full_name, COUNT(i.issue_id) AS books_borrowed
FROM members m
JOIN issue_records i ON m.member_id = i.member_id
GROUP BY m.member_id, m.full_name
HAVING COUNT(i.issue_id) > (
    SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM issue_records GROUP BY member_id) t
);

-- Q12. Books currently issued, with the member name and days left
SELECT b.title, m.full_name, i.due_date, DATEDIFF(i.due_date, CURDATE()) AS days_left
FROM issue_records i
JOIN books b   ON i.book_id = b.book_id
JOIN members m ON i.member_id = m.member_id
WHERE i.status = 'Issued'
ORDER BY i.due_date;

-- Q13. Books together with all their authors (GROUP_CONCAT)
SELECT b.title, GROUP_CONCAT(a.author_name SEPARATOR ', ') AS authors
FROM books b
JOIN book_authors ba ON b.book_id = ba.book_id
JOIN authors a       ON ba.author_id = a.author_id
GROUP BY b.book_id, b.title;

-- Q14. Publisher-wise number of books and total copies
SELECT p.publisher_name, COUNT(b.book_id) AS titles, SUM(b.total_copies) AS copies
FROM publishers p
JOIN books b ON p.publisher_id = b.publisher_id
GROUP BY p.publisher_name;

-- Q15. HAVING : categories that have more than 2 titles
SELECT c.category_name, COUNT(b.book_id) AS titles
FROM categories c
JOIN books b ON c.category_id = b.category_id
GROUP BY c.category_name
HAVING COUNT(b.book_id) > 2;

-- Q16. AVG : average price of books per category
SELECT c.category_name, ROUND(AVG(b.price), 2) AS average_price
FROM categories c
JOIN books b ON c.category_id = b.category_id
GROUP BY c.category_name;

-- Q17. Pending reservations with member and book names
SELECT r.reservation_id, m.full_name, b.title, r.reservation_date
FROM reservations r
JOIN members m ON r.member_id = m.member_id
JOIN books b   ON r.book_id   = b.book_id
WHERE r.status = 'Pending';

-- Q18. Books that have no copy available at the moment
SELECT title, total_copies, available_copies FROM books WHERE available_copies = 0;

-- Q19. Member-type wise number of issues
SELECT m.member_type, COUNT(i.issue_id) AS total_issues
FROM members m
LEFT JOIN issue_records i ON m.member_id = i.member_id
GROUP BY m.member_type;

-- Q20. Members who currently hold overdue books (subquery with IN)
SELECT full_name, email
FROM members
WHERE member_id IN (SELECT member_id FROM overdue_books_view);

-- Q21. Library utilization report (uses a view)
SELECT * FROM library_utilization_view;

-- Q22. Fine summary : paid vs unpaid
SELECT paid_status, COUNT(*) AS number_of_fines, SUM(fine_amount) AS total_amount
FROM fines GROUP BY paid_status;

-- Q23. UPDATE : suspend a member who holds an overdue book of 10+ days
UPDATE members SET status = 'Suspended'
WHERE member_id IN (
    SELECT member_id FROM (
        SELECT DISTINCT member_id
        FROM issue_records
        WHERE return_date IS NULL AND DATEDIFF(CURDATE(), due_date) >= 10
    ) AS late_members
);
SELECT member_id, full_name, status FROM members WHERE status = 'Suspended';

-- Q24. UPDATE : change the shelf location of a book
UPDATE books SET shelf_location = 'CS-A9' WHERE book_id = 13;
SELECT title, shelf_location FROM books WHERE book_id = 13;

-- Q25. DELETE : remove cancelled reservations
DELETE FROM reservations WHERE status = 'Cancelled';
SELECT reservation_id, status FROM reservations;

-- >>>>>>>>>> 06_procedure_and_transaction_demo.sql <<<<<<<<<<
-- =====================================================================
-- File 06: Demo of Stored Procedures, Function and Transactions
-- =====================================================================
USE digital_library;

-- ---- A. Function demo : Rs 5 per late day ---------------------------
SELECT fn_calculate_fine('2026-11-01', '2026-11-08') AS fine_for_7_late_days,
       fn_calculate_fine('2026-11-01', '2026-10-30') AS fine_for_early_return;

-- ---- B. Procedure 1 : issue a book ----------------------------------
CALL sp_issue_book(6, 4, 14);    -- Ananya takes 'Higher Engineering Mathematics' -> success
CALL sp_issue_book(3, 2, 14);    -- Rohan has an unpaid fine                      -> fails
CALL sp_issue_book(10, 7, 14);   -- Arjun is suspended                            -> fails
CALL sp_issue_book(2, 12, 14);   -- Gitanjali has no copies                       -> fails

-- ---- C. Procedure 3 : reserve a book --------------------------------
CALL sp_reserve_book(2, 12);     -- no copy available    -> success
CALL sp_reserve_book(2, 12);     -- already reserved     -> fails
CALL sp_reserve_book(2, 7);      -- copies are available -> fails

-- ---- D. Procedure 2 : return a book (late) --------------------------
-- Issue 11 is overdue; the trigger creates the fine automatically.
CALL sp_return_book(11, CURDATE());
SELECT * FROM fines WHERE issue_id = 11;
CALL sp_return_book(11, CURDATE());   -- already returned -> fails

-- ---- E. Trigger demo : stock goes up/down automatically -------------
SELECT title, total_copies, available_copies FROM books WHERE book_id IN (4, 5);

-- ---- F. Trigger demo : issuing with zero copies is blocked ----------
-- Un-comment the next line to see the error from trg_before_issue:
-- INSERT INTO issue_records (book_id, member_id, issue_date, due_date)
-- VALUES (12, 2, CURDATE(), CURDATE() + INTERVAL 14 DAY);

-- ---- G. TRANSACTION with ROLLBACK : undo a mistake ------------------
START TRANSACTION;
    INSERT INTO issue_records (book_id, member_id, issue_date, due_date)
    VALUES (11, 8, CURDATE(), CURDATE() + INTERVAL 14 DAY);
    SELECT 'Inside transaction' AS step, title, available_copies FROM books WHERE book_id = 11;
ROLLBACK;
SELECT 'After ROLLBACK' AS step, title, available_copies FROM books WHERE book_id = 11;

-- ---- H. TRANSACTION with COMMIT : save the change permanently -------
START TRANSACTION;
    INSERT INTO issue_records (book_id, member_id, issue_date, due_date)
    VALUES (11, 8, CURDATE(), CURDATE() + INTERVAL 14 DAY);
COMMIT;
SELECT 'After COMMIT' AS step, title, available_copies FROM books WHERE book_id = 11;
