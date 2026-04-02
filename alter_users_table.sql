-- SQL to alter the users table to add email and created_at columns
-- Run this in your Supabase SQL Editor

-- Add email column
ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- Add created_at column with default value
ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add unique constraint on email (optional, but recommended)
ALTER TABLE users ADD CONSTRAINT users_email_unique UNIQUE (email);

-- Add index on email for faster lookups (optional)
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
