-- 1. Calculate the percentage contribution of each pizza type to total revenue

SELECT 
    pt.name,
    ROUND(
        (SUM(od.quantity * p.price)::NUMERIC / 
         SUM(SUM(od.quantity * p.price)) OVER () * 100)::NUMERIC, 
        2
    ) AS revenue_percentage
FROM pizza_types pt
JOIN pizzas p ON pt.pizza_type_id = p.pizza_type_id
JOIN order_details od ON od.pizza_id = p.pizza_id
GROUP BY pt.name
ORDER BY revenue_percentage DESC;

-- 2. Analyze cumulative revenue generated over time

WITH daily_revenue AS (
    SELECT 
        o.date,
        SUM(od.quantity * p.price) AS revenue
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    GROUP BY o.date
)
SELECT 
    date,
    ROUND(revenue::NUMERIC, 2) AS daily_revenue,
    ROUND(SUM(revenue) OVER (ORDER BY date)::NUMERIC, 2) AS cumulative_revenue
FROM daily_revenue
ORDER BY date;

-- 3. Determine the top 3 most ordered pizza types based on revenue for each pizza category

WITH ranked_pizzas AS (
    SELECT 
        pt.category,
        pt.name,
        SUM(od.quantity * p.price) AS revenue,
        DENSE_RANK() OVER (
            PARTITION BY pt.category 
            ORDER BY SUM(od.quantity * p.price) DESC
        ) AS rank_in_category
    FROM pizza_types pt
    JOIN pizzas p ON pt.pizza_type_id = p.pizza_type_id
    JOIN order_details od ON od.pizza_id = p.pizza_id
    GROUP BY pt.category, pt.name
)
SELECT 
    category, 
    rank_in_category, 
    name, 
    ROUND(revenue::NUMERIC, 2) AS revenue
FROM ranked_pizzas
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

-- 4. 7-Day moving average of daily sales

WITH daily_totals AS (
    SELECT 
        o.date,
        SUM(od.quantity * p.price) AS daily_revenue
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    GROUP BY o.date
)
SELECT 
    date,
    ROUND(daily_revenue::NUMERIC, 2) AS daily_revenue,
    ROUND(
        AVG(daily_revenue) OVER (
            ORDER BY date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        )::NUMERIC, 
        2
    ) AS moving_avg_7d
FROM daily_totals
ORDER BY date;


-- 5. Month-over-Month (MoM) revenue growth with prior month comparison


WITH monthly_sales AS (
    SELECT 
        TO_CHAR(o.date, 'YYYY-MM') AS order_month,
        SUM(od.quantity * p.price) AS total_revenue
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    GROUP BY TO_CHAR(o.date, 'YYYY-MM')
)
SELECT 
    order_month,
    ROUND(total_revenue::NUMERIC, 2) AS current_month_revenue,
    ROUND(LAG(total_revenue) OVER (ORDER BY order_month)::NUMERIC, 2) AS prior_month_revenue,
    ROUND(
        ((total_revenue - LAG(total_revenue) OVER (ORDER BY order_month)) / 
         LAG(total_revenue) OVER (ORDER BY order_month) * 100)::NUMERIC, 
        2
    ) AS mom_growth_pct
FROM monthly_sales
ORDER BY order_month;

-- 6. Running Total of Orders per Day vs. Daily Average

