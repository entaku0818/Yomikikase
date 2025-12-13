#!/bin/sh

# ci_pre_xcodebuild.sh
# Environment variable validation before build

echo "Checking environment variables..."

# Check AUDIO_API_BASE_URL (optional - warn only)
if [ -z "$AUDIO_API_BASE_URL" ]; then
    echo "⚠️  AUDIO_API_BASE_URL is not configured (optional)"
else
    echo "✅ AUDIO_API_BASE_URL is configured: $AUDIO_API_BASE_URL"
fi

echo "Environment check completed successfully."
