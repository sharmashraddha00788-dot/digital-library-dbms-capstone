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
