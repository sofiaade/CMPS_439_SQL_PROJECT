/*
TEAM NAME: REGULAR
TEAM MEMBERS' NAME: Alameen Adeku, Sofiat Adeyemi


Instructions
- Descriptions must reflect a business operation's need
- One query for each item (Q..) is enough. E.g., for QD1: CREATE TABLE, write a DDL query to create one of your project's tables. Similar for the others.
- You must use the exact format
- Project a few attributes only unless otherwise said
- Do not change the order of the queries
*/

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DDL QUERIES   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--QD1: CREATE TABLE ...
/*
Instructions:
- Must define PK
- Must define a default value as needed
*/
DROP TABLE IF EXISTS Reviews;
CREATE TABLE Reviews
(
	Id INT ,
	Customer_Id INT NOT NULL,
	Book_Id INT NOT NULL DEFAULT 3,
	Rating INT NOT NULL DEFAULT 5,
	Review_Text VARCHAR(50),
	PRIMARY KEY(Id),
);

--QD2: ALTER TABLE ...
----Description:  Add Review date of DATE type as an attribute of the Reviews table.
ALTER TABLE Reviews 
ADD  Review_Date DATE;	1Q

--QD3: ADD "CHECK" CONSTRAINT:
----Description: Ensure rating is valid (i.e between 1 and 10) by adding a constraint named isValid.
ALTER TABLE Reviews
ADD CONSTRAINT isValid
CHECK(Rating>=0 AND Rating<=10);

--QD4: ADD FK CONSTRAINT(S) TO THE TABLE
/*
Instructions:
- Must define action
- At least one of the FKs must utilize the default value
*/
----Description: Create Foreign key constraint for Book_Id attribute in Reviews table.
--We have to create a books table becuase SSMS did not allow assooication of a FK with a table that is yet to be created.
DROP TABLE IF EXISTS BOOKS;
CREATE TABLE Books
(
	Id INT NOT NULL,
	Title	VARCHAR(45) UNIQUE NOT NULL,
	Author	VARCHAR(35) NOT NULL,
	Genre	VARCHAR(35),
	Price	DECIMAL NOT NULL,
	Stock	INT DEFAULT 20,
	ISBN	VARCHAR(6) UNIQUE,
	Publisher VARCHAR(45) NOT NULL,
	PRIMARY KEY(Id)
);

ALTER TABLE Reviews
ADD CONSTRAINT bookIdFkConstraint
FOREIGN KEY(Book_Id) REFERENCES Books(Id)
ON DELETE SET DEFAULT 
ON UPDATE CASCADE;

--QD5: Create TRIGGER ...
----Description: Add trigger to deny any updates to the Review table.
GO
CREATE TRIGGER RejectReviewUpdate
ON Reviews
AFTER UPDATE
AS PRINT ('Update rejected, rollback!')
ROLLBACK;
GO
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DML QUERIES   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


--QM1.1: A TEST QUERY FOR THE TRIGGER CREATED in QD5:
----Description: Create a Review tuple and try to update it; Update should be rejected.
INSERT INTO Books 
VALUES (1, 'The Hobbit', 'J.R.R. Tolkien', 'Fantasy', 10.99,50, '978-1');
INSERT INTO Reviews
VALUES (1, 1, 1, 5, 'Amazing book!','2023-12-2');

SELECT *
FROM Reviews
WHERE id = 1;

UPDATE Reviews
SET Customer_Id = 1, Rating= 9
WHERE Id = 1;

--QM1.2: A TEST QUERY FOR THE "CHECK" CONSTRAINT DEFINED in QD3
----Description: Attempt to insert a tuple into Review with a rating of 200; Insert should be rejected because it confilicts with isValid constraint.

INSERT INTO Reviews 
VALUES (2, 2, 1, 200, 'Absolutely magnificient', '2023-12-2');

--QM1.3: A TEST QUERY FOR THE FK CONSTRAINT DEFINED in QD4:
----Description: Attempt to create a review for a book that does not exist yet by inserting a non existent bookId.

INSERT INTO Reviews 
VALUES (2, 2, 2, 5, 'Decent book', '2023-12-2');
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ DML QUERIES   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--QM2: INSERT DATA:
----Description: Inserts a new book into the inventory to enable purchase by customers.
INSERT INTO Books (Id, Title, Author, Genre, Price, Stock, ISBN, Publisher)
VALUES (1, 'The Striker', 'Ana Huang', 'Romance', 18.99, 20, '9781464223327', 'Bloom Books');

--QM3: UPDATE DATA:
----Description: Reduces the stock of a book by 1 after a customer purchases it.
UPDATE Books
SET Stock = Stock - 1
WHERE ID = 1;

--QM4: DELETE DATA:
----Description: Removes books from the database when they are out of stock.
DELETE FROM Books
WHERE Stock = 0;


--QM5: QUERY DATA WITH WHERE CLAUSE:
--Description: Retrieves all dystopian books or books that are cheap and well-stocked.

