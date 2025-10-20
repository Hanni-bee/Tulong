# 🧪 Offline Auth Testing Guide

## How to Test Offline Signup and Signin

### **Step 1: Test Offline Signup**
1. **Turn off WiFi and mobile data** on your device
2. **Open the app** → Go to "Sign Up"
3. **Fill out the form** with:
   - First Name: Test
   - Last Name: User  
   - Email: test@example.com
   - Password: password123
   - Address: 123 Test St
   - Region: NCR
   - City: Manila
   - Barangay: Test Barangay
   - ZIP: 1000
4. **Submit** → Should see "Account created successfully! Works offline and will sync when online."
5. **You're logged in** → Can use the app offline

### **Step 2: Test Offline Signin**
1. **Sign out** of the app
2. **Stay offline** (no WiFi, no mobile data)
3. **Go to Sign In** → Enter:
   - Email: test@example.com
   - Password: password123
4. **Submit** → Should see "Using offline mode - will sync when online"
5. **You're logged in** → Can use the app offline

### **Step 3: Test Auto-Sync**
1. **Turn internet back on** (WiFi or mobile data)
2. **The app will automatically sync** your offline account to Firebase
3. **You'll see a success message** when sync completes

## ✅ **Expected Results:**

- **Offline Signup**: Works completely without internet
- **Offline Signin**: Works for accounts created offline
- **Auto-Sync**: When internet returns, accounts sync to Firebase
- **No Errors**: Everything works smoothly offline

## 🚨 **Emergency Scenario:**
- Cell towers down ✅
- No WiFi ✅  
- No power (but device has battery) ✅
- **You can still create accounts and log in!**

Your app is **emergency-ready**! 🎉
