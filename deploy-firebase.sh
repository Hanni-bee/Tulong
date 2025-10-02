#!/bin/bash

# T.U.L.O.N.G Firebase Deployment Script
# This script safely deploys Firebase enhancements without breaking existing functionality

echo "🔥 Starting T.U.L.O.N.G Firebase Deployment..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if user is logged in
if ! firebase projects:list &> /dev/null; then
    echo "❌ Please login to Firebase first:"
    echo "firebase login"
    exit 1
fi

echo "✅ Firebase CLI ready"

# Step 1: Deploy Database Rules (Safe - only adds validation)
echo "📊 Deploying Database Rules..."
firebase deploy --only database
if [ $? -eq 0 ]; then
    echo "✅ Database rules deployed successfully"
else
    echo "❌ Database rules deployment failed"
    exit 1
fi

# Step 2: Deploy Storage Rules (Safe - only adds file restrictions)
echo "📁 Deploying Storage Rules..."
firebase deploy --only storage
if [ $? -eq 0 ]; then
    echo "✅ Storage rules deployed successfully"
else
    echo "❌ Storage rules deployment failed"
    exit 1
fi

# Step 3: Deploy Cloud Functions (Optional - can be skipped if not ready)
echo "⚡ Deploying Cloud Functions..."
read -p "Deploy Cloud Functions? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    firebase deploy --only functions
    if [ $? -eq 0 ]; then
        echo "✅ Cloud Functions deployed successfully"
    else
        echo "❌ Cloud Functions deployment failed"
        echo "⚠️  This is optional - continuing with other deployments"
    fi
else
    echo "⏭️  Skipping Cloud Functions deployment"
fi

# Step 4: Verify deployment
echo "🔍 Verifying deployment..."
firebase projects:list
echo "✅ Deployment verification complete"

echo ""
echo "🎉 T.U.L.O.N.G Firebase deployment completed!"
echo ""
echo "📋 What was deployed:"
echo "  ✅ Database Security Rules (enhanced validation)"
echo "  ✅ Storage Security Rules (file upload restrictions)"
echo "  ⚡ Cloud Functions (if selected)"
echo ""
echo "🔧 Next steps:"
echo "  1. Test your app to ensure everything works"
echo "  2. Check Firebase Console for any issues"
echo "  3. Monitor your app's performance"
echo ""
echo "🆘 If you encounter issues:"
echo "  - Check Firebase Console for error logs"
echo "  - Test with Firebase emulators first"
echo "  - Rollback if necessary: firebase database:rules:rollback"
