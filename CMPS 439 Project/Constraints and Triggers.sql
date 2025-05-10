--CONSTRAINTS

ALTER TABLE Reviews
ADD CONSTRAINT CHK_Review_Rating CHECK (Rating BETWEEN 1 AND 5);

ALTER TABLE CustomerProfile
ADD CONSTRAINT DF_LoyaltyPoints DEFAULT 0 FOR LoyaltyPoints;

-- Price must be greater than zero
ALTER TABLE Books
ADD CONSTRAINT CHK_Book_Price CHECK (Price > 0);

-- Quantity in OrderDetails must be positive
ALTER TABLE OrderDetails
ADD CONSTRAINT CHK_Quantity CHECK (Quantity > 0);

--Prevents future-dated payments.
ALTER TABLE Payments
ADD CONSTRAINT CHK_Payment_Date CHECK (Payment_Date <= GETDATE());

--Prevents future-dated Ordercs.
ALTER TABLE Orders
ADD CONSTRAINT CHK_Order_Date CHECK (OrderDate <= GETDATE());


-- Prevents the same book being added twice to the same order.
ALTER TABLE OrderDetails
ADD CONSTRAINT UQ_Order_Book UNIQUE (OrderID, BooksID);

--Pre-fill values if not provided:
ALTER TABLE Orders
ADD CONSTRAINT DF_Order_Status DEFAULT 'Pending' FOR Status;

ALTER TABLE Customer
ADD CONSTRAINT UQ_Email UNIQUE (Email);

ALTER TABLE Books
ADD CONSTRAINT CHK_BOOK_ISBN UNIQUE (ISBN);

-- Only accept 5 types of payment methods
ALTER TABLE Payments
ADD CONSTRAINT CHK_Payment_Methods CHECK (
    Payment_Methods IN ('Credit Card', 'PayPal', 'Gift Card', 'Bank Transfer', 'Debit Card')
);

-- limit book stock to non negative
ALTER TABLE Books
ADD CONSTRAINT CHK_Book_Stock CHECK (Stock >= 0);

--Loyalty Points Must Be Non-negative

ALTER TABLE CustomerProfile
ADD CONSTRAINT CHK_LoyaltyPoints CHECK (LoyaltyPoints >= 0);

-- Ensures a customer cannot review the same book twice.
ALTER TABLE Reviews
ADD CONSTRAINT UQ_Review_UniqueCustomerBook UNIQUE (Customer_Id, Book_Id);

--Force ISBN Length = 13
ALTER TABLE Books
ADD CONSTRAINT CHK_ISBN_Length CHECK (LEN(ISBN) = 13 OR ISBN IS NULL);

-- Prevent Payment Amounts Below $10
ALTER TABLE Payments
ADD CONSTRAINT CHK_Min_PaymentAmount CHECK (Payment_Amount >= 10);

-- Force Positive Quantity in OrderDetails
ALTER TABLE OrderDetails
ADD CONSTRAINT CHK_Positive_Quantity CHECK (Quantity > 0);

--. Ensure Book Price is Within Reasonable Range
ALTER TABLE Books
ADD CONSTRAINT CHK_Book_PriceRange CHECK (
    Price BETWEEN 1 AND 1000
);

-- Enforce Email Format (basic LIKE check)
ALTER TABLE Customer
ADD CONSTRAINT CHK_Email_Format CHECK (
    Email LIKE '_%@_%._%' OR Email IS NULL
);


--TRIGGERS

-- ensure Payments.Payment_Amount equals the Order.TotalAmount.
DROP TRIGGER TRG_ValidatePaymentAmount
CREATE TRIGGER TRG_ValidatePaymentAmount
ON Payments
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Payments p
        JOIN Orders o ON p.Order_Id = o.Id
        WHERE p.Payment_Amount <> o.TotalAmount
    )
    BEGIN
        RAISERROR('Payment amount must match order total.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;

-- Prevent Duplicate Book Titles per Author
DROP TRIGGER TRG_PreventDuplicateTitlePerAuthor
CREATE TRIGGER TRG_PreventDuplicateTitlePerAuthor
ON Books
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN Books b ON i.Title = b.Title AND i.Author = b.Author AND i.Id != b.Id
    )
    BEGIN
        RAISERROR('An author cannot publish the same book title more than once.', 16, 1);
        ROLLBACK;
    END
    ELSE
    BEGIN
        INSERT INTO Books SELECT * FROM inserted;
    END
