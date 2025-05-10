USE master
GO

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'BookManagement')
DROP DATABASE BookManagement
GO

CREATE DATABASE BookManagement
GO

USe BookManagement
GO

DROP TABLE IF EXISTS Reviews;
CREATE TABLE Reviews
(
	Id INT ,
	Customer_Id INT NOT NULL,
	Book_Id INT NOT NULL,
	Rating INT NOT NULL,
	Review_Text VARCHAR(255),
	PRIMARY KEY(Id),
	FOREIGN KEY (Customer_Id) REFERENCES Customer(ID),
	FOREIGN KEY (Book_Id) REFERENCES Books(Id)

);

DROP TABLE IF EXISTS Books;
CREATE TABLE Books
(
	Id INT PRIMARY KEY,
	Title	VARCHAR(255) UNIQUE NOT NULL,
	Author	VARCHAR(255) NOT NULL,
	Genre	VARCHAR(255),
	Price DECIMAL(6, 2) NOT NULL,
	Stock INT,
	ISBN VARCHAR(255) UNIQUE,
	Publisher VARCHAR(255) NOT NULL,
	FOREIGN KEY (Publisher) REFERENCES Publisher(Name),
);

--Customer ? Customer Profile works as 1:1

DROP TABLE IF EXISTS Customer;
CREATE TABLE Customer
(
	ID INT PRIMARY KEY,
	Name VARCHAR (255) NOT NULL,
	Email VARCHAR (255),
	Address VARCHAR (255) NOT NULL,
	Phone VARCHAR (255),
	AccountCreationDate VARCHAR (255) NOT NULL,
)

DROP TABLE IF EXISTS CustomerProfile;
CREATE TABLE CustomerProfile (
    CustomerID INT PRIMARY KEY NOT NULL,  -- also a FK referencing Customer
    DateOfBirth DATE,
    Gender VARCHAR(10),
    PreferredGenre VARCHAR(30),
    LoyaltyPoints INT,
    FOREIGN KEY (CustomerID) REFERENCES Customer(ID)
);


--Orders ? OrderDetails already works as 1:N

DROP TABLE IF EXISTS Orders;
CREATE TABLE Orders
(
	Id INT PRIMARY KEY ,
	CustomerID INT NOT NULL,
	OrderDate DATETIME NOT NULL,
	TotalAmount DECIMAL NOT NULL,
	Status VARCHAR(255),
	FOREIGN KEY (CustomerID) REFERENCES Customer(ID)
);

DROP TABLE IF EXISTS OrderDetails;
CREATE TABLE OrderDetails
(
	Id INT PRIMARY KEY ,
	OrderID INT NOT NULL,
	BooksID INT NOT NULL,
	Quantity INT NOT NULL,
	Subtotal INT NOT NULL,
	FOREIGN KEY (OrderID) REFERENCES Orders(Id),
	FOREIGN KEY (BooksID) REFERENCES Books(Id)
);

DROP TABLE IF EXISTS Payments;
CREATE TABLE Payments
(
	Id INT PRIMARY KEY ,
	Order_Id INT NOT NULL,
	Book_Id INT NOT NULL DEFAULT 3,
	Payment_Methods VARCHAR (255) NOT NULL,
	Payment_Date DATETIME,
	Payment_Amount INT NOT NULL,
	FOREIGN KEY (Order_Id) REFERENCES Orders(Id),
	FOREIGN KEY (Book_Id) REFERENCES Books(Id),
);

DROP TABLE IF EXISTS Publisher;
CREATE TABLE Publisher
(
	Name VARCHAR (255) PRIMARY KEY NOT NULL,
	Email VARCHAR (255) NOT NULL,
	Address VARCHAR (255) NOT NULL,
	Phone VARCHAR (255) NOT NULL,
)

--WEAK entity-- 
DROP TABLE IF EXISTS BookEdition;
CREATE TABLE BookEdition (
  EditionID INT, 
  BookId INT,
  PublishedYear INT,
  EditionInfo VARCHAR(100),
  PRIMARY KEY (EditionID, BookId),
  FOREIGN KEY (BookId) REFERENCES Books(Id)
);

--Ternary Relationship

