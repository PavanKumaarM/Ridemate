# RideMate Database Schema - User Profile

## Supabase SQL Setup

Run these SQL commands in your Supabase SQL Editor to set up the user profile system:

### 1. Users Table (Extended)

```sql
-- Create/Update users table with extended profile fields
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT,
    address TEXT,
    profile_photo_url TEXT,
    identity_document_url TEXT,
    identity_document_type TEXT,
    is_profile_complete BOOLEAN DEFAULT false,
    rating DOUBLE PRECISION DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view all profiles"
    ON public.users FOR SELECT
    USING (true);

CREATE POLICY "Users can update own profile"
    ON public.users FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
    ON public.users FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Create function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### 2. Storage Buckets

```sql
-- Create storage bucket for profile photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-photos', 'profile-photos', true);

-- Create storage bucket for identity documents
INSERT INTO storage.buckets (id, name, public)
VALUES ('identity-documents', 'identity-documents', false);
```

### 3. Storage Policies

```sql
-- Profile photos bucket policies
CREATE POLICY "Users can upload own profile photo"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'profile-photos' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can update own profile photo"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'profile-photos' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Profile photos are publicly viewable"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'profile-photos');

CREATE POLICY "Users can delete own profile photo"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'profile-photos' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- Identity documents bucket policies
CREATE POLICY "Users can upload own identity document"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'identity-documents' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can update own identity document"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'identity-documents' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view own identity document"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'identity-documents' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Admins can view all identity documents"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'identity-documents' 
        AND EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() AND is_admin = true
        )
    );

CREATE POLICY "Users can delete own identity document"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'identity-documents' 
        AND auth.uid()::text = (storage.foldername(name))[1]
    );
```

### 4. Add is_admin column (optional, for admin access)

```sql
-- Add is_admin column to users table (if needed for admin access)
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;
```

## Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key, references auth.users |
| `name` | TEXT | User's full name |
| `phone` | TEXT | Phone number |
| `email` | TEXT | Email address (optional) |
| `address` | TEXT | Home/Current address (optional) |
| `profile_photo_url` | TEXT | URL to profile photo in storage bucket |
| `identity_document_url` | TEXT | URL to ID document in storage bucket |
| `identity_document_type` | TEXT | Type: 'Aadhaar Card', 'PAN Card', 'Driving License', 'Passport', 'Voter ID' |
| `is_profile_complete` | BOOLEAN | Whether profile setup is complete |
| `rating` | DOUBLE | User rating (0-5) |
| `created_at` | TIMESTAMP | Account creation time |
| `updated_at` | TIMESTAMP | Last update time |

## Storage Buckets

| Bucket Name | Public | Purpose |
|-------------|--------|---------|
| `profile-photos` | Yes | User profile pictures |
| `identity-documents` | No | Identity verification documents |

## Flutter Model Mapping

The `UserModel` in Flutter maps to this schema:

```dart
class UserModel {
  String id;              // → users.id
  String name;            // → users.name
  String phone;           // → users.phone
  String? email;          // → users.email
  String? address;        // → users.address
  String? profilePhotoUrl;    // → users.profile_photo_url
  String? identityDocumentUrl; // → users.identity_document_url
  String? identityDocumentType;  // → users.identity_document_type
  bool isProfileComplete; // → users.is_profile_complete
  double rating;          // → users.rating
  DateTime? createdAt;    // → users.created_at
  DateTime? updatedAt;    // → users.updated_at
}
```

## Usage

1. **Create user record after signup:**
```sql
INSERT INTO public.users (id, name, phone, is_profile_complete)
VALUES (auth.uid(), 'New User', '', false);
```

2. **Fetch user profile:**
```dart
final response = await Supabase.instance.client
    .from('users')
    .select()
    .eq('id', userId)
    .single();
```

3. **Update profile:**
```dart
await Supabase.instance.client
    .from('users')
    .update({
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'profile_photo_url': photoUrl,
      'identity_document_url': docUrl,
      'identity_document_type': docType,
      'is_profile_complete': true,
    })
    .eq('id', userId);
```

4. **Upload profile photo:**
```dart
await Supabase.instance.client.storage
    .from('profile-photos')
    .upload('user_id/filename.jpg', file);
```

## Screens Integration

| Screen | Route | Purpose |
|--------|-------|---------|
| Profile Setup | `/profileSetup` | First-time setup or edit profile |
| Profile View | `/profile` | Display user profile with all fields |

## Required Flutter Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  image_picker: ^1.1.2
  supabase_flutter: ^2.12.0
```

## Android Permissions

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

## iOS Permissions

Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to take profile photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select profile photos</string>
```
