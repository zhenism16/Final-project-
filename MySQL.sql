#1.
WITH monthly_stats AS (
    SELECT 
        ID_client,
        DATE_FORMAT(date_new, '%Y-%m') AS month_yr,
        COUNT(DISTINCT Id_check) AS checks_in_month,
        SUM(Sum_payment) AS monthly_sum,
        COUNT(*) AS operations_in_month
    FROM transactions
    WHERE date_new >= '2015-06-01' AND date_new < '2016-06-01'
    GROUP BY ID_client, month_yr
),
loyal_clients AS (
    SELECT 
        ID_client,
        SUM(operations_in_month) AS total_operations,
        SUM(monthly_sum) AS total_amount,
        COUNT(DISTINCT month_yr) AS months_active
    FROM monthly_stats
    GROUP BY ID_client
    HAVING months_active = 12
)
SELECT 
    lc.ID_client,
    lc.total_operations,
    (lc.total_amount / lc.total_operations) AS avg_check,
    (lc.total_amount / 12) AS avg_monthly_amount      
FROM loyal_clients lc
ORDER BY lc.total_amount DESC;

#2. 
WITH normalized_data AS (
    SELECT 
        CASE 
            WHEN date_new LIKE '201%' THEN STR_TO_DATE(date_new, '%Y-%m-%d')
            ELSE DATE_ADD('1899-12-30', INTERVAL CAST(date_new AS UNSIGNED) DAY)
        END AS clean_date,
        Id_check,
        ID_client,
        Sum_payment
    FROM transactions
    WHERE 
        (date_new LIKE '201%' AND STR_TO_DATE(date_new, '%Y-%m-%d') BETWEEN '2015-06-01' AND '2016-06-01')
        OR (date_new NOT LIKE '201%' AND DATE_ADD('1899-12-30', INTERVAL CAST(date_new AS UNSIGNED) DAY) 
        BETWEEN '2015-06-01' AND '2016-06-01')
),
monthly_stats AS (
    SELECT 
        DATE_FORMAT(clean_date, '%Y-%m') AS month_yr,
        SUM(Sum_payment) AS m_sum,
        COUNT(Id_check) AS m_ops,
        COUNT(DISTINCT ID_client) AS m_clients
    FROM normalized_data
    GROUP BY month_yr
),
yearly_totals AS (
    SELECT SUM(m_sum) as y_sum, SUM(m_ops) as y_ops FROM monthly_stats
)
SELECT 
    m.month_yr,
    (m.m_sum / m.m_ops) AS avg_check_monthly,        
    m.m_ops AS ops_count,                            
    m.m_clients AS unique_clients,                   
    (m.m_ops / y.y_ops) * 100 AS ops_share_pct,      
    (m.m_sum / y.y_sum) * 100 AS sum_share_pct       
FROM monthly_stats m, yearly_totals y
ORDER BY m.month_yr;

WITH gender_data AS (
    SELECT 
        DATE_FORMAT(CASE 
            WHEN t.date_new LIKE '201%' THEN STR_TO_DATE(t.date_new, '%Y-%m-%d')
            ELSE DATE_ADD('1899-12-30', INTERVAL CAST(t.date_new AS UNSIGNED) DAY)
        END, '%Y-%m') AS month_yr,
        t.ID_client,
        t.Sum_payment,
        IFNULL(NULLIF(c.Gender, ''), 'NA') AS gender_clean
    FROM transactions t
    LEFT JOIN customers c ON t.ID_client = c.Id_client
)
SELECT 
    month_yr,
    COUNT(DISTINCT CASE WHEN gender_clean = 'M' THEN ID_client END) * 100.0 / COUNT(DISTINCT ID_client) AS M_client_pct,
    COUNT(DISTINCT CASE WHEN gender_clean = 'F' THEN ID_client END) * 100.0 / COUNT(DISTINCT ID_client) AS F_client_pct,
    COUNT(DISTINCT CASE WHEN gender_clean = 'NA' THEN ID_client END) * 100.0 / COUNT(DISTINCT ID_client) AS NA_client_pct,
    SUM(CASE WHEN gender_clean = 'M' THEN Sum_payment ELSE 0 END) * 100.0 / SUM(Sum_payment) AS M_spend_share_pct,
    SUM(CASE WHEN gender_clean = 'F' THEN Sum_payment ELSE 0 END) * 100.0 / SUM(Sum_payment) AS F_spend_share_pct,
    SUM(CASE WHEN gender_clean = 'NA' THEN Sum_payment ELSE 0 END) * 100.0 / SUM(Sum_payment) AS NA_spend_share_pct
FROM gender_data
GROUP BY month_yr
ORDER BY month_yr;

#3.
SELECT 
    CASE 
        WHEN c.Age IS NULL THEN 'Unknown'
        WHEN c.Age BETWEEN 0 AND 9 THEN '0-9'
        WHEN c.Age BETWEEN 10 AND 19 THEN '10-19'
        WHEN c.Age BETWEEN 20 AND 29 THEN '20-29'
        WHEN c.Age BETWEEN 30 AND 39 THEN '30-39'
        WHEN c.Age BETWEEN 40 AND 49 THEN '40-49'
        WHEN c.Age BETWEEN 50 AND 59 THEN '50-59'
        WHEN c.Age BETWEEN 60 AND 69 THEN '60-69'
        ELSE '70+'
    END AS age_group,
    SUM(t.Sum_payment) AS total_spent,
    COUNT(t.Id_check) AS total_operations
FROM transactions t
LEFT JOIN customers c ON t.ID_client = c.Id_client
GROUP BY age_group
ORDER BY age_group;

WITH quarterly_raw AS (
    SELECT 
        YEAR(CASE 
            WHEN t.date_new LIKE '201%' THEN STR_TO_DATE(t.date_new, '%Y-%m-%d')
            ELSE DATE_ADD('1899-12-30', INTERVAL CAST(t.date_new AS UNSIGNED) DAY)
        END) AS yr,
        QUARTER(CASE 
            WHEN t.date_new LIKE '201%' THEN STR_TO_DATE(t.date_new, '%Y-%m-%d')
            ELSE DATE_ADD('1899-12-30', INTERVAL CAST(t.date_new AS UNSIGNED) DAY)
        END) AS qrt,
        CASE 
            WHEN c.Age IS NULL THEN 'Unknown'
            ELSE CONCAT(FLOOR(c.Age / 10) * 10, '-', (FLOOR(c.Age / 10) * 10) + 9)
        END AS age_group,
        t.Sum_payment
    FROM transactions t
    LEFT JOIN customers c ON t.ID_client = c.Id_client
),
quarterly_stats AS (
    SELECT 
        yr, qrt, age_group,
        SUM(Sum_payment) AS q_sum,
        COUNT(*) AS q_ops,
        AVG(Sum_payment) AS q_avg_payment
    FROM quarterly_raw
    GROUP BY yr, qrt, age_group
),
quarterly_totals AS (
    SELECT yr, qrt, SUM(q_sum) AS total_q_sum, SUM(q_ops) AS total_q_ops
    FROM quarterly_stats
    GROUP BY yr, qrt
)
SELECT 
    s.yr, s.qrt, s.age_group,
    s.q_avg_payment AS avg_check,                      
    (s.q_sum / t.total_q_sum) * 100 AS sum_percent,    
    (s.q_ops / t.total_q_ops) * 100 AS ops_percent     
FROM quarterly_stats s
JOIN quarterly_totals t ON s.yr = t.yr AND s.qrt = t.qrt
ORDER BY s.yr, s.qrt, s.age_group;