DROP TABLE IF EXISTS BookPromotion;
CREATE TABLE BookPromotion(
Book_Id INT,
Publisher_Name VARCHAR (255), 
Customer_Id INT, 
PromotionDate DATETIME,
FOREIGN KEY (Book_Id) REFERENCES Books(Id),
FOREIGN KEY (Publisher_Name) REFERENCES Publisher(Name),
FOREIGN KEY (Customer_Id) REFERENCES Customer(Id),
);

-- alter - forgot to add pk
ALTER TABLE BookPromotion
ADD PromotionID INT;

WITH NumberedPromotions AS (
  SELECT 
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum,
    Book_Id, Publisher_Name, Customer_Id, PromotionDate
  FROM BookPromotion
)
UPDATE bp
SET PromotionID = np.RowNum
FROM BookPromotion bp
JOIN NumberedPromotions np
  ON bp.Book_Id = np.Book_Id
 AND bp.Publisher_Name = np.Publisher_Name
 AND bp.Customer_Id = np.Customer_Id
 AND bp.PromotionDate = np.PromotionDate;

ALTER TABLE BookPromotion
ALTER COLUMN PromotionID INT NOT NULL

-- Step 2: Add the primary key constraint on PromotionID
ALTER TABLE BookPromotion
ADD CONSTRAINT PK_BookPromotion PRIMARY KEY (PromotionID);

--	Views

-- Create a View: Customer Purchase Summary
DROP VIEW CustomerPurchaseSummary
CREATE VIEW CustomerPurchaseSummary AS
SELECT 
    c.ID AS CustomerID,
    c.Name,
    COUNT(o.Id) AS TotalOrders,
    SUM(p.Payment_Amount) AS TotalSpent
FROM Customer c
LEFT JOIN Orders o ON c.ID = o.CustomerID
LEFT JOIN Payments p ON o.Id = p.Order_Id
GROUP BY c.ID, c.Name;

--Book Inventory Summary : Shows books with their current stock and price:
DROP VIEW BookInventory
CREATE VIEW BookInventory AS
SELECT 
    Id AS BookID,
    Title,
    Author,
    Genre,
    Price,
    Stock
FROM Books;

-- Customer Order History: Combines customer, order, and order details:

DROP VIEW CustomerOrderHistory
CREATE VIEW CustomerOrderHistory AS
SELECT 
    c.ID AS CustomerID,
    c.Name,
    o.Id AS OrderID,
    o.OrderDate,
    b.Title AS BookTitle,
    od.Quantity,
    od.Subtotal
FROM Customer c
JOIN Orders o ON c.ID = o.CustomerID
JOIN OrderDetails od ON o.Id = od.OrderID
JOIN Books b ON od.BooksID = b.Id;

-- Payment Summary by Method : Aggregates payments:

DROP VIEW PaymentSummary
CREATE VIEW PaymentSummary AS
SELECT 
    Payment_Methods,
    COUNT(*) AS NumberOfPayments,
    SUM(Payment_Amount) AS TotalAmount
FROM Payments
GROUP BY Payment_Methods;

-- Unpaid Orders: Lists orders with no matching payment:

DROP VIEW UnpaidOrders
CREATE VIEW UnpaidOrders AS
SELECT 
    o.Id AS OrderID,
    o.CustomerID,
    o.OrderDate,
    o.TotalAmount,
    o.Status
FROM Orders o
LEFT JOIN Payments p ON o.Id = p.Order_Id
WHERE p.Id IS NULL;

-- Top Rated Books: Shows average ratings for books:

DROP VIEW TopRatedBooks
CREATE VIEW TopRatedBooks AS
SELECT 
    b.Id AS BookID,
    b.Title,
    AVG(r.Rating) AS AverageRating,
    COUNT(r.Id) AS ReviewCount
FROM Books b
JOIN Reviews r ON b.Id = r.Book_Id
GROUP BY b.Id, b.Title
HAVING COUNT(r.Id) >= 4; -- only books with 4+ reviews

-- Recent Orders

DROP VIEW RecentOrders
CREATE VIEW RecentOrders AS
SELECT 
    o.Id AS OrderID,
    o.CustomerID,
    c.Name AS CustomerName,
    o.OrderDate,
    o.TotalAmount,
    o.Status
FROM Orders o
JOIN Customer c ON o.CustomerID = c.ID
WHERE o.OrderDate >= DATEADD(DAY, -30, GETDATE());

