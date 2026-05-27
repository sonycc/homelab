CREATE USER grafana WITH PASSWORD 'strong_password_here';

CREATE DATABASE grafana OWNER grafana;

GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;
