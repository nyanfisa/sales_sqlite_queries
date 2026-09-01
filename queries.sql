--Выбрать 20 самых дорогих товаров(подзапросы)
SELECT 
    product_id, 
    unit_price, 
    p.name
FROM sale_items si
JOIN products p 
ON si.product_id = p.id
WHERE unit_price > 
    (SELECT AVG(unit_price) AS avg_price
    FROM sale_items)
ORDER BY unit_price DESC
LIMIT 20;

--ВЫбрать самые прибыльные категории(join)
SELECT 
    c.name AS category_name,
    ROUND(SUM(quantity * unit_price - discount_amount), 2) AS total_revenue
FROM sale_items si
INNER JOIN products p
    ON si.product_id = p.id
INNER JOIN categories c 
    ON p.category_id = c.id 
GROUP BY c.id
ORDER BY total_revenue  DESC;

--Показать динамику начисления баллов за покупки(join)
SELECT 
    c.full_name AS customer_name,
    s.id AS sale_id, sale_datetime,
    points_delta, 
    lt.name AS tier_name
FROM sales s
INNER JOIN customers c
    ON s.customer_id = c.id
INNER JOIN loyalty_point_transactions lpt
    ON lpt.sale_id = s.id
INNER JOIN loyalty_accounts la
    ON c.id = la.customer_id
INNER JOIN loyalty_tiers lt
    ON lt.id = la.tier_id            
ORDER BY points_delta  DESC; 

--Отобразить количество работающих магазинов по каждому городу, сколько из них совершали продажи и какова доля работающих магазинов
--Фильтрация и группировка данных
SELECT 
    s.city,
    COUNT(DISTINCT s.id) AS total_active_stores,
    COUNT(DISTINCT sl.store_id) AS stores_with_sales,
    COUNT(DISTINCT sl.store_id) * 1.0 / COUNT(DISTINCT s.id) AS activity_ratio
FROM stores s
LEFT JOIN sales sl ON s.id = sl.store_id
WHERE s.is_active = 1
GROUP BY s.city
ORDER BY activity_ratio DESC;

--Показать клентов с наибольшим количеством покупок (join)
SELECT 
    c.full_name AS customer_name,
    COUNT(DISTINCT(s.id)) AS sales_count,
    ROUND(SUM(quantity * unit_price - discount_amount), 2) AS total_spent
FROM sales s 
JOIN sale_items si
    ON s.id = si.sale_id
JOIN customers c
    ON  s.customer_id = c.id    
GROUP BY c.id, c.full_name
ORDER BY sales_count  DESC;

--Найти самые дорогие покупки для каждого клиента (подзапросы)
SELECT 
    s.id AS id, 
    s.customer_id as customer_id, 
    si.sale_total
FROM sales s
JOIN (
    SELECT 
        sale_id, 
        ROUND(SUM(quantity * unit_price - discount_amount), 2) as sale_total
    FROM sale_items 
    GROUP BY sale_id
    ) si ON s.id = si.sale_id
WHERE si.sale_total = (
    SELECT ROUND(MAX(si2.sale_total), 2)
    FROM (
        SELECT 
            sale_id, 
            ROUND(SUM(quantity * unit_price - discount_amount), 2) as sale_total
        FROM sale_items
        GROUP BY sale_id 
    ) si2
    JOIN sales s2 ON si2.sale_id = s2.id
    WHERE s2.customer_id = s.customer_id  
    )     
ORDER BY sale_id;

--CTE
--Определить 5 клиентов с наибольшей общей суммой покупок.
WITH total_purchases AS(
    SELECT 
        customer_id, 
        ROUND(SUM(quantity*unit_price-discount_amount)) AS total_spent
    FROM sales s 
    JOIN sale_items si ON s.id = si.sale_id
    GROUP BY customer_id
)    
SELECT 
    tp.customer_id,
    c.full_name, 
    tp.total_spent
FROM total_purchases tp
JOIN customers c ON tp.customer_id = c.id      
ORDER BY total_spent DESC
LIMIT 5;

--Найти магазины, у которых суммарная выручка выше средней по всем магазинам.
WITH store_sales AS (
    SELECT 
        store_id, 
        ROUND(SUM(unit_price * quantity - discount_amount)) AS total_revenue 
    FROM sales s 
    JOIN sale_items si ON s.id = si.sale_id
    GROUP BY store_id),

avg_sales AS (
    SELECT AVG(total_revenue) AS avg_sale
    FROM store_sales)     
SELECT 
    ss.store_id,
    s.name AS store_name, 
    ss.total_revenue 
FROM store_sales ss 
JOIN stores s ON ss.store_id = s.id     
WHERE total_revenue > (
    SELECT avg_sale
    FROM avg_sales
);    

--Найдите клиентов, у которых количество больше 5 покупок.
WITH total_purchases AS (
    SELECT customer_id, COUNT(*) as sales_count
    FROM sales
    GROUP BY customer_id
    HAVING sales_count > 5
)
SELECT 
    customer_id,
    c.full_name,
    sales_count
