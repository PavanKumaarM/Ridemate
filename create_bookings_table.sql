-- SQL to create bookings table
-- Run this in your Supabase SQL Editor

-- Create bookings table to track trip bookings
CREATE TABLE IF NOT EXISTS bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    booker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    host_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, accepted, rejected, cancelled
    seats_booked INTEGER NOT NULL DEFAULT 1,
    total_fare DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_bookings_trip_id ON bookings(trip_id);
CREATE INDEX IF NOT EXISTS idx_bookings_booker_id ON bookings(booker_id);
CREATE INDEX IF NOT EXISTS idx_bookings_host_id ON bookings(host_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

-- Add RLS policies for bookings table
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own bookings (as booker or host)
CREATE POLICY "Users can view own bookings"
    ON bookings FOR SELECT
    USING (auth.uid() = booker_id OR auth.uid() = host_id);

-- Policy: Users can create bookings
CREATE POLICY "Users can create bookings"
    ON bookings FOR INSERT
    WITH CHECK (auth.uid() = booker_id);

-- Policy: Hosts can update booking status
CREATE POLICY "Hosts can update booking status"
    ON bookings FOR UPDATE
    USING (auth.uid() = host_id);

-- Policy: Users can delete their own bookings
CREATE POLICY "Users can delete own bookings"
    ON bookings FOR DELETE
    USING (auth.uid() = booker_id);
