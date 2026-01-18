-- makes the user can be accessed from any host
UPDATE mysql.user SET host = '%' WHERE user = 'root';

-- Template for creating additional databases and users

-- CREATE DATABASE IF NOT EXISTS service_db;
-- CREATE USER IF NOT EXISTS 'example_user'@'%' IDENTIFIED BY 'example_password';
-- GRANT ALL PRIVILEGES ON service_db.* TO 'example_user'@'%';

FLUSH PRIVILEGES;