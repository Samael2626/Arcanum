#!/bin/bash
# Script para testear Dockerfile localmente ANTES de pusheara Render
# Uso: ./build.sh

set -e

echo "=== Building Render Docker image locally ==="
docker build -f render.dockerfile -t arcanum-api:test .

echo ""
echo "=== Testing swisseph compilation ==="
docker run --rm arcanum-api:test python3 -c "
import swisseph as swe
print(f'✓ swisseph loaded successfully')
print(f'✓ Version: {swe.__version__ if hasattr(swe, \"__version__\") else \"unknown\"}')

# Test basic functionality
jd = 2451545.0  # J2000.0 epoch
result = swe.calc_ut(jd, swe.SUN, swe.FLG_MOSEPH)
print(f'✓ Calculation test passed: Sun at {result[0][0]:.2f}°')
print(f'✓ All checks passed!')
"

echo ""
echo "=== Image ready for Render ==="
echo "Next steps:"
echo "  1. Commit files: git add render.dockerfile render.yaml requirements-render.txt"
echo "  2. Push: git push origin feat/onboarding-5-pasos"
echo "  3. In Render dashboard:"
echo "     - Select project"
echo "     - New Service → Web Service"
echo "     - Connect GitHub repo"
echo "     - Select branch: feat/onboarding-5-pasos"
echo "     - Runtime: Docker (not Python buildpack!)"
echo "     - Dockerfile Path: ./render.dockerfile"
echo "     - Deploy"
