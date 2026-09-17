# Fix: Doctor Registration Server Error

## Problem
When registering a doctor account through the Flutter app, users encountered a "server error" even though the registration appeared successful.

## Root Causes

### Issue 1: Missing Doctor Profile Creation
The Flutter app was calling `/api/v1/auth/register` with `role: 'doctor'`, which created a User record but did NOT automatically create the corresponding Doctor profile in the database. 

When the user tried to login and access their profile, the app would fail because the Doctor profile didn't exist.

### Issue 2: Unique Constraint on License Number
After fixing Issue 1 by auto-creating Doctor profiles, a second error appeared: the database has a unique constraint on `licenseNumber`, and we were setting it to an empty string `''` for all new doctors. This caused "Unique constraint failed on licenseNumber" errors when multiple doctors tried to register.

## Solutions

### Solution 1: Auto-create Doctor Profile
Modified the `register()` method in `backend/src/modules/auth/auth.service.ts` to automatically create a basic Doctor profile when the role is 'doctor'.

### Solution 2: Generate Unique Temporary License Number
Instead of using an empty string for `licenseNumber`, we now generate a unique temporary license number using the format: `TEMP-{userId}-{timestamp}`.

This ensures:
- Every doctor has a unique license number
- The number is clearly marked as temporary
- Doctors can update it with their real license number when completing their profile

## Solution
Modified the `register()` method in `backend/src/modules/auth/auth.service.ts` to automatically create a basic Doctor profile when the role is 'doctor'.

### Changes Made

**File: `backend/src/modules/auth/auth.service.ts`**

```typescript
// After creating the User record
if (input.role === 'doctor') {
  const firstName = input.firstName || '';
  const lastName = input.lastName || '';
  // Generate a temporary unique license number until doctor completes profile
  const tempLicenseNumber = `TEMP-${user.id.substring(0, 8)}-${Date.now()}`;
  await prisma.doctor.create({
    data: {
      userId: user.id,
      firstName,
      lastName,
      specialty: 'General Practice', // Default specialty
      licenseNumber: tempLicenseNumber, // Temporary unique license number
    },
  });
}

// In the error handler
if (error?.code === 'P2002') {
  const target = Array.isArray(error?.meta?.target)
    ? error.meta.target.join(',')
    : String(error?.meta?.target ?? '');
  if (target.includes('phone')) {
    throw phoneConflict();
  }
  if (target.includes('licenseNumber')) {
    throw new ConflictError('License number conflict - please try again');
  }
  // ... handle email conflicts
}
```

### How It Works Now

1. **Registration Flow:**
   - Flutter app sends: `POST /api/v1/auth/register`
   - Payload includes: `firstName`, `lastName`, `phone`, `password`, `role: 'doctor'`
   - Backend creates:
     - ✅ User record with role 'doctor'
     - ✅ Doctor profile with basic information
   - Returns JWT tokens

2. **Login Flow:**
   - User logs in with phone + password
   - Backend returns JWT tokens
   - App calls `GET /api/v1/doctors/profile`
   - ✅ Doctor profile now exists and is returned

3. **Profile Completion:**
   - User can complete their profile with additional details:
     - Specialty (can be changed from default)
     - License number
     - Photo
     - Languages
     - Working hours
     - etc.

## Testing

### Test the Registration
```bash
# Register a new doctor
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Test",
    "lastName": "Doctor",
    "phone": "+237655112233",
    "password": "TestPass123",
    "role": "doctor"
  }'
```

Expected response:
```json
{
  "success": true,
  "message": "Registration successful",
  "data": {
    "user": {
      "id": "6aac7cadde95109a36395737",
      "email": "phone-237698765432@tosumo.cm",
      "phone": "+237698765432",
      "role": "doctor",
      ...
    },
    "tokens": {
      "accessToken": "...",
      "refreshToken": "..."
    }
  }
}
```

### Test Profile Access
```bash
# Login to get token
TOKEN=$(curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+237655112233",
    "password": "TestPass123"
  }' | jq -r '.data.tokens.accessToken')

# Get profile
curl -X GET http://localhost:3000/api/v1/doctors/profile \
  -H "Authorization: Bearer $TOKEN"
```

Expected response:
```json
{
  "success": true,
  "data": {
    "id": "6aac7cadde95109a36395738",
    "userId": "6aac7cadde95109a36395737",
    "firstName": "Sophie",
    "lastName": "Durand",
    "specialty": "General Practice",
    "licenseNumber": "TEMP-6aac7cad-1789689006288",
    "phone": "+237698765432",
    ...
  }
}
```

Note that the `licenseNumber` is now a unique temporary value that starts with "TEMP-".

## Flutter App Integration

No changes needed in the Flutter app! The existing registration flow now works correctly:

**File: `apps/doctor_flutter/lib/features/auth/presentation/register_screen.dart`**

The registration form already sends the correct payload:
```dart
await authProvider.register(
  firstName: _firstNameController.text.trim(),
  lastName: _lastNameController.text.trim(),
  phone: _phoneController.text.trim(),
  password: _passwordController.text,
);
```

**File: `apps/doctor_flutter/lib/core/data/repositories/remote_doctor_repository.dart`**

The repository already calls the correct endpoint:
```dart
@override
Future<void> register({
  required String firstName,
  required String lastName,
  required String phone,
  required String password,
}) async {
  await _client.dio.post(DoctorApiEndpoints.register, data: {
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'password': password,
    'role': 'doctor',
  });
}
```

## Database Schema

### User Table
```
id: ObjectId
email: string (unique)
phone: string (unique)
passwordHash: string
role: 'patient' | 'doctor' | 'admin'
isActive: boolean
...
```

### Doctor Table
```
id: ObjectId
userId: ObjectId (references User.id)
firstName: string
lastName: string
specialty: string
licenseNumber: string
phone: string (optional, can override User.phone)
...
```

## Benefits

1. **Seamless Registration:** Doctors can now register and immediately access their profile
2. **Better UX:** No "server error" or missing profile issues
3. **Consistent Data:** Every doctor User automatically has a corresponding Doctor profile
4. **Progressive Profile:** Doctors start with basic info and can complete details later

## Additional Endpoints

For reference, there's also a specialized doctor registration endpoint for the web app that requires more details upfront:

**Endpoint:** `POST /api/v1/auth/register/doctor`

**Payload:**
```json
{
  "firstName": "Marie",
  "lastName": "Kamga",
  "email": "marie.kamga@tosumo.cm",
  "phone": "+237699887766",
  "password": "TestPass123",
  "specialty": "Cardiology",
  "licenseNumber": "MD-CMR-12345",
  "institutionId": "507f1f77bcf86cd799439011"
}
```

This endpoint creates:
- User record
- Doctor record with full details
- DoctorInstitution association

## Commit Information

**Branch:** `feature/hospital-web-sync-fixes`

**Commits:**
1. `1f0f06d` - fix(backend): Auto-create Doctor profile on doctor registration
2. `6ed03e3` - fix(backend): Generate unique temporary license number for doctor registration

**Changes:**
- `backend/src/modules/auth/auth.service.ts` - Modified register() method to:
  - Auto-create Doctor profile when role is 'doctor'
  - Generate unique temporary license number
  - Handle license number conflicts

**Pushed to GitHub:** ✅ Yes

## Status

✅ **Fixed and Deployed**

The doctor registration flow now works correctly in both:
- Flutter mobile app (simplified registration)
- Web app (full registration with institution)

Users can register, login, and access their profiles without errors.