WITH daily_counts AS (
    SELECT 
        date,
        COUNT(order_id) AS orders_today
    FROM orders
    GROUP BY date
)
SELECT 
    date,
    orders_today,
    SUM(orders_today) OVER (ORDER BY date) AS running_total_orders,
    ROUND(AVG(orders_today) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS expanding_avg_orders_per_day
FROM daily_counts
ORDER BY date;

-- 7. Percentage Rank and Cumulative Distribution of Order Totals

WITH order_totals AS (
    SELECT 
        o.order_id,
        ROUND(SUM(od.quantity * p.price)::NUMERIC, 2) AS total_spend
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    GROUP BY o.order_id
)
SELECT 
    order_id,
    total_spend,
    ROUND(PERCENT_RANK() OVER (ORDER BY total_spend)::NUMERIC, 4) AS percent_rank,
    ROUND(CUME_DIST() OVER (ORDER BY total_spend)::NUMERIC, 4) AS cume_dist
FROM order_totals
ORDER BY total_spend DESC;

-- 8. Unnesting Ingredients to Calculate Revenue Contribution per Raw Material

WITH exploded_ingredients AS (
    SELECT 
        TRIM(ingredient) AS ingredient_name,
        od.quantity * p.price AS line_revenue
    FROM order_details od
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id,
    LATERAL UNNEST(STRING_TO_ARRAY(pt.ingredients, ',')) AS ingredient
)
SELECT 
    ingredient_name,
    COUNT(*) AS times_featured_in_sold_line,
    ROUND(SUM(line_revenue)::NUMERIC, 2) AS total_revenue_impact,
    ROUND(
        (SUM(line_revenue) / SUM(SUM(line_revenue)) OVER () * 100)::NUMERIC, 
        2
    ) AS ingredient_revenue_share_pct
FROM exploded_ingredients
GROUP BY ingredient_name
ORDER BY total_revenue_impact DESC
LIMIT 10;


-- 9. First vs. Last Order Time and Active Operating Span per Date

SELECT 
    date,
    MIN(time) AS store_open_first_order,
    MAX(time) AS store_close_last_order,
    MAX(time) - MIN(time) AS daily_operational_hours,
    COUNT(order_id) AS total_orders
FROM orders
GROUP BY date
ORDER BY daily_operational_hours DESC
LIMIT 10;


-- 10. Customer Order Gap Analysis (Time Between Consecutive Orders)

WITH peak_day_orders AS (
    SELECT 
        order_id,
        date,
        time,
        LAG(time) OVER (ORDER BY time) AS previous_order_time
    FROM orders
    WHERE date = '2015-11-27' -- Day after Thanksgiving / Black Friday
)
SELECT 
    order_id,
    time,
    previous_order_time,
    EXTRACT(EPOCH FROM (time - previous_order_time)) AS seconds_since_prior_order
FROM peak_day_orders
WHERE previous_order_time IS NOT NULL
ORDER BY seconds_since_prior_order ASC
LIMIT 15;

-- 11. Pivot Matrix: Total Revenue by Pizza Category Across All 4 Quarters

SELECT 
    pt.category,
    ROUND(SUM(CASE WHEN EXTRACT(QUARTER FROM o.date) = 1 THEN od.quantity * p.price ELSE 0 END)::NUMERIC, 2) AS q1_revenue,
    ROUND(SUM(CASE WHEN EXTRACT(QUARTER FROM o.date) = 2 THEN od.quantity * p.price ELSE 0 END)::NUMERIC, 2) AS q2_revenue,
    ROUND(SUM(CASE WHEN EXTRACT(QUARTER FROM o.date) = 3 THEN od.quantity * p.price ELSE 0 END)::NUMERIC, 2) AS q3_revenue,
    ROUND(SUM(CASE WHEN EXTRACT(QUARTER FROM o.date) = 4 THEN od.quantity * p.price ELSE 0 END)::NUMERIC, 2) AS q4_revenue,
    ROUND(SUM(od.quantity * p.price)::NUMERIC, 2) AS full_year_revenue
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
JOIN pizzas p ON od.pizza_id = p.pizza_id
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.category
ORDER BY full_year_revenue DESC;

-- 12. Order spend distribution by customer quartiles using NTILE(4)

WITH order_baskets AS (
    SELECT 
        o.order_id,
        SUM(od.quantity * p.price) AS order_total
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    GROUP BY o.order_id
),
quartiles AS (
    SELECT 
        order_id,
        order_total,
        NTILE(4) OVER (ORDER BY order_total) AS quartile
    FROM order_baskets
)
SELECT 
    quartile,
    COUNT(order_id) AS total_orders,
    ROUND(MIN(order_total)::NUMERIC, 2) AS min_spend,
    ROUND(MAX(order_total)::NUMERIC, 2) AS max_spend,
    ROUND(AVG(order_total)::NUMERIC, 2) AS avg_spend,
    ROUND(SUM(order_total)::NUMERIC, 2) AS tier_revenue,
    ROUND(
        (SUM(order_total) / SUM(SUM(order_total)) OVER () * 100)::NUMERIC, 
        2
    ) AS revenue_share_pct
FROM quartiles
GROUP BY quartile
ORDER BY quartile;

-- 13. Identify pizzas that have NEVER been ordered (Unsold Inventory / Anti-Join)

SELECT 
    p.pizza_id,
    pt.name,
    p.size,
    p.price
FROM pizzas p
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
LEFT JOIN order_details od ON p.pizza_id = od.pizza_id
WHERE od.pizza_id IS NULL;

-- 14. Multi-Dimensional Rollup: Subtotals and Grand Totals across Category and Size

SELECT 
    COALESCE(pt.category) AS category,
    COALESCE(p.size) AS size,
    SUM(od.quantity) AS total_units_sold,
    ROUND(SUM(od.quantity * p.price)::NUMERIC, 2) AS total_revenue
FROM pizza_types pt
JOIN pizzas p ON pt.pizza_type_id = p.pizza_type_id
JOIN order_details od ON p.pizza_id = od.pizza_id
GROUP BY ROLLUP(pt.category, p.size)
ORDER BY pt.category NULLS LAST, p.size NULLS LAST;

-- 15. Categorize Order Basket Sizes into Custom Tiers (Small, Medium, Large, Party)

SELECT 
    basket_tier,
    COUNT(order_id) AS total_orders,
    ROUND((COUNT(order_id)::NUMERIC / SUM(COUNT(order_id)) OVER () * 100)::NUMERIC, 2) AS pct_of_orders,
    ROUND(SUM(order_revenue)::NUMERIC, 2) AS total_revenue
FROM (
    SELECT 
        o.order_id,
        SUM(od.quantity) AS total_pizzas,
        SUM(od.quantity * p.price) AS order_revenue,
        CASE 
            WHEN SUM(od.quantity) = 1 THEN '1 Pizza (Individual)'
            WHEN SUM(od.quantity) = 2 THEN '2 Pizzas (Couple)'
            WHEN SUM(od.quantity) BETWEEN 3 AND 4 THEN '3-4 Pizzas (Family)'
            ELSE '5+ Pizzas (Party/Event)'
        END AS basket_tier
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    GROUP BY o.order_id
) AS categorized_baskets
GROUP BY basket_tier
ORDER BY total_revenue DESC;


-- 16  Recursive CTE: Generate a 2015 Calendar Dimension and Identify Zero-Sales Dates

WITH RECURSIVE full_year_dates AS (
    SELECT '2015-01-01'::DATE AS cal_date
    UNION ALL
    SELECT (cal_date + INTERVAL '1 day')::DATE
    FROM full_year_dates
    WHERE cal_date < '2015-12-31'::DATE
)
SELECT 
    d.cal_date,
    COALESCE(COUNT(DISTINCT o.order_id), 0) AS total_orders,
    COALESCE(ROUND(SUM(od.quantity * p.price)::NUMERIC, 2), 0.00) AS total_revenue
FROM full_year_dates d
LEFT JOIN orders o ON d.cal_date = o.date
LEFT JOIN order_details od ON o.order_id = od.order_id
LEFT JOIN pizzas p ON od.pizza_id = p.pizza_id
GROUP BY d.cal_date
HAVING COUNT(DISTINCT o.order_id) = 0
ORDER BY d.cal_date;


-- 17. Find the Single Most Popular Day of the Week (Monday to Sunday)

SELECT 
    TO_CHAR(date, 'Day') AS day_of_week,
    EXTRACT(DOW FROM date) AS day_index,
    SUM(daily_order_count) AS total_orders,
    ROUND(AVG(daily_order_count), 2) AS avg_orders_per_day
FROM (
    SELECT 
        date,
        COUNT(order_id) AS daily_order_count
    FROM orders
    GROUP BY date
) sub
GROUP BY TO_CHAR(date, 'Day'), EXTRACT(DOW FROM date)
ORDER BY total_orders DESC;
