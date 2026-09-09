
-- Drop tables if they already exist
DROP TABLE IF EXISTS order_details CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS pizzas CASCADE;
DROP TABLE IF EXISTS pizza_types CASCADE;


-- 1. pizza_types
CREATE TABLE pizza_types (
    pizza_type_id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    ingredients TEXT NOT NULL
);

-- 2. pizzas
CREATE TABLE pizzas (
    pizza_id VARCHAR(50) PRIMARY KEY,
    pizza_type_id VARCHAR(50) NOT NULL REFERENCES pizza_types(pizza_type_id) ON UPDATE CASCADE,
    size VARCHAR(5) NOT NULL,
    price NUMERIC(6,2) NOT NULL CHECK (price > 0)
);

-- 3. orders
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    date DATE NOT NULL,
    time TIME NOT NULL
);

-- 4. order_details
CREATE TABLE order_details (
    order_details_id INT PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(order_id) ON UPDATE CASCADE ON DELETE CASCADE,
    pizza_id VARCHAR(50) NOT NULL REFERENCES pizzas(pizza_id) ON UPDATE CASCADE,
    quantity INT NOT NULL CHECK (quantity > 0)
);

SELECT * FROM pizza_types;
SELECT * FROM pizzas;
SELECT * FROM orders;
SELECT * FROM order_details;


SELECT 'pizza_types' AS table_name, COUNT(*) AS row_count FROM pizza_types
UNION ALL
SELECT 'pizzas', COUNT(*) FROM pizzas
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_details', COUNT(*) FROM order_details;




-- Basic Analysis


-- 1. Retrieve the total number of orders placed

SELECT COUNT(order_id) AS total_orders 
FROM orders;


-- 2. Calculate the total revenue generated from pizza sales

SELECT 
    ROUND(SUM(od.quantity * p.price)::NUMERIC, 2) AS total_revenue
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id;


-- 3. Identify the highest-priced pizza

SELECT 
    pt.name,
    p.size,
    p.price
FROM pizzas p
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
ORDER BY p.price DESC
LIMIT 1;


-- 4. What is the total quantity of all pizzas sold?

SELECT SUM(quantity) AS total_pizzas_sold
FROM order_details;

-- 5. What is the lowest-priced pizza on the menu?

SELECT 
    pt.name,
    p.size,
    p.price
FROM pizzas p
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
ORDER BY p.price ASC
LIMIT 1;

-- 6. How many distinct pizza categories does the restaurant offer?

SELECT 
    COUNT(DISTINCT category) AS total_categories,
    STRING_AGG(DISTINCT category, ', ') AS category_names
FROM pizza_types;

-- 7. What is the date of the first and last order recorded in the dataset?

SELECT 
    MIN(date) AS first_order_date,
    MAX(date) AS last_order_date
FROM orders;

-- 8. How many total distinct pizza SKUs (combinations of pizza and size) exist?

SELECT COUNT(pizza_id) AS total_skus
FROM pizzas;


-- 9. Which pizza sizes exist on the menu and what is their average price?

SELECT 
    size,
    COUNT(pizza_id) AS total_pizzas,
    ROUND(AVG(price)::NUMERIC, 2) AS average_price
FROM pizzas
GROUP BY size
ORDER BY average_price DESC;

-- 10. Which pizza sizes exist on the menu and what is their average price?

SELECT 
    p.size,
    COUNT(od.order_details_id) AS times_ordered,
    SUM(od.quantity) AS total_pizzas_sold
FROM pizzas p
JOIN order_details od ON p.pizza_id = od.pizza_id
GROUP BY p.size
ORDER BY total_pizzas_sold DESC;

-- 11. List the top 5 most ordered pizza types along with their quantities

SELECT 
    pt.name,
    SUM(od.quantity) AS total_quantity_ordered
FROM pizza_types pt
JOIN pizzas p ON pt.pizza_type_id = p.pizza_type_id
JOIN order_details od ON od.pizza_id = p.pizza_id
GROUP BY pt.name
ORDER BY total_quantity_ordered DESC
LIMIT 5;

-- 12. What are the minimum, maximum, and average pizza prices on the menu?

SELECT 
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    ROUND(AVG(price)::NUMERIC, 2) AS avg_price
FROM pizzas;

-- 13. How many orders contained only one single pizza?

SELECT COUNT(*) AS single_pizza_orders
FROM (
    SELECT order_id, SUM(quantity) AS total_qty
    FROM order_details
    GROUP BY order_id
    HAVING SUM(quantity) = 1
) AS single_orders;

-- 14. How many distinct pizzas belong to the "Veggie" category?

SELECT 
    COUNT(pizza_type_id) AS veggie_pizza_count
FROM pizza_types
WHERE category = 'Veggie';