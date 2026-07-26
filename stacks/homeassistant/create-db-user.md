CREATE USER homeassistant WITH PASSWORD 'strong_password_here';

CREATE DATABASE homeassistant OWNER homeassistant;

GRANT ALL PRIVILEGES ON DATABASE homeassistant TO homeassistant;
