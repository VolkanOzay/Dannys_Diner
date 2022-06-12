CREATE SCHEMA dannys_diner;
SET search_path = dannys_diner;

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
 

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(5),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
  

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');

-- Q1 -- 1. What is the total amount each customer spent at the restaurant?

SELECT
	customer_id, sum(price) amount
FROM dannys_diner.sales s
JOIN dannys_diner.menu m
ON s.product_id = m.product_id
GROUP BY customer_id
ORDER BY customer_id;

-- Q2 -- 2. How many days has each customer visited the restaurant?

SELECT
	customer_id,
    COUNT(DISTINCT(order_date)) number_of_visits
FROM dannys_diner.sales
GROUP BY customer_id
ORDER BY customer_id;

-- Q3 -- 3. What was the first item from the menu purchased by each customer?

SELECT
	DISTINCT(customer_id),
    product_name
FROM dannys_diner.sales s
JOIN dannys_diner.menu m
ON s.product_id = m.product_id
WHERE s.order_date = ANY
	(SELECT
     	MIN(order_date)
     FROM dannys_diner.sales
     GROUP BY customer_id)
ORDER BY customer_id;

-- Q4-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT
	product_name,
	COUNT(product_name) AS order_count	
FROM dannys_diner.sales s
JOIN dannys_diner.menu m
ON s.product_id = m.product_id
GROUP BY product_name
ORDER BY order_count DESC
LIMIT 1;

-- Q5 -- 5. Which item was the most popular for each customer?

WITH order_ranks AS(
  SELECT
      s.customer_id,
      m.product_name,
      COUNT(s.product_id) as order_count,
  	  DENSE_RANK() OVER(PARTITION BY s.customer_id
                        ORDER BY COUNT(s.product_id) DESC) as ranks
  FROM dannys_diner.menu m
  JOIN dannys_diner.sales s
  ON m.product_id = s.product_id
  GROUP BY s.customer_id, s.product_id, m.product_name
  ORDER BY order_count DESC)
  
SELECT
	customer_id,
    product_name,
    order_count
FROM order_ranks
WHERE ranks = 1
ORDER BY customer_id;
  
-- Q6 -- 6. Which item was purchased first by the customer after they became a member?

WITH orders AS(
  SELECT
  	s.customer_id,
  	s.order_date,
  	m.product_name,
    DENSE_RANK() OVER(PARTITION BY s.customer_id
                      ORDER BY s.order_date) AS order_rank
  FROM dannys_diner.sales s
  JOIN dannys_diner.menu m
  ON s.product_id = m.product_id
  JOIN dannys_diner.members mb
  ON mb.customer_id = s.customer_id
  WHERE mb.join_date <= s.order_date
  ORDER BY order_date)
 
SELECT
	customer_id,
    order_date,
    product_name
FROM orders o
WHERE order_rank = ANY(SELECT
                       	MIN(order_rank)
                       FROM orders
                       GROUP BY customer_id)
ORDER BY customer_id;
 
 -- Q7 -- 7. Which item was purchased just before the customer became a member?
 
WITH orders AS(
   SELECT
   	s.customer_id,
   	s.order_date,
   	m.product_name,
    DENSE_RANK() OVER(PARTITION BY s.customer_id
                      ORDER BY s.order_date DESC) AS order_rank
   FROM dannys_diner.sales s
   JOIN dannys_diner.menu m
   ON s.product_id = m.product_id
   JOIN dannys_diner.members mb
   ON s.customer_id = mb.customer_id
   WHERE s.order_date < mb.join_date
   ORDER BY s.order_date)
 
SELECT
 	customer_id,
    product_name,
    order_date
FROM orders
WHERE order_rank = 1
ORDER BY customer_id;
 
-- Q8 -- 8. What is the total items and amount spent for each member before they became a member?
 
WITH orders AS(
   SELECT
   	s.customer_id,
   	s.order_date,
   	s.product_id,
   	m.price
   FROM dannys_diner.sales s
   JOIN dannys_diner.menu m
   ON s.product_id = m.product_id
   JOIN dannys_diner.members mb
   ON s.customer_id = mb.customer_id
   WHERE s.order_date < mb.join_date
   ORDER BY customer_id, order_date)
   
SELECT
	customer_id,
    COUNT(product_id),
    SUM(price)
FROM orders
GROUP BY customer_id
ORDER BY customer_id;

-- Q9 -- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH orders AS(
  SELECT
  	s.customer_id,
  	m.product_name,
  	CASE
  	WHEN m.product_name != 'sushi' THEN m.price*10
  	WHEN m.product_name = 'sushi' THEN m.price*20
  	END AS customer_point
  FROM dannys_diner.sales s
  JOIN dannys_diner.menu m
  ON s.product_id = m.product_id)

SELECT
	customer_id,
    SUM(customer_point) AS customer_point
FROM orders
GROUP BY customer_id
ORDER BY customer_id;

-- Q10 -- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

WITH orders AS(
  SELECT
  	s.customer_id,
  	m.product_name,
  	CASE
  	WHEN m.product_name != 'sushi'
  		AND ((s.order_date - mb.join_date) > 7
             OR (s.order_date - mb.join_date) < 0) THEN m.price*10
  	WHEN m.product_name != 'sushi'
  		AND ((s.order_date - mb.join_date) <= 7
             OR (s.order_date - mb.join_date) >= 0) THEN m.price*20
  	WHEN m.product_name = 'sushi' 
  		AND ((s.order_date - mb.join_date) > 7
             OR (s.order_date - mb.join_date) < 0) THEN m.price*20
	WHEN m.product_name = 'sushi' 
  		AND ((s.order_date - mb.join_date) <= 7
             OR (s.order_date - mb.join_date) >= 0) THEN m.price*40
  	END AS customer_point
  FROM dannys_diner.sales s
  JOIN dannys_diner.menu m
  ON s.product_id = m.product_id
  JOIN dannys_diner.members mb
  ON s.customer_id = mb.customer_id
  WHERE EXTRACT(MONTH FROM s.order_date) = 1)
  
SELECT
 	customer_id,
   SUM(customer_point) AS customer_point
FROM orders
GROUP BY customer_id
ORDER BY customer_id;