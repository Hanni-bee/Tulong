# AI Classification Testing Guide

## Model Information
Your model classifies images into **4 disaster types**:
- **Cyclone** (Index 0) - Hurricanes, typhoons, tornadoes
- **Earthquake** (Index 1) - Building damage, cracks, collapsed structures
- **Flood** (Index 2) - Water, flooded areas, submerged objects
- **Wildfire** (Index 3) - Fire, smoke, burned areas

## Best Test Images for Each Category

### 🌪️ **Cyclone/Tornado Images**
**What to look for:**
- Dark storm clouds
- Tornado funnel clouds
- Hurricane satellite images
- Wind damage (trees bent, debris)
- Stormy weather scenes

**Where to find test images:**
- Search: "tornado image", "hurricane satellite", "cyclone weather"
- News websites (weather sections)
- Stock photo sites (free): Unsplash, Pexels, Pixabay
- Search terms: "tornado", "hurricane", "typhoon", "cyclone"

### 🌍 **Earthquake Images**
**What to look for:**
- Cracked buildings/walls
- Collapsed structures
- Damaged roads with cracks
- Rubble and debris
- Buildings leaning or damaged

**Where to find test images:**
- Search: "earthquake damage", "cracked building", "collapsed structure"
- News websites (disaster sections)
- Stock photo sites
- Search terms: "earthquake damage", "building collapse", "cracked wall"

### 🌧️ **Flood Images**
**What to look for:**
- Water covering streets/roads
- Flooded houses/buildings
- Submerged vehicles
- Waterlogged areas
- Rivers overflowing

**Where to find test images:**
- Search: "flooded street", "flood damage", "water flood"
- News websites
- Stock photo sites
- Search terms: "flood", "flooded area", "water damage", "submerged"

### 🔥 **Wildfire Images**
**What to look for:**
- Fire flames
- Smoke and burning areas
- Burned forests/vegetation
- Firefighters battling fires
- Charred landscapes

**Where to find test images:**
- Search: "wildfire", "forest fire", "burning fire"
- News websites
- Stock photo sites
- Search terms: "wildfire", "forest fire", "fire damage", "burning"

### ✅ **No Emergency Images** (Should return "No Emergency")
**What to look for:**
- Normal landscapes
- Clear skies
- Peaceful scenes
- Regular buildings (no damage)
- Everyday scenes (parks, streets, buildings)

**Where to find test images:**
- Any normal photo from your gallery
- Stock photo sites (search: "normal landscape", "peaceful scene")
- Your own photos

## How to Test in the App

### Step 1: Prepare Test Images
1. Download or save test images to your phone's gallery
2. Make sure images are clear and show the disaster type clearly
3. For best results, use images that clearly show the disaster (not ambiguous)

### Step 2: Test Each Category
1. Open the Emergency Detection screen
2. Tap the gallery icon or camera button
3. Select a test image
4. Wait for classification (check debug logs)
5. Verify the result matches the image type

### Step 3: Check Debug Logs
Look for these logs in your console:
```
🔍 Using ML classification
📊 Raw Model Output:
   Cyclone: 0.123456
   Earthquake: 0.234567
   Flood: 0.345678
   Wildfire: 0.296299
✅ Post-processing complete:
   Detected: Flood
   Confidence: 34.57%
```

### Step 4: Verify Results
- **Correct Classification**: Model detects the right disaster type
- **High Confidence**: Should be > 30% for clear images
- **UI Display**: Check if severity colors are correct
- **Chat Message**: Verify message is sent with correct severity

## Quick Test Checklist

- [ ] Test with a **Flood** image → Should detect "Flood"
- [ ] Test with a **Wildfire** image → Should detect "Wildfire"
- [ ] Test with an **Earthquake** image → Should detect "Earthquake"
- [ ] Test with a **Cyclone** image → Should detect "Cyclone"
- [ ] Test with a **normal** image → Should detect "No Emergency"
- [ ] Verify confidence > 0% for clear disaster images
- [ ] Check severity colors in chat (green for low, orange for medium, etc.)
- [ ] Verify chat message is sendable

## Troubleshooting Low Confidence (0%)

If you're getting 0% confidence:

1. **Check Image Quality**
   - Image should be clear and not blurry
   - Disaster should be clearly visible
   - Avoid images that are too dark or too bright

2. **Check Model Output**
   - Look at debug logs for raw probabilities
   - All 4 classes should have some probability (even if small)
   - Highest probability should be > 0.3 for clear images

3. **Verify Preprocessing**
   - Image should be resized to 224x224
   - Pixel values normalized to 0-1 range
   - Check logs: "✅ Preprocessing complete"

4. **Test with Different Images**
   - Try images from different sources
   - Use images that clearly show the disaster
   - Avoid ambiguous or mixed scenes

## Sample Test Image Sources

### Free Stock Photo Sites:
- **Unsplash**: https://unsplash.com (search: "flood", "wildfire", "earthquake", "tornado")
- **Pexels**: https://pexels.com (search disaster types)
- **Pixabay**: https://pixabay.com (free images)

### Search Terms for Each Category:
- **Flood**: "flooded street", "water damage", "flood disaster"
- **Wildfire**: "forest fire", "wildfire", "burning forest"
- **Earthquake**: "earthquake damage", "collapsed building", "cracked wall"
- **Cyclone**: "tornado", "hurricane", "typhoon", "cyclone"

## Expected Results

### Good Test Image (High Confidence):
- Clear disaster visible in image
- Single disaster type dominant
- Good lighting and clarity
- **Expected confidence: 40-90%**

### Average Test Image (Medium Confidence):
- Disaster visible but not dominant
- Some ambiguity
- **Expected confidence: 30-50%**

### Poor Test Image (Low Confidence):
- Unclear or ambiguous
- Multiple disaster types or none
- Poor quality
- **Expected confidence: < 30% → May show "No Emergency"**

## Next Steps

1. **Download test images** from the sources above
2. **Test each disaster type** systematically
3. **Check debug logs** to see raw probabilities
4. **Verify UI** shows correct colors and severity
5. **Test chat functionality** to ensure messages are sent correctly

Good luck with testing! 🚀
