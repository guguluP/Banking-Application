-- Banking Application Database Schema
-- Import this into MySQL Workbench to create the database

CREATE DATABASE IF NOT EXISTS banking_db;
USE banking_db;

-- Users table
CREATE TABLE users (
    id VARCHAR(50) PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone_number VARCHAR(20) UNIQUE,
    date_of_birth DATE,
    street VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Accounts table
CREATE TABLE accounts (
    id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    account_number VARCHAR(50) UNIQUE NOT NULL,
    account_type ENUM('checking', 'savings', 'credit') NOT NULL,
    account_status ENUM('active', 'inactive', 'frozen', 'closed') DEFAULT 'active',
    balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    available_balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'INR',
    nickname VARCHAR(100),
    opened_date DATE,
    interest_rate DECIMAL(5,4),
    is_primary BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Transactions table
CREATE TABLE transactions (
    id VARCHAR(50) PRIMARY KEY,
    account_id VARCHAR(50) NOT NULL,
    transaction_type ENUM('deposit', 'withdrawal', 'transfer', 'payment', 'fee', 'interest') NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    description VARCHAR(255),
    counterparty VARCHAR(255),
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_credit BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (account_id) REFERENCES accounts(id)
);

-- UPI Transactions table
CREATE TABLE upi_transactions (
    id VARCHAR(50) PRIMARY KEY,
    account_id VARCHAR(50) NOT NULL,
    upi_id VARCHAR(100) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    remarks TEXT,
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(id)
);

-- Billers table
CREATE TABLE billers (
    id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_number VARCHAR(50),
    biller_code VARCHAR(50),
    nickname VARCHAR(100),
    phone_number VARCHAR(20),
    email VARCHAR(255),
    website VARCHAR(255),
    is_favorite BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Bank Locations table (Odisha branches/ATMs)
CREATE TABLE bank_locations (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    location_type ENUM('atm', 'branch', 'atm_and_branch') NOT NULL,
    street VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100) DEFAULT 'OD',
    postal_code VARCHAR(20),
    country VARCHAR(100) DEFAULT 'India',
    phone_number VARCHAR(20),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    hours JSON,
    is_open_now BOOLEAN DEFAULT TRUE
);