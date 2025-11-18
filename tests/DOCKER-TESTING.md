# Running E2E Tests with Docker

Since the E2E tests require PowerShell 7+ and Pester, Docker provides an isolated and consistent environment for running them.

## Quick Start

### Option 1: Using the Helper Script (Recommended)

```bash
# Run E2E tests in Docker
./tests/run-e2e-docker.sh
```

This script will:
1. Check if Docker is installed
2. Build the Docker image
3. Run the tests
4. Show detailed output
5. Return the exit code

### Option 2: Using Docker Directly

```bash
# Build the image
docker build -f tests/Dockerfile.test -t archive-tovarishestvo-tests .

# Run the tests
docker run --rm archive-tovarishestvo-tests
```

### Option 3: Using Docker Compose

```bash
# Build and run
docker-compose -f tests/docker-compose.test.yml up --build

# Clean up
docker-compose -f tests/docker-compose.test.yml down
```

## Docker Image Details

### Base Image
- **Image**: `mcr.microsoft.com/powershell:7.4-ubuntu-22.04`
- **PowerShell Version**: 7.4
- **OS**: Ubuntu 22.04

### Installed Components
- PowerShell 7.4
- Pester testing framework (latest)

### Container Structure
```
/app/
├── libs/               # PowerShell modules
├── tests/              # Test files
│   └── E2E-ImageProcessing.Tests.ps1
├── config.json
└── *.ps1               # Processing scripts
```

## Advanced Usage

### Run Specific Tests

```bash
# Run only specific test context
docker run --rm archive-tovarishestvo-tests \
  pwsh -Command "Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1 -TestName '*Full End-to-End*'"
```

### Run with Different Output Modes

```bash
# Minimal output
docker run --rm archive-tovarishestvo-tests \
  pwsh -Command "Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1 -Output Minimal"

# Normal output
docker run --rm archive-tovarishestvo-tests \
  pwsh -Command "Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1 -Output Normal"

# Detailed output (default)
docker run --rm archive-tovarishestvo-tests \
  pwsh -Command "Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1 -Output Detailed"
```

### Run All Tests

```bash
# Run all tests in the tests directory
docker run --rm archive-tovarishestvo-tests \
  pwsh -Command "Invoke-Pester ./tests/"
```

### Interactive Shell

```bash
# Open PowerShell shell in container
docker run --rm -it archive-tovarishestvo-tests pwsh

# Then run tests manually:
PS> Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1
```

### Mount Local Code (for Development)

```bash
# Mount current directory to test local changes
docker run --rm -v $(pwd):/app archive-tovarishestvo-tests
```

## CI/CD Integration

### GitHub Actions

See `.github/workflows/e2e-tests.yml` for the CI workflow configuration.

### GitLab CI

```yaml
test:e2e:
  image: mcr.microsoft.com/powershell:7.4-ubuntu-22.04
  before_script:
    - pwsh -Command "Install-Module -Name Pester -Force -SkipPublisherCheck"
  script:
    - pwsh -Command "Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1 -CI"
```

### Azure Pipelines

```yaml
- task: PowerShell@2
  inputs:
    targetType: 'inline'
    script: |
      Install-Module -Name Pester -Force -SkipPublisherCheck
      Invoke-Pester ./tests/E2E-ImageProcessing.Tests.ps1 -CI
```

## Troubleshooting

### Docker Not Found

```bash
# Check if Docker is installed
docker --version

# If not installed, visit: https://docs.docker.com/get-docker/
```

### Permission Denied

```bash
# Add your user to docker group (Linux)
sudo usermod -aG docker $USER
newgrp docker

# Or run with sudo (not recommended)
sudo ./tests/run-e2e-docker.sh
```

### Build Failures

```bash
# Clean up old images
docker rmi archive-tovarishestvo-tests

# Rebuild without cache
docker build --no-cache -f tests/Dockerfile.test -t archive-tovarishestvo-tests .
```

### Network Issues

If you're behind a proxy or firewall:

```bash
# Build with proxy settings
docker build --build-arg HTTP_PROXY=http://proxy:port \
             --build-arg HTTPS_PROXY=http://proxy:port \
             -f tests/Dockerfile.test -t archive-tovarishestvo-tests .
```

## Performance Tips

### Cache Docker Layers

The Dockerfile is optimized to cache Pester installation. If you modify code frequently:

```bash
# Use volume mount instead of rebuilding
docker run --rm -v $(pwd):/app archive-tovarishestvo-tests
```

### Multi-stage Builds (Future)

For production deployments, consider multi-stage builds to reduce image size.

## Cleaning Up

```bash
# Remove the test image
docker rmi archive-tovarishestvo-tests

# Remove all stopped containers
docker container prune

# Remove unused images
docker image prune
```

## Comparison with Local Execution

| Aspect | Docker | Local PowerShell |
|--------|--------|------------------|
| Setup | Build image once | Install PowerShell + Pester |
| Consistency | ✅ Identical everywhere | ⚠️ Depends on local setup |
| Speed | Slower (container overhead) | Faster (native) |
| Isolation | ✅ Fully isolated | ❌ Uses local environment |
| CI/CD | ✅ Easy integration | ⚠️ Requires agent setup |

## Related Files

- `tests/Dockerfile.test` - Docker image definition
- `tests/docker-compose.test.yml` - Docker Compose configuration
- `tests/run-e2e-docker.sh` - Helper script for running tests
- `tests/E2E-ImageProcessing.Tests.ps1` - The actual test suite
- `tests/E2E-ImageProcessing.README.md` - Test documentation

## Next Steps

After running tests successfully:
1. Review test output for any failures
2. Check code coverage (if configured)
3. Update tests as needed
4. Commit changes and push to repository
