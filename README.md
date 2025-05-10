# 📚 BookManagement Database System

A comprehensive SQL Server relational database for managing a fictional book retail system, supporting customers, orders, payments, reviews, inventory, and publisher interactions.

---

## 📦 Features

- At least 6 relational tables with over 20 attributes total
- Includes 1:1, 1:N, and M:N (via weak/ternary) relationships
- Uses structural constraints like (0,N) and (1,1)
- Implements:
  - Views for reporting and analytics
  - Triggers for automatic enforcement
  - Check constraints and defaults for data integrity

---

## 🛠️ Technologies Used

- SQL Server (T-SQL)
- SSMS or Azure Data Studio
- Excel (for data population)

---

## 🧱 Table Overview

| Table             | Description                              |
|------------------|------------------------------------------|
| `Books`          | Book inventory with title, genre, ISBN   |
| `Customer`       | Buyer info with 1:1 `CustomerProfile`    |
| `Orders`         | Order header, customer and date info     |
| `OrderDetails`   | Line items of each order (1:N relation)  |
| `Payments`       | Payment records for orders               |
| `Reviews`        | Customer reviews for books               |
| `Publisher`      | Publisher contact information            |
| `BookEdition`    | Weak entity for editions of books        |
| `BookPromotion`  | Ternary relationship (Book-Customer-Publisher) |

---

## 📊 Views

- `TopRatedBooks` – Average rating of books
- `RecentOrders` – Orders placed in last 30 days
- `LowStockBooks` – Books with fewer than 10 units in stock
- `CustomerPurchaseSummary` – Spending per customer
- `BookPromotions` – Promotions via ternary relationship
- `MostPurchasedBooks`, `vw_BooksNeverReviewed`, etc.

---

## ⚙️ Triggers

- Automatically update book stock on order
- Prevent duplicate reviews
- Validate payment method
- Set default loyalty points, etc

---

## 🔁 Stored Procedures
 Did not add procedures but it's something i can work on in the future

---

## 📂 Files Included

- `tables and attributes.sql` – Table and Views creation scripts
- `Data.sql` –  data (≥100 rows)
- ` constraints and triggers.sql` – Triggers for automation and additional constraints
- `BookManagement_Data.xlsx` – Data import file (if needed)
- `Queries.sql` – sql queries to run to test the database maybe
---

## 🚀 How to Use

1. Open SQL Server Management Studio
2. Run `tables and attributies.sql` to create schema
3. Import data using Excel or `data.sql`
4. Run `constraints and triggers.sql`
5. Query data or test procedures/views

---

## 📝 Notes

- Make sure to enable foreign key checks and identity insert where needed
- Designed for academic purposes and extendable for production use

---

## 📫 Contact

Author: Sofiat Adeyemi  
Email: sofiatadeyemi78@gmail.com
GitHub: github.com/sofiaade

---