FROM total_purchases tp
JOIN customers c
ON tp.customer_id = c.id    
ORDER BY sales_count DESC;

--Для каждого аккаунта лояльности сравнить текущий баланс баллов и сумму всех транзакций по этому аккаунту.
WITH points_sum AS (
    SELECT account_id, SUM(points_delta) AS tx_sum 
    FROM loyalty_point_transactions lpt
    GROUP BY account_id
)    
SELECT 
    la.id AS account_id,
    la.points_balance,
    ps.tx_sum,
    ps.tx_sum - la.points_balance AS difference 
FROM loyalty_accounts la
JOIN points_sum ps
ON la.id = ps.account_id;  

--Определить, в каком магазине каждый клиент совершил первую покупку
WITH first_purchase AS (
    SELECT 
        customer_id,
        MIN(sale_datetime) AS first_sale_datetime
    FROM sales
    GROUP BY customer_id
)
SELECT 
    fp.customer_id,
    fp.first_sale_datetime,
    s.store_id
FROM first_purchase fp
JOIN sales s ON s.customer_id = fp.customer_id 
            AND s.sale_datetime = fp.first_sale_datetime;


--Показать клиентов, которые совершали покупки только в одном городе
SELECT 
    customer_id,
    COUNT(DISTINCT(city)) as count_city
FROM sales s
JOIN stores st
ON s.store_id = st.id 
GROUP BY customer_id   
HAVING count_city = 1;

--какие купоны были выданы, но не применены ни в одном чеке.
WITH issued_coupons AS (
    SELECT id, code
    FROM coupons
    WHERE status = 'ISSUED'
)   
SELECT 
    iss.id AS coupon_id,
    code
FROM issued_coupons iss
WHERE iss.id NOT IN (SELECT coupon_id FROM sale_coupons);

--то же, но короче
SELECT 
    id AS coupon_id,
    code
FROM coupons
WHERE status = 'ISSUED'
  AND id NOT IN (SELECT coupon_id FROM sale_coupons);

-- Вывести накопительную сумму продаж по каждому магазину в порядке времени
WITH sale_totals AS (
    SELECT 
        s.store_id,
        s.sale_datetime,
        s.id AS sale_id,
        SUM(si.quantity * si.unit_price - si.discount_amount) AS sale_amount
    FROM sales s
    JOIN sale_items si ON s.id = si.sale_id
    GROUP BY s.id, s.store_id, s.sale_datetime
)
SELECT 
    store_id,
    sale_datetime,
    ROUND(sale_amount, 2) AS sale_amount,
    ROUND(SUM(sale_amount) OVER(PARTITION BY store_id ORDER BY sale_datetime, sale_id), 2) AS running_total_per_store
FROM sale_totals
ORDER BY store_id, sale_datetime;

--Вывести для каждой продажи её метрику отклонения от цены среднего чека по клиенту
WITH sale_sum AS (
    SELECT 
        customer_id,
        s.id AS sale_id,
        SUM(quantity * unit_price - discount_amount) AS sale_amount 
    FROM sales s 
    JOIN sale_items si
    ON s.id = si.sale_id
    GROUP BY sale_id
)
SELECT   
    customer_id,
    sale_id,     
    ROUND(sale_amount,2) AS sale_amount,
    ROUND(AVG(sale_amount) OVER (PARTITION BY customer_id),2) AS avg_amount_per_customer,
    ROUND(sale_amount - AVG(sale_amount) OVER (PARTITION BY customer_id),2) AS diff_from_avg
FROM sale_sum
ORDER BY customer_id, sale_amount DESC;

--Вывести рейтинг товара по убыванию цены внутри своей категории
SELECT 
    p.name AS product_name,
    category_id,
    base_price,
    ROW_NUMBER() OVER (
        PARTITION BY category_id
        ORDER BY base_price DESC
    ) AS price_rank_in_category 
FROM products p
ORDER BY category_id, price_rank_in_category;    

--Вывести накопительный баланс по аккаунту в системе лояльности
SELECT 
    account_id, 
    tx_datetime,
    points_delta,
    SUM(points_delta) OVER (PARTITION BY account_id ORDER BY tx_datetime) AS running_points_balance 
FROM loyalty_point_transactions
ORDER BY account_id, tx_datetime;

--Вывести клиентский оборот
WITH sale_total AS (
    SELECT 
        customer_id,
        s.id AS sale_id,
        SUM(quantity * unit_price - discount_amount) AS sale_amount
    FROM sales s
    JOIN sale_items si
    ON s.id = si.sale_id
    GROUP BY sale_id
)
SELECT     
    customer_id,
    sale_id,
    sale_amount, --сумма продажи по всем позициям
    SUM(sale_amount) OVER(PARTITION BY customer_id) AS customer_total_amount, --общий оборот клиента (сумма всех продаж по всем позициям)
    ROUND(sale_amount / SUM(sale_amount) OVER(PARTITION BY customer_id) * 100, 2) AS sale_share_percent --доля текущей продажи в обороте клиента 
FROM sale_total
ORDER BY customer_id, sale_amount DESC;

