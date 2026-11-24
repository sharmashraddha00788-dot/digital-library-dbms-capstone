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
