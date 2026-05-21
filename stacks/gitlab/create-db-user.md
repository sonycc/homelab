CREATE USER gitlab WITH PASSWORD 'strong_password_here';

CREATE DATABASE gitlab OWNER gitlab;

GRANT ALL PRIVILEGES ON DATABASE gitlab TO gitlab;
