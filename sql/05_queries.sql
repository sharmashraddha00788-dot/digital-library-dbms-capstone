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
