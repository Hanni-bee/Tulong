# Simple Testing Guide - No Download Needed! 📸

## Option 1: Test with Your Camera 📷

You can test using your phone's camera with simple everyday objects:

### 🌧️ **FLOOD Test**
- Take photo of: **Water** (glass of water, pool, puddle, rain)
- Or: **Blue objects** (blue cloth, blue wall, blue sky)
- Even: **Bathroom sink with water**

### 🔥 **WILDFIRE Test**
- Take photo of: **Fire** (candle, lighter, match, campfire)
- Or: **Smoke** (cigarette, incense, cooking smoke)
- Or: **Orange/Red objects** (orange fruit, red cloth, sunset)

### 🌍 **EARTHQUAKE Test**
- Take photo of: **Cracked surface** (cracked wall, cracked floor, broken tile)
- Or: **Damaged objects** (broken glass, damaged furniture)
- Or: **Rough textures** (concrete, brick wall)

### 🌪️ **CYCLONE Test**
- Take photo of: **Dark clouds** (stormy sky, cloudy weather)
- Or: **Gray/Blue objects** (gray wall, dark blue cloth)
- Or: **Windy scenes** (trees moving, flags)

### ✅ **NO EMERGENCY Test**
- Take photo of: **Normal scenes** (your room, clear sky, everyday objects)
- Or: **Green landscapes** (plants, grass, trees)
- Or: **Regular photos** from your gallery

## Option 2: Test with Gallery Photos 📱

Use photos you already have:

1. **Open Emergency Detection screen**
2. **Tap Gallery icon**
3. **Select any photo** from your gallery
4. **Check the result**

Even regular photos can be tested - the AI will classify them as "No Emergency" if they don't match disaster types.

## Option 3: Create Simple Test Images 🎨

I've created a helper that can generate simple colored test images. You can use this in the app:

1. The app can generate test images programmatically
2. These are simple colored images that represent each disaster type
3. They're saved temporarily and can be used for testing

## Quick Test Steps:

1. **Open Emergency Detection screen**
2. **Use Camera or Gallery**
3. **Take/Select a photo** (even simple ones work!)
4. **Wait for classification**
5. **Check the result**

## What to Look For:

✅ **Model loads successfully** (check logs)
✅ **Classification happens** (not stuck)
✅ **Confidence > 0%** (even if low, it's working!)
✅ **Correct disaster type** (or "No Emergency" for normal photos)
✅ **UI shows result** with correct colors
✅ **Can send to chat** with severity colors

## Tips:

- **Start simple**: Test with normal photos first to see "No Emergency"
- **Try different angles**: Same object from different angles
- **Use good lighting**: Better photos = better results
- **Check debug logs**: See what the model is detecting
- **Don't worry about low confidence**: Even 10-20% means it's working!

## Expected Results:

- **Normal photos** → "No Emergency" (Low severity, Green color)
- **Water/Blue photos** → May detect "Flood" (even if low confidence)
- **Fire/Orange photos** → May detect "Wildfire"
- **Cracked/Damaged** → May detect "Earthquake"
- **Dark clouds** → May detect "Cyclone"

**Remember**: The model was trained on real disaster images, so simple everyday photos might have lower confidence. That's normal! The important thing is that it's classifying and not stuck at 0%.

## Troubleshooting:

**If confidence is 0%:**
- Try a different photo
- Make sure photo is clear
- Check debug logs for raw probabilities
- Even if all probabilities are low, the highest one wins

**If classification seems wrong:**
- The model might be detecting patterns/colors similar to disasters
- This is normal for simple test images
- Real disaster images will have much higher confidence

**If nothing happens:**
- Check if model loaded (look for "✅ Model loaded" in logs)
- Make sure you're using ML classification (not fallback)
- Check debug panel for errors

Happy Testing! 🚀
