select *
FROM `bigquery-public-data.ml_datasets.credit_card_default`;

-- Создание таблиц для работы
CREATE SCHEMA IF NOT EXISTS `exam-499409.exam`
OPTIONS(location='US');

-- Создание представления для работы
CREATE OR REPLACE VIEW `exam-499409.exam.credit_data` AS
SELECT
  -- ЦЕЛЕВАЯ ПЕРЕМЕННАЯ
  limit_balance AS credit_limit,
  
  -- ДЕМОГРАФИЧЕСКИЕ ПРИЗНАКИ
  sex,
  education_level,
  marital_status,
  age,
  
  -- ИСТОРИЯ ПЛАТЕЖЕЙ
  pay_0,
  pay_2,
  pay_3,
  pay_4,
  pay_5,
  pay_6,
  
  -- СУММЫ СЧЕТОВ
  bill_amt_1,
  bill_amt_2,
  bill_amt_3,
  bill_amt_4,
  bill_amt_5,
  bill_amt_6,
  
  -- СУММЫ ОПЛАТ
  pay_amt_1,
  pay_amt_2,
  pay_amt_3,
  pay_amt_4,
  pay_amt_5,
  pay_amt_6,
  
  -- ФЛАГ ДЕФОЛТА
  default_payment_next_month,
  
  -- АГРЕГИРОВАННЫЕ ПРИЗНАКИ
  (pay_amt_1 + pay_amt_2 + pay_amt_3 + pay_amt_4 + pay_amt_5 + pay_amt_6) AS total_paid_6m,
  (bill_amt_1 + bill_amt_2 + bill_amt_3 + bill_amt_4 + bill_amt_5 + bill_amt_6) AS total_billed_6m

FROM `bigquery-public-data.ml_datasets.credit_card_default`
WHERE limit_balance IS NOT NULL;



-- АНАЛИЗ ДАННЫХ
SELECT 
  COUNT(*) AS total_rows,
  COUNTIF(credit_limit IS NULL) AS null_limit,
  COUNTIF(age IS NULL) AS null_age,
  COUNTIF(sex IS NULL) AS null_sex
FROM `exam-499409.exam.credit_data`;


--ТИПЫ ДАННЫХ
SELECT 
  column_name,
  data_type
