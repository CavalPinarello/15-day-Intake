# Physician Authentication System

## Overview

The system now includes **role-based authentication** with three user roles:
- `patient` - Regular users who complete the 15-day sleep program
- `physician` - Medical professionals who review patient data
- `admin` - Administrative users with full access

## Database Schema

### User Role Field

The `users` table now includes a `role` field:

```typescript
users: defineTable({
  username: v.string(),
  password_hash: v.string(),
  email: v.optional(v.string()),
  role: v.optional(v.union(v.literal("patient"), v.literal("physician"), v.literal("admin"))),
  // ... other fields
})
  .index("by_username", ["username"])
  .index("by_email", ["email"])
  .index("by_role", ["role"]),  // New index for role queries
```

## Current Setup

✅ **Schema Deployed**: Role field added to database
✅ **Users Migrated**: All existing users set to "patient" role
✅ **Physician User**: Username "physician" set to "physician" role

### Current Users and Roles:

| Username  | Role      |
|-----------|-----------|
| Martin    | patient   |
| Martin2   | patient   |
| physician | physician |

## Authentication Flow

### 1. Login

When a user logs in:
1. Backend validates credentials
2. Backend returns user data **including the `role` field**
3. Frontend stores user data in localStorage
4. Frontend checks the role and redirects:
   - `physician` or `admin` → `/physician-dashboard`
   - `patient` → `/journey`

### 2. Code Example

```typescript
// Login response includes role
const response = await authAPI.login(username, password);

// Redirect based on role from database
const userRole = response.user.role || 'patient';
if (userRole === 'physician' || userRole === 'admin') {
  router.push('/physician-dashboard');
} else {
  router.push('/journey');
}
```

## Available Convex Functions

### Queries

- `getUsersByRole({ role })` - Get all users with a specific role
- `getUserByUsername({ username })` - Get user by username (includes role)

### Mutations

- `setUserRole({ userId, role })` - Set a user's role by ID
- `setRoleByUsername({ username, role })` - Set a user's role by username
- `migrateUserRoles({})` - Migrate users without roles to "patient"

## Testing Physician Login

### Step 1: Login as Physician

1. Go to: http://localhost:3000/login
2. Enter credentials:
   - **Username**: `physician`
   - **Password**: (your physician user password)
3. Click "Login"

### Step 2: Verify Redirect

After successful login, you should be automatically redirected to:
```
http://localhost:3000/physician-dashboard
```

### Step 3: Test Patient Login

1. Login as a regular user (e.g., "Martin")
2. Verify you are redirected to:
```
http://localhost:3000/journey
```

## Managing Roles

### Set a User to Physician Role

Using the Convex dashboard or via the script:

```javascript
// Using the script
NEXT_PUBLIC_CONVEX_URL="https://your-deployment.convex.cloud" node scripts/setup-physician-user.js

// Or using Convex CLI
npx convex run users:setRoleByUsername '{"username": "dr_smith", "role": "physician"}'
```

### Create a New Physician User

**Option 1: Register then Upgrade**
1. Register a new user at `/register`
2. Use Convex function to set role:
   ```bash
   npx convex run users:setRoleByUsername '{"username": "new_physician", "role": "physician"}'
   ```

**Option 2: Manual Database Entry**
1. Insert user into Convex database
2. Set `role: "physician"` in the user document

## Security Considerations

### ✅ What's Implemented

1. **Database-Driven Roles**: Roles are stored in the database, not hardcoded
2. **Index for Performance**: `by_role` index for efficient role queries
3. **Backend Validation**: Backend includes role in auth response
4. **Frontend Routing**: Frontend uses database role for redirection

### 🔒 What Should Be Added

For production, you should also implement:

1. **Protected API Endpoints**: Verify user role in backend middleware
   ```javascript
   function requireRole(role) {
     return (req, res, next) => {
       if (req.user.role !== role) {
         return res.status(403).json({ error: 'Forbidden' });
       }
       next();
     };
   }
   ```

2. **Frontend Route Protection**: Add role checks to physician dashboard pages
   ```typescript
   // In physician dashboard layout
   useEffect(() => {
     const user = JSON.parse(localStorage.getItem('user') || '{}');
     if (user.role !== 'physician' && user.role !== 'admin') {
       router.push('/journey');
     }
   }, []);
   ```

3. **JWT Token Claims**: Include role in JWT tokens for stateless validation

## Troubleshooting

### Issue: Physician user redirects to journey page

**Solution**: Run the migration script
```bash
cd "/Users/martinkawalski/Documents/1. Projects/15-Day Test"
NEXT_PUBLIC_CONVEX_URL="https://enchanted-terrier-633.convex.cloud" node scripts/setup-physician-user.js
```

### Issue: Role not showing in login response

**Solution**: Check backend auth route includes role:
```javascript
const { password_hash, _id, ...userData } = user;
if (!userData.role) {
  userData.role = "patient";
}
res.json({ user: userData, ... });
```

### Issue: Frontend doesn't recognize role

**Solution**: Update TypeScript interface:
```typescript
export interface User {
  id: number;
  username: string;
  role?: 'patient' | 'physician' | 'admin';
  // ...
}
```

## Files Modified

### Backend
- `convex/schema.ts` - Added role field and index
- `convex/users.ts` - Added role management functions
- `server/routes/auth.js` - Updated login to return role

### Frontend
- `client/lib/api.ts` - Added role to User interface
- `client/app/login/page.tsx` - Updated redirect logic to use role

### Scripts
- `scripts/setup-physician-user.js` - New setup script for role management

## Next Steps

1. ✅ Test physician login and verify redirect
2. 🔄 Add route protection to physician dashboard pages
3. 🔄 Implement backend API authorization middleware
4. 🔄 Add role-based UI elements (show/hide features by role)
5. 🔄 Create admin panel for role management

---

**Last Updated**: November 13, 2025
**Status**: ✅ Deployed and Ready for Testing



