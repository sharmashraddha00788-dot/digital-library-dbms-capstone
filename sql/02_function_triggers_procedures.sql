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