FROM `exam-499409.exam.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'credit_data'
ORDER BY ordinal_position;


--некорректные типы, создаем новую таблицу с правильными типами данных
CREATE OR REPLACE TABLE `exam-499409.exam.credit_data_prepared` AS
SELECT
  -- Целевая переменная
  SAFE_CAST(limit_balance AS FLOAT64) AS credit_limit,
  
  -- кодировка категориальных признаков
  SAFE_CAST(sex AS INT64) AS sex,
  SAFE_CAST(education_level AS INT64) AS education_level,
  SAFE_CAST(marital_status AS INT64) AS marital_status,
  SAFE_CAST(age AS FLOAT64) AS age,
  
  -- Платежные статусы в FLOAT64 (были строки)
  SAFE_CAST(pay_0 AS FLOAT64) AS pay_0,
  SAFE_CAST(pay_2 AS FLOAT64) AS pay_2,
  SAFE_CAST(pay_3 AS FLOAT64) AS pay_3,
  SAFE_CAST(pay_4 AS FLOAT64) AS pay_4,
  SAFE_CAST(pay_5 AS FLOAT64) AS pay_5,
  SAFE_CAST(pay_6 AS FLOAT64) AS pay_6,
  
  -- Суммы счетов
  SAFE_CAST(bill_amt_1 AS FLOAT64) AS bill_amt_1,
  SAFE_CAST(bill_amt_2 AS FLOAT64) AS bill_amt_2,
  SAFE_CAST(bill_amt_3 AS FLOAT64) AS bill_amt_3,
  SAFE_CAST(bill_amt_4 AS FLOAT64) AS bill_amt_4,
  SAFE_CAST(bill_amt_5 AS FLOAT64) AS bill_amt_5,
  SAFE_CAST(bill_amt_6 AS FLOAT64) AS bill_amt_6,
  
  -- Суммы платежей
  SAFE_CAST(pay_amt_1 AS FLOAT64) AS pay_amt_1,
  SAFE_CAST(pay_amt_2 AS FLOAT64) AS pay_amt_2,
  SAFE_CAST(pay_amt_3 AS FLOAT64) AS pay_amt_3,
  SAFE_CAST(pay_amt_4 AS FLOAT64) AS pay_amt_4,
  SAFE_CAST(pay_amt_5 AS FLOAT64) AS pay_amt_5,
  SAFE_CAST(pay_amt_6 AS FLOAT64) AS pay_amt_6,
  
  -- Флаг дефолта преобразуем в INT64
  SAFE_CAST(default_payment_next_month AS INT64) AS default_payment_next_month,
  
  -- Агрегированные признаки
  SAFE_CAST(pay_amt_1 AS FLOAT64) + SAFE_CAST(pay_amt_2 AS FLOAT64) + 
  SAFE_CAST(pay_amt_3 AS FLOAT64) + SAFE_CAST(pay_amt_4 AS FLOAT64) + 
  SAFE_CAST(pay_amt_5 AS FLOAT64) + SAFE_CAST(pay_amt_6 AS FLOAT64) AS total_paid_6m,
  
  SAFE_CAST(bill_amt_1 AS FLOAT64) + SAFE_CAST(bill_amt_2 AS FLOAT64) + 
  SAFE_CAST(bill_amt_3 AS FLOAT64) + SAFE_CAST(bill_amt_4 AS FLOAT64) + 
  SAFE_CAST(bill_amt_5 AS FLOAT64) + SAFE_CAST(bill_amt_6 AS FLOAT64) AS total_billed_6m

FROM `bigquery-public-data.ml_datasets.credit_card_default`;

-- СТАТИСТИКА КРЕДИТНОГО ЛИМИТА
SELECT 
  COUNT(*) AS n,
  ROUND(MIN(credit_limit), 2) AS min,
  ROUND(APPROX_QUANTILES(credit_limit, 100)[OFFSET(25)], 2) AS q1,
  ROUND(APPROX_QUANTILES(credit_limit, 100)[OFFSET(50)], 2) AS median,
  ROUND(AVG(credit_limit), 2) AS mean,
  ROUND(APPROX_QUANTILES(credit_limit, 100)[OFFSET(75)], 2) AS q3,
  ROUND(MAX(credit_limit), 2) AS max,
  ROUND(STDDEV(credit_limit), 2) AS std_dev,
  ROUND(STDDEV(credit_limit) / AVG(credit_limit) * 100, 2) AS cv_percent
FROM `exam-499409.exam.credit_data_prepared`;



-- Распределение целевой переменной по децилям
SELECT 
  percentile,
  ROUND(MIN(credit_limit), 2) AS min_value,
  ROUND(MAX(credit_limit), 2) AS max_value,
  COUNT(*) AS count
FROM (
  SELECT 
    credit_limit,
    NTILE(10) OVER (ORDER BY credit_limit) AS percentile
  FROM `exam-499409.exam.credit_data_prepared`
)
GROUP BY percentile
ORDER BY percentile;



-- ПОЛ ЗАЕМЩИКОВ (распределение и средний лимит)
SELECT 
  sex,
  COUNT(*) AS amount,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percent,
  ROUND(AVG(credit_limit), 2) AS mean_limit,
  ROUND(APPROX_QUANTILES(credit_limit, 100)[OFFSET(50)], 2) AS median_limit,
  ROUND(AVG(default_payment_next_month) * 100, 2) AS default_rate_percent
FROM `exam-499409.exam.credit_data_prepared`
GROUP BY sex
ORDER BY sex;


-- ВОЗРАСТ ЗАЕМЩИКОВ
SELECT 
  COUNT(*) AS amount,
  ROUND(MIN(age), 1) AS min_age,
  ROUND(AVG(age), 1) AS mean_age,
  ROUND(APPROX_QUANTILES(age, 100)[OFFSET(50)], 1) AS median_age,
  ROUND(MAX(age), 1) AS max_age
FROM `exam-499409.exam.credit_data_prepared`;



-- АНАЛИЗ ВОЗРАСТНЫХ ГРУПП
SELECT 
  CASE 
    WHEN age < 30 THEN 'До 30 лет'
    WHEN age < 40 THEN '30-39 лет'
    WHEN age < 50 THEN '40-49 лет'
    WHEN age < 60 THEN '50-59 лет'
    ELSE '60+ лет'
  END AS age_group,
  COUNT(*) AS amount,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percent,
  ROUND(AVG(credit_limit), 2) AS avg_limit
FROM `exam-499409.exam.credit_data_prepared`
GROUP BY age_group
ORDER BY MIN(age);



-- Все корреляции с кредитным лимитом
SELECT 
  ROUND(CORR(credit_limit, age), 4) AS corr_age,
  ROUND(CORR(credit_limit, pay_0), 4) AS corr_pay_0,
  ROUND(CORR(credit_limit, bill_amt_1), 4) AS corr_bill_1,
  ROUND(CORR(credit_limit, pay_amt_1), 4) AS corr_pay_amt_1,
  ROUND(CORR(credit_limit, total_billed_6m), 4) AS corr_total_billed,
  ROUND(CORR(credit_limit, total_paid_6m), 4) AS corr_total_paid,
  ROUND(CORR(credit_limit, default_payment_next_month), 4) AS corr_default
FROM `exam-499409.exam.credit_data_prepared`;


-- Наибольшее влияние на кредитный лимит оказывают: Общая сумма платежей за 6 месяцев (r = 0.347) — клиенты, которые больше платят, получают более высокие лимиты, Общая сумма счетов за 6 месяцев (r = 0.322) — объём потребления кредитных средств, Счёт в текущем месяце (r = 0.300). Отрицательное влияние оказывают: Просрочки платежей (r = -0.224) — задержки снижают доверие банка, Наличие дефолта (r = -0.162)




-- РАЗБИВКА  70% обучение, 30% тест
CREATE OR REPLACE TABLE `exam-499409.exam.credit_data_split` AS
SELECT 
  *,
  RAND() < 0.7 AS is_train   -- TRUE = обучение, FALSE = тест
FROM `exam-499409.exam.credit_data_prepared`;


-- МОДЕЛЬ
CREATE OR REPLACE MODEL `exam-499409.exam.credit_limit_regressor`
OPTIONS(
  MODEL_TYPE = 'LINEAR_REG',
  INPUT_LABEL_COLS = ['credit_limit'],
  ENABLE_GLOBAL_EXPLAIN = TRUE,
  DATA_SPLIT_METHOD = 'CUSTOM',
  DATA_SPLIT_COL = 'is_train'      
) AS
SELECT *
FROM `exam-499409.exam.credit_data_split`;

--ОЦЕНКА 
SELECT
  ROUND(r2_score, 4) AS r_squared,
  ROUND(mean_absolute_error, 2) AS mae,
  ROUND(SQRT(mean_squared_error), 2) AS rmse
FROM
  ML.EVALUATE(
    MODEL `exam-499409.exam.credit_limit_regressor`,
    (SELECT * EXCEPT(is_train) FROM `exam-499409.exam.credit_data_split` WHERE is_train = FALSE)
  );


--xgbst
CREATE OR REPLACE MODEL `exam-499409.exam.credit_limit_xgboost`
OPTIONS(
  MODEL_TYPE = 'BOOSTED_TREE_REGRESSOR',
  INPUT_LABEL_COLS = ['credit_limit'],
  NUM_PARALLEL_TREE = 4,
  MAX_ITERATIONS = 100,
  EARLY_STOP = TRUE,
  DATA_SPLIT_METHOD = 'CUSTOM',
  DATA_SPLIT_COL = 'is_train'
) AS
SELECT 
  credit_limit,
  age,
  sex,
  education_level,
  marital_status,
  pay_0, pay_2, pay_3, pay_4, pay_5, pay_6,
  bill_amt_1, bill_amt_2, bill_amt_3, bill_amt_4, bill_amt_5, bill_amt_6,
  pay_amt_1, pay_amt_2, pay_amt_3, pay_amt_4, pay_amt_5, pay_amt_6,
  default_payment_next_month,
  total_paid_6m,
  total_billed_6m,
  is_train
FROM `exam-499409.exam.credit_data_split`;


--оценка xgbst
SELECT
  ROUND(r2_score, 4) AS r_squared,
  ROUND(mean_absolute_error, 2) AS mae,
  ROUND(SQRT(mean_squared_error), 2) AS rmse
FROM
  ML.EVALUATE(
    MODEL `exam-499409.exam.credit_limit_xgboost`,
    (SELECT 
       credit_limit, age, sex, education_level, marital_status,
       pay_0, pay_2, pay_3, pay_4, pay_5, pay_6,
       bill_amt_1, bill_amt_2, bill_amt_3, bill_amt_4, bill_amt_5, bill_amt_6,
       pay_amt_1, pay_amt_2, pay_amt_3, pay_amt_4, pay_amt_5, pay_amt_6,
       default_payment_next_month, total_paid_6m, total_billed_6m
     FROM `exam-499409.exam.credit_data_split` WHERE is_train = FALSE)
  );