#!/bin/sh

# ci_pre_xcodebuild.sh
# Environment variable validation before build

echo "Checking required environment variables..."

# Check AUDIO_API_BASE_URL
if [ -z "$AUDIO_API_BASE_URL" ]; then
    echo "error: AUDIO_API_BASE_URL is not configured."
    echo "Please set AUDIO_API_BASE_URL in your .xcconfig file:"
    echo "  Debug.xcconfig or Release.xcconfig"
    exit 1
fi

echo "✅ AUDIO_API_BASE_URL is configured: $AUDIO_API_BASE_URL"

# Validate URL format
if [[ ! "$AUDIO_API_BASE_URL" =~ ^https?:// ]]; then
    echo "warning: AUDIO_API_BASE_URL should start with http:// or https://"
fi

echo "Environment variables check completed successfully."