--Показать рейтинг магазинов по выручке
    --сумма одной продажи
WITH sales_total AS (    
    SELECT
        s.id AS sale_id,
        SUM(quantity * unit_price - discount_amount) AS sale_total 
    FROM sales s
    JOIN sale_items si
    ON s.id = si.sale_id
    GROUP BY sale_id
),
    --общая сумма продаж для каждого магазина
store_sales_total AS (
    SELECT 
        store_id,
        SUM(sale_total) AS total_store_amount
    FROM sales_total st
    JOIN sales s
    ON st.sale_id = s.id
    GROUP BY store_id
)  
SELECT 
    store_id,
    ROUND(total_store_amount,2) AS total_store_amount,
    ROW_NUMBER() OVER(ORDER BY total_store_amount DESC) AS store_rank_by_revenue
FROM store_sales_total
ORDER BY store_rank_by_revenue;     

--Определить рейтинг продаж по сумме чека для каждого магазина
SELECT 
    store_id, 
    sale_id, 
    ROUND(SUM(quantity * unit_price - discount_amount), 2) AS sale_amount,
    DENSE_RANK() OVER(
        PARTITION BY store_id
        ORDER BY ROUND(SUM(quantity * unit_price - discount_amount), 2) DESC) AS rank_in_store 
FROM sales s
JOIN sale_items si
ON s.id = si.sale_id      
GROUP BY sale_id
ORDER BY store_id, rank_in_store;

--Вывести порядковый номер покупок каждого клиента 
SELECT 
    customer_id, 
    sales.id AS sale_id, 
    sale_datetime,
    ROW_NUMBER() OVER(
    PARTITION BY customer_id
        ORDER BY sale_datetime) AS purchase_number
FROM sales
ORDER BY customer_id,  sale_datetime;   

--Определить для каждого товара его позицию по цене внутри категории.
SELECT 
    products.id AS product_id, 
    category_id,
    base_price,
    DENSE_RANK() OVER(
        PARTITION BY category_id
        ORDER BY base_price DESC) AS dense_price_rank 
FROM products
ORDER BY category_id, dense_price_rank;
           
--Для каждого клиента необходимо определить степень изменения суммы покупки относительно предыдущей.
WITH customer_sales AS (
    SELECT 
        customer_id,
        sale_id,
        sale_datetime,
        ROUND(SUM(quantity * unit_price - discount_amount),2) AS sale_amount
    FROM sales s
    JOIN sale_items si
    ON s.id = si.sale_id
    GROUP BY sale_id
),
prev_date_numbers AS (
    SELECT 
        customer_id,
        sale_id,
        sale_amount,
        LAG(sale_amount) OVER (
            PARTITION BY customer_id
            ORDER BY sale_datetime) AS previous_sale_amount 
    FROM customer_sales
)
SELECT    
    customer_id, 
    sale_id, 
    sale_amount,
    previous_sale_amount,
    sale_amount - previous_sale_amount AS change_from_previous 
FROM prev_date_numbers;   

--Для каждой продажи определить дату следующей покупки клиента 
WITH customer_sale_dates AS (
    SELECT 
        customer_id,
        s.id AS sale_id,
        sale_datetime,
        LEAD(sale_datetime) OVER (
            PARTITION BY customer_id
            ORDER BY sale_datetime
            ) AS next_sale_datetime
     FROM sales s
)
SELECT   
    customer_id,
    sale_id,
    sale_datetime,
    next_sale_datetime,
    ROUND(JULIANDAY(next_sale_datetime) - JULIANDAY(sale_datetime)) AS days_to_next_purchase 
FROM customer_sale_dates  
ORDER BY customer_id, sale_datetime;      
                
--Для каждого города определить рейтинг клиентов по суммарной выручке.
WITH customer_city_totals AS (
    SELECT 
        s.customer_id,
        st.city,
        ROUND(SUM(si.quantity * si.unit_price - si.discount_amount), 2) AS total_revenue
    FROM sales s
    JOIN sale_items si ON s.id = si.sale_id
    JOIN stores st ON s.store_id = st.id
    GROUP BY s.customer_id, st.city
)
SELECT 
    city,
    customer_id,
    total_revenue,
    ROW_NUMBER() OVER (
        PARTITION BY city 
        ORDER BY total_revenue DESC
    ) AS city_rank
FROM customer_city_totals
ORDER BY city, city_rank;

--Найти для каждого клиента его самую крупную покупку.
WITH total_sales AS (
    SELECT
        customer_id,
        sale_id,
        ROUND(SUM(quantity * unit_price - discount_amount), 2) AS sale_amount 
    FROM sales s
    JOIN sale_items si ON s.id = si.sale_id
    GROUP BY sale_id, customer_id 
),
ranked AS (
    SELECT 
        customer_id,
        sale_id,
        sale_amount,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY sale_amount DESC
        ) AS rank_within_customer 
    FROM total_sales
)
SELECT 
    customer_id,
    sale_id,
    sale_amount, 
    rank_within_customer
FROM ranked 
WHERE rank_within_customer = 1;       