END;


-- Validate Subtotal = Book Price × Quantity
DROP TRIGGER TRG_CheckSubtotal
CREATE TRIGGER TRG_CheckSubtotal
ON OrderDetails
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM OrderDetails od
        JOIN Books b ON od.BooksID = b.Id
        WHERE od.Subtotal <> b.Price * od.Quantity
    )
    BEGIN
        RAISERROR('Subtotal must be equal to book price multiplied by quantity.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;

-- Prevent Orders With No Items

DROP TRIGGER TRG_PreventEmptyOrder
CREATE TRIGGER TRG_PreventEmptyOrder
ON Orders
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT o.Id
        FROM inserted o
        LEFT JOIN OrderDetails od ON o.Id = od.OrderID
        GROUP BY o.Id
        HAVING COUNT(od.Id) = 0
    )
    BEGIN
        RAISERROR('Orders must contain at least one item.', 16, 1);
        ROLLBACK;
    END
END;

-- Auto-Assign Loyalty Points on Payment : Adds 1 point for every $10 spent.

DROP TRIGGER TRG_AwardLoyaltyPoints
CREATE TRIGGER TRG_AwardLoyaltyPoints
ON Payments
AFTER INSERT
AS
BEGIN
    UPDATE cp
    SET cp.LoyaltyPoints = cp.LoyaltyPoints + i.Payment_Amount / 10
    FROM CustomerProfile cp
    JOIN Orders o ON cp.CustomerID = o.CustomerID
    JOIN inserted i ON i.Order_Id = o.Id;
END;

-- Prevent Deletion of Books That Are Ordered

DROP TRIGGER TRG_PreventBookDelete
CREATE TRIGGER TRG_PreventBookDelete
ON Books
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM deleted d
        JOIN OrderDetails od ON d.Id = od.BooksID
    )
    BEGIN
        RAISERROR('Cannot delete books that have been ordered.', 16, 1);
        ROLLBACK;
    END
    ELSE
    BEGIN
        DELETE FROM Books WHERE Id IN (SELECT Id FROM deleted);
    END
END;

--Automatically Update Stock on Order

DROP TRIGGER TRG_DecreaseStockAfterOrder
CREATE TRIGGER TRG_DecreaseStockAfterOrder
ON OrderDetails
AFTER INSERT
AS
BEGIN
    UPDATE b
    SET b.Stock = b.Stock - i.Quantity
    FROM Books b
    JOIN inserted i ON b.Id = i.BooksID;

    -- Check if any book went negative
    IF EXISTS (SELECT 1 FROM Books WHERE Stock < 0)
    BEGIN
        RAISERROR('Not enough stock for one or more ordered books.', 16, 1);
        ROLLBACK;
    END
END;

-- Prevent Customer Account Deletion if Orders Exist

DROP TRIGGER TRG_PreventCustomerDelete
CREATE TRIGGER TRG_PreventCustomerDelete
ON Customer
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM Orders o
        JOIN deleted d ON o.CustomerID = d.ID
    )
    BEGIN
        RAISERROR('Cannot delete customer with existing orders.', 16, 1);
        ROLLBACK;
    END
    ELSE
    BEGIN
        DELETE FROM Customer WHERE ID IN (SELECT ID FROM deleted);
    END
END;

-- Set Default Order Status to 'Pending'

DROP TRIGGER TRG_DefaultOrderStatus
CREATE TRIGGER TRG_DefaultOrderStatus
ON Orders
INSTEAD OF INSERT
AS
BEGIN
    INSERT INTO Orders (Id, CustomerID, OrderDate, TotalAmount, Status)
    SELECT Id, CustomerID, OrderDate, TotalAmount,
           ISNULL(Status, 'Pending')
    FROM inserted;
END;

-- Prevent Payment Before Order

