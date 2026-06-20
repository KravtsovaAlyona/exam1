-- Сколько всего клиентов
SELECT COUNT(*) AS total_customers
FROM `exam-task-5.customer_churn.telco_churn`;

-- Проверяем пропуски
SELECT
  COUNTIF(customerID IS NULL) AS null_customerID,
  COUNTIF(gender IS NULL) AS null_gender,
  COUNTIF(Partner IS NULL) AS null_partner,
  COUNTIF(Dependents IS NULL) AS null_dependents,
  COUNTIF(tenure IS NULL) AS null_tenure,
  COUNTIF(MonthlyCharges IS NULL) AS null_monthly_charges,
  COUNTIF(TotalCharges IS NULL) AS null_total_charges,
  COUNTIF(Churn IS NULL) AS null_churn
FROM `exam-task-5.customer_churn.telco_churn`;


-- Распределение Churn
SELECT
  Churn,
  COUNT(*) AS count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM `exam-task-5.customer_churn.telco_churn`
GROUP BY Churn
ORDER BY Churn DESC;


-- Отток по полу
SELECT
  gender,
  COUNT(*) AS total,
  SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churned,
  ROUND(AVG(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_pct
FROM `exam-task-5.customer_churn.telco_churn`
GROUP BY gender
ORDER BY churn_rate_pct DESC;
--Пол практически не влияет на отток


-- Отток по возрасту (SeniorCitizen)
SELECT
  SeniorCitizen,
  CASE WHEN SeniorCitizen = 1 THEN 'Пенсионер (65+)' ELSE 'Не пенсионер' END AS age_group,
  COUNT(*) AS total,
  SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churned,
  ROUND(AVG(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_pct
FROM `exam-task-5.customer_churn.telco_churn`
GROUP BY SeniorCitizen
ORDER BY churn_rate_pct DESC;
--Пенсионеры уходят почти в 2 раза чаще!


-- Отток по наличию иждивенцев (Dependents)
SELECT
  Dependents,
  COUNT(*) AS total,
  ROUND(AVG(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_pct
FROM `exam-task-5.customer_churn.telco_churn`
GROUP BY Dependents
ORDER BY churn_rate_pct DESC;
--Клиенты с иждивенцами уходят реже

-- Отток  в разрезе типа контракта
SELECT
  Contract,
  COUNT(*) AS total,
  SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS churned,
  ROUND(AVG(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_pct
FROM `exam-task-5.customer_churn.telco_churn`
GROUP BY Contract
ORDER BY churn_rate_pct DESC;
--Месячные контракты уходят в 15 раз чаще, чем двухлетние


--Отток по наличию интернета
SELECT
  InternetService,
  COUNT(*) AS total,
  ROUND(AVG(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_pct
FROM `exam-task-5.customer_churn.telco_churn`
GROUP BY InternetService
ORDER BY churn_rate_pct DESC;
--Клиенты с оптоволокном уходят в 5 раз чаще, чем без интернета


-- Сколько клиент пользуется услугами
SELECT
  CASE
    WHEN tenure < 12 THEN '0-11 мес (новые)'
    WHEN tenure < 24 THEN '12-23 мес'
    WHEN tenure < 48 THEN '24-47 мес'
    ELSE '48+ мес (старые)'
  END AS tenure_group,
  COUNT(*) AS total,
  ROUND(AVG(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) * 100, 2) AS churn_rate_pct
FROM `exam-task-5.customer_churn.telco_churn`
GROUP BY tenure_group
ORDER BY tenure_group;
--Чем дольше клиент, тем меньше шансов на его уход



-- Создаём или заменяем таблицу с флагом разделения
CREATE OR REPLACE TABLE `exam-task-5.customer_churn.telco_churn_split` AS
SELECT
  *,
  -- Преобразуем Churn в 0/1 для модели
  CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END AS churn_label,
  -- Преобразуем TotalCharges из строки в число (если нужно)
  SAFE_CAST(TotalCharges AS FLOAT64) AS TotalCharges_num,
  -- Разделение: 70% train, 30% test
  RAND() < 0.7 AS is_train
FROM `exam-task-5.customer_churn.telco_churn`;



CREATE OR REPLACE MODEL `exam-task-5.customer_churn.churn_classifier`
OPTIONS(
  MODEL_TYPE = 'LOGISTIC_REG',
  INPUT_LABEL_COLS = ['churn_label'],
  ENABLE_GLOBAL_EXPLAIN = TRUE,
  AUTO_CLASS_WEIGHTS = TRUE,  -- Балансировка классов
  DATA_SPLIT_METHOD = 'CUSTOM',
  DATA_SPLIT_COL = 'is_train'
) AS
SELECT
  churn_label,
  gender,
  SeniorCitizen,
  Partner,
  Dependents,
  tenure,
  PhoneService,
  MultipleLines,
  InternetService,
  OnlineSecurity,
  OnlineBackup,
  DeviceProtection,
  TechSupport,
  StreamingTV,
  StreamingMovies,
  Contract,
  PaperlessBilling,
  PaymentMethod,
  MonthlyCharges,
  TotalCharges_num,
  is_train
FROM `exam-task-5.customer_churn.telco_churn_split`;


-- Оценка модели
SELECT
  ROUND(roc_auc, 4) AS roc_auc,
  ROUND(accuracy, 4) AS accuracy,
  ROUND(precision, 4) AS precision,
  ROUND(recall, 4) AS recall,
  ROUND(f1_score, 4) AS f1_score
FROM
  ML.EVALUATE(
    MODEL `exam-task-5.customer_churn.churn_classifier`,
    (SELECT
       churn_label, gender, SeniorCitizen, Partner, Dependents,
       tenure, PhoneService, MultipleLines, InternetService,
       OnlineSecurity, OnlineBackup, DeviceProtection, TechSupport,
       StreamingTV, StreamingMovies, Contract, PaperlessBilling,
       PaymentMethod, MonthlyCharges, TotalCharges_num
     FROM `exam-task-5.customer_churn.telco_churn_split`
     WHERE is_train = FALSE)
  );
--Модель находит 81 из 100 реальных уходящих клиентов

SELECT
  customerID,
  Churn AS actual_churn,
  ROUND(predicted_churn_label, 4) AS probability_churn_yes,
  
  CASE
    WHEN predicted_churn_label >= 0.5 THEN 'ДА, уйдёт'
    ELSE 'НЕТ, останется'
  END AS model_decision,
  
  CASE
    WHEN Churn = 'Yes' AND predicted_churn_label >= 0.5 THEN 'Угадала! (отток)'
    WHEN Churn = 'No' AND predicted_churn_label < 0.5 THEN 'Угадала! (лояльный)'
    WHEN Churn = 'Yes' AND predicted_churn_label < 0.5 THEN 'Ошибка! (пропустила отток)'
    WHEN Churn = 'No' AND predicted_churn_label >= 0.5 THEN 'Ошибка! (ложная тревога)'
  END AS result,

  tenure,
  MonthlyCharges,
  Contract

FROM
  ML.PREDICT(
    MODEL `exam-task-5.customer_churn.churn_classifier`,
    (SELECT * FROM `exam-task-5.customer_churn.telco_churn_split` WHERE is_train = FALSE)
  )

ORDER BY predicted_churn_label DESC
LIMIT 30;