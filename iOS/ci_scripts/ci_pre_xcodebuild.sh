#!/bin/sh

# ci_pre_xcodebuild.sh
# Environment variable validation before build

echo "Checking environment variables..."

# Check REVENUECAT_API_KEY (required)
if [ -z "$REVENUECAT_API_KEY" ]; then
    echo "❌ REVENUECAT_API_KEY is not configured"
    exit 1
else
    echo "✅ REVENUECAT_API_KEY is configured"
fi

# Check ADMOB_BANNER_ID (required)
if [ -z "$ADMOB_BANNER_ID" ]; then
    echo "❌ ADMOB_BANNER_ID is not configured"
    exit 1
else
    echo "✅ ADMOB_BANNER_ID is configured"
fi

# Check AUDIO_API_BASE_URL (optional - warn only)
if [ -z "$AUDIO_API_BASE_URL" ]; then
    echo "⚠️  AUDIO_API_BASE_URL is not configured (optional)"
else
    echo "✅ AUDIO_API_BASE_URL is configured: $AUDIO_API_BASE_URL"
fi

echo "Environment check completed successfully."