DROP TRIGGER TRG_PaymentAfterOrder
CREATE TRIGGER TRG_PaymentAfterOrder
ON Payments
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted p
        JOIN Orders o ON o.Id = p.Order_Id
        WHERE p.Payment_Date < o.OrderDate
    )
    BEGIN
        RAISERROR('Payment date cannot be before order date.', 16, 1);
        ROLLBACK;
    END
END;

-- Auto-Cancel Orders After 7 Days If No Payment

DROP TRIGGER TRG_AutoCancelLateOrders
CREATE TRIGGER TRG_AutoCancelLateOrders
ON Payments
AFTER INSERT
AS
BEGIN
    UPDATE Orders
    SET Status = 'Cancelled'
    WHERE Id IN (
        SELECT o.Id
        FROM Orders o
        LEFT JOIN Payments p ON o.Id = p.Order_Id
        WHERE DATEDIFF(DAY, o.OrderDate, GETDATE()) > 7
        AND NOT EXISTS (
            SELECT 1 FROM Payments p2 WHERE p2.Order_Id = o.Id
        )
    );
END;

-- Prevent Editing Completed Orders

DROP TRIGGER TRG_PreventUpdateCompletedOrders
CREATE TRIGGER TRG_PreventUpdateCompletedOrders
ON Orders
INSTEAD OF UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN Orders o ON o.Id = i.Id
        WHERE o.Status = 'Completed'
    )
    BEGIN
        RAISERROR('Completed orders cannot be modified.', 16, 1);
        ROLLBACK;
    END
    ELSE
    BEGIN
        UPDATE Orders
        SET CustomerID = i.CustomerID,
            OrderDate = i.OrderDate,
            TotalAmount = i.TotalAmount,
            Status = i.Status
        FROM inserted i
        WHERE Orders.Id = i.Id;
    END
END;


-- Enforce Only One Active Promotion per Book

DROP TRIGGER TRG_OneActivePromotionPerBook
CREATE TRIGGER TRG_OneActivePromotionPerBook
ON BookPromotion
AFTER INSERT
AS
BEGIN
    IF EXISTS (
        SELECT Book_Id
        FROM BookPromotion
        GROUP BY Book_Id
        HAVING COUNT(*) > 5
    )
    BEGIN
        RAISERROR('A book can only have at most 5 active promotions at a time.', 16, 1);
        ROLLBACK;
    END
END;

-- Prevent Underage Profiles (<13 years old)

DROP TRIGGER TRG_PreventUnderageProfile
CREATE TRIGGER TRG_PreventUnderageProfile
ON CustomerProfile
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE DATEDIFF(YEAR, DateOfBirth, GETDATE()) < 13
    )
    BEGIN
        RAISERROR('Customer must be at least 13 years old.', 16, 1);
        ROLLBACK;
    END
    ELSE
    BEGIN
        INSERT INTO CustomerProfile (CustomerID, DateOfBirth, Gender, PreferredGenre, LoyaltyPoints)
        SELECT CustomerID, DateOfBirth, Gender, PreferredGenre, LoyaltyPoints
        FROM inserted;
    END
END;

--  Prevent Duplicate Edition Per Year for a Book
DROP TRIGGER TRG_PreventDuplicateEditionYear
CREATE TRIGGER TRG_PreventDuplicateEditionYear
ON BookEdition
INSTEAD OF INSERT
AS
BEGIN
    IF EXISTS (
        SELECT 5
        FROM BookEdition e
        JOIN inserted i ON e.BookId = i.BookId AND e.PublishedYear = i.PublishedYear
    )
    BEGIN
        RAISERROR('A book cannot have more than five editions per year.', 16, 1);
        ROLLBACK;
    END
    ELSE
    BEGIN
        INSERT INTO BookEdition (EditionID, BookId, PublishedYear, EditionInfo)
        SELECT EditionID, BookId, PublishedYear, EditionInfo FROM inserted;
    END
END;


-- testing
SELECT DISTINCT id, Payment_Methods
FROM Payments
WHERE Payment_Methods NOT IN ('Credit Card', 'PayPal', 'Gift Card', 'Bank Transfer', 'Debit Card');

UPDATE Payments
SET Payment_Methods = 'PayPal'
WHERE id = 16

SELECT * FROM BookWithEditions;