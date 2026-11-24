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
