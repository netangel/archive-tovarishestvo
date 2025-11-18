#!/bin/bash
# Script to run E2E tests in Docker container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "======================================"
echo "E2E Tests - Docker Runner"
echo "======================================"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    echo "   Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

echo "✅ Docker is available"
echo ""

# Build the Docker image
echo "📦 Building Docker image..."
docker build -f "$SCRIPT_DIR/Dockerfile.test" -t archive-tovarishestvo-tests "$PROJECT_ROOT"

if [ $? -ne 0 ]; then
    echo "❌ Failed to build Docker image"
    exit 1
fi

echo "✅ Docker image built successfully"
echo ""

# Run the tests
echo "🧪 Running E2E tests in Docker container..."
echo "======================================"
echo ""

docker run --rm archive-tovarishestvo-tests

TEST_EXIT_CODE=$?

echo ""
echo "======================================"
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ Tests completed successfully!"
else
    echo "❌ Tests failed with exit code: $TEST_EXIT_CODE"
fi
echo "======================================"

exit $TEST_EXIT_CODE