SELECT Title, Author, Price
FROM Books
WHERE Genre = 'Dystopian' OR (Price < 15 AND Stock > 5);


--QM6.1: QUERY DATA WITH 'SUB-QUERY IN WHERE CLAUSE':

----Description: Finds customers who have made orders worth more than $100.
SELECT Name, Email
FROM Customer
WHERE ID IN (
  SELECT CustomerID FROM Orders WHERE TotalAmount > 100
);
--QM6.2: QUERY DATA WITH SUB-QUERY IN FROM CLAUSE:

----Description: Returns classic books that are priced under $20.
SELECT Title, Price
FROM (
  SELECT * FROM Books WHERE Genre = 'Romace'
) AS ClassicBooks
WHERE Price < 20.00;

--QM6.3: QUERY DATA WITH 'SUB-QUERY IN SELECT CLAUSE':
----Description: Displays each book along with the number of times it has been ordered.
SELECT Title,
  (SELECT COUNT(*) FROM OrderDetails WHERE OrderDetails.BooksID = Books.ID) AS TimesOrdered
FROM Books;

--QM7: QUERY DATA WITH EXCEPT:
----Description: .....................
SELECT ID FROM Customer
EXCEPT
SELECT ID FROM Orders;

--QM8.1: QUERY DATA WITH ANY/SOME:
----Description: Lists books more expensive than at least one poetry book.
SELECT Title, Price
FROM Books
WHERE Price > ANY (
  SELECT Price FROM Books WHERE Genre = 'Romance'
);

--QM8.2: QUERY DATA WITH ALL in front of a sub-query:
----Description: Finds books that are cheaper than all science books.
SELECT Title
FROM Books
WHERE Price < ALL (
  SELECT Price FROM Books WHERE Genre = 'Fiction'
);

--QM9.1: INNER-JOIN-QUERY WITH WHERE CLAUSE:
----Description: Display all customers whose orders have been delivered
SELECT C.ID, Name, Email, OrderDate, Status
FROM Customer AS C INNER JOIN Orders O ON C.ID = O.CustomerID
WHERE O.Status = 'Delivered';

--QM9.2: LEFT-OUTER-JOIN-QUERY WITH WHERE CLAUSE:
----Instruction: The query must return NULL DUE TO MISMATCHING TUPLES during the outer join:
----Description: Display customers that have orders less than 20 dollars and customers that have no orders at all.
Select C.ID, Name, Email, OrderDate, TotalAmount 
FROM Customer AS C LEFT JOIN  Orders AS O ON C.ID = O.CustomerID
WHERE TotalAmount < 20 OR TotalAmount IS NULL;


--QM9.3: RIGHT-OUTER-JOIN-QUERY WITH WHERE CLAUSE:
----Instruction: The query must return NULL DUE TO MISMATCHING TUPLES during the outer join:
----Description: Display all books along with their reviews if they have any under $25.
SELECT B.Id, Title, Price, Rating, Review_Text
FROM Reviews AS R RIGHT JOIN Books AS B ON R.Book_Id = B.Id
WHERE B.Price < 25;

--QM9.4: FULL-OUTER-JOIN-QUERY WITH WHERE CLAUSE:
----Instruction: The query must return NULL DUE TO MISMATCHING TUPLES from LEFT and RIGHT tables due to the outer join:
----Description: Display all customers with or without a order and all orders with or without a customer
Select C.ID, Name, Email, OrderDate, TotalAmount 
FROM Customer AS C FULL JOIN  Orders AS O ON C.ID = O.CustomerID
WHERE TotalAmount < 20 OR TotalAmount IS NULL;

--QM10.1: AGGREGATION-JOIN-QUERY WITH GROUP BY & HAVING:
----Description:  Display customers who have placed at least 2 orders.

SELECT C.Id, C.Name, COUNT(O.Id) AS NumOrders
FROM Customer C INNER JOIN Orders O ON C.Id = O.CustomerID
WHERE O.OrderDate IS NOT NULL
GROUP BY C.Id, C.Name
HAVING COUNT(O.Id) >= 2;

--QM10.2: AGGREGATION-JOIN-QUERY WITH SUB-QUERY:
----Description: Displays all customers who have made at least 2 orders, displaying their customer ID, name, and the number of orders they made.
SELECT C.Id, C.Name,C.Email, COUNT(O.Id) AS NumOrders
FROM Customer C INNER JOIN Orders O ON C.Id  = O.CustomerID
WHERE C.Id IN (SELECT DISTINCT Id FROM Orders)
GROUP BY C.Id, C.Name, C.Email
HAVING COUNT(O.Id) >= 2;

--QM11: WITH-QUERY:
----Description: Display all orders that are higher than the average order amount.
WITH TotalAverage(Average) AS (
	SELECT AVG(TotalAmount)
	FROM Orders
)
SELECT O.CustomerID, O.Status,O.TotalAmount, T.Average
FROM Orders O, TotalAverage T
WHERE O.TotalAmount > T.Average;


