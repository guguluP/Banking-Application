-- Seed data for Odisha bank locations
USE banking_db;

INSERT INTO bank_locations (id, name, location_type, street, city, state, postal_code, phone_number, latitude, longitude, is_open_now) VALUES
('loc_001', 'Bhubaneswar Main Branch', 'branch', '123 Janpath Road', 'Bhubaneswar', 'OD', '751001', '+91 674 5551234', 20.2963, 85.8248, TRUE),
('loc_002', 'Cuttack ATM', 'atm', '456 Link Road', 'Cuttack', 'OD', '753001', '+91 671 5555678', 20.4627, 85.8960, TRUE),
('loc_003', 'Puri Branch', 'atm_and_branch', '789 Marine Drive', 'Puri', 'OD', '751002', '+91 675 5559012', 19.8135, 85.8329, TRUE),
('loc_004', 'Rourkela ATM', 'atm', '321 Steel Plant Road', 'Rourkela', 'OD', '769001', '+91 661 5553456', 22.2281, 84.8567, TRUE),
('loc_005', 'Sambalpur Branch', 'branch', '654 Main Street', 'Sambalpur', 'OD', '768001', '+91 664 5557890', 21.4416, 83.9897, TRUE);

-- Seed users
INSERT INTO users (id, first_name, last_name, email, phone_number, city, state) VALUES
('user_001', 'John', 'Doe', 'john.doe@example.com', '+1234567890', 'Bhubaneswar', 'OD');

-- Seed accounts
INSERT INTO accounts (id, user_id, account_number, account_type, balance, available_balance, nickname) VALUES
('acc_001', 'user_001', '1234567890', 'checking', 5420.75, 5420.75, 'Primary Checking'),
('acc_002', 'user_001', '0987654321', 'savings', 12500.00, 12500.00, 'Emergency Fund'),
('acc_003', 'user_001', '5555444433332222', 'credit', -850.25, 4149.75, 'Visa Credit Card');