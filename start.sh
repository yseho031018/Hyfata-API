#!/bin/bash

# ==========================================
# Hyfata REST API Environment Setup & Start Script
# ==========================================

# Server Configuration
export PORT=8080

# Database Configuration (PostgreSQL)
export DB_URL="jdbc:postgresql://localhost:5432/hyfata_db"
export DB_USER="postgres"
export DB_PASSWORD="your_password"
# export R2DBC_URL="r2dbc:postgresql://localhost:5432/hyfata_db" # Optional

# JWT Configuration
# Important: Use a strong, random string for production
export JWT_SECRET="your_very_secure_and_long_random_secret_key_minimum_256_bits"

# Mail Configuration
export MAIL_HOST_NAME="smtp.example.com"
export MAIL_PORT=587
export MAIL_USERNAME="your_email"
export MAIL_PASSWORD="your_email_password"
export MAIL_FROM="noreply@hyfata.kr"

# Redis Configuration
export REDIS_HOST="localhost"
export REDIS_PORT=6379
export REDIS_PASSWORD=""

# GeoIP Configuration
export GEOIP_DATABASE_PATH="./GeoLite2-City.mmdb"
export GEOIP_ENABLED="false"

echo "----------------------------------------"
echo "Environment variables exported."
echo "Starting Hyfata REST API..."
echo "----------------------------------------"

# Run the application
./gradlew bootRun