--Books With Multiple Editions

DROP VIEW BookWithEditions
CREATE VIEW BookWithEditions AS
SELECT 
    b.Id AS BookID,
    b.Title,
    COUNT(e.EditionID) AS EditionCount
FROM Books b
JOIN BookEdition e ON b.Id = e.BookId
GROUP BY b.Id, b.Title;

-- to know when a book stock is low
DROP VIEW LowStockBooks
CREATE VIEW LowStockBooks AS
SELECT 
    Id,
    Title,
    Stock
FROM Books
WHERE Stock IS NOT NULL AND Stock < 10

-- Book Promotions Overview (Ternary Relation)

DROP VIEW BookPromotions
CREATE VIEW BookPromotions AS
SELECT 
    bp.Book_Id,
    b.Title,
    bp.Publisher_Name,
    p.Email AS PublisherEmail,
    bp.Customer_Id,
    c.Name AS CustomerName,
    bp.PromotionDate
FROM BookPromotion bp
JOIN Books b ON bp.Book_Id = b.Id
JOIN Publisher p ON bp.Publisher_Name = p.Name
JOIN Customer c ON bp.Customer_Id = c.ID;

--View: Book Edition Details (Weak Entity)

DROP VIEW BookEditionDetails 
CREATE VIEW BookEditionDetails AS
SELECT 
    b.Id AS BookID,
    b.Title,
    be.EditionID,
    be.PublishedYear,
    be.EditionInfo
FROM BookEdition be
JOIN Books b ON be.BookId = b.Id;

-- Most Purchased Books

DROP VIEW MostPurchasedBooks
CREATE VIEW MostPurchasedBooks AS
SELECT 
    b.Id,
    b.Title,
    SUM(od.Quantity) AS TotalSold
FROM OrderDetails od
JOIN Books b ON od.BooksID = b.Id
GROUP BY b.Id, b.Title

-- Customers with No Orders

DROP VIEW CustomersWithNoOrders
CREATE VIEW CustomersWithNoOrders AS
SELECT 
    c.ID,
    c.Name,
    c.Email
FROM Customer c
LEFT JOIN Orders o ON c.ID = o.CustomerID
WHERE o.Id IS NULL;

--Daily Sales Summary

DROP VIEW DailySalesSummary 
CREATE VIEW DailySalesSummary AS
SELECT 
    CONVERT(DATE, OrderDate) AS SaleDate,
    COUNT(DISTINCT o.Id) AS OrdersCount,
    SUM(od.Subtotal) AS TotalSales
FROM Orders o
JOIN OrderDetails od ON o.Id = od.OrderID
GROUP BY CONVERT(DATE, OrderDate)

-- Payment Method Usage

DROP VIEW PaymentMethodStats
CREATE VIEW PaymentMethodStats AS
SELECT 
    Payment_Methods,
    COUNT(*) AS PaymentCount,
    SUM(Payment_Amount) AS TotalPaid
FROM Payments
GROUP BY Payment_Methods

--Books Never

DROP VIEW BooksNeverReviewed
CREATE VIEW BooksNeverReviewed AS
SELECT 
    b.Id,
    b.Title,
    b.Author
FROM Books b
LEFT JOIN Reviews r ON b.Id = r.Book_Id
WHERE r.Id IS NULL;

--Inactive Customers (No Recent Orders)

DROP VIEW InactiveCustomers
CREATE VIEW InactiveCustomers AS
SELECT 
    c.ID,
    c.Name,
    MAX(o.OrderDate) AS LastOrderDate
FROM Customer c
LEFT JOIN Orders o ON c.ID = o.CustomerID
GROUP BY c.ID, c.Name
HAVING MAX(o.OrderDate) IS NULL OR MAX(o.OrderDate) < DATEADD(MONTH, -6, GETDATE());

--Customers by Preferred Genre

DROP VIEW CustomersByGenre
CREATE VIEW CustomersByGenre AS
SELECT 
    cp.PreferredGenre,
    COUNT(*) AS CustomerCount
FROM CustomerProfile cp
WHERE cp.PreferredGenre IS NOT NULL
GROUP BY cp.PreferredGenre




/*
SELECT *
from Customer

UPDATE Review
SET Rating = '5'
WHERE Id = 11;

*/

SELECT *
from BookPromotion