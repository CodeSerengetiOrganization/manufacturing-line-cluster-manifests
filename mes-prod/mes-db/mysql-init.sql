-- MES database bootstrap (mes-prod namespace).
-- Creates mes_db and app user only. Apply full schema from mes-db repo baseline/ separately.
CREATE DATABASE IF NOT EXISTS mes_db;
CREATE USER IF NOT EXISTS 'linemachine'@'%' IDENTIFIED BY '1234fast';
GRANT ALL PRIVILEGES ON mes_db.* TO 'linemachine'@'%';
FLUSH PRIVILEGES;