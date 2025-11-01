# CI/CD Pipeline for ML Systems - Tutorial

This tutorial explains each step of a CI/CD pipeline that automatically tests, builds, trains, and deploys machine learning models to production.

---

## 🎯 Pipeline Overview

Automatically on every push to `main`:

```
1. Unit Tests       → Verify code works
2. Build Image      → Create Docker container
3. Train Model      → Register to MLflow
4. E2E Tests        → Test complete system
5. Push to Registry → Deploy to staging
```

**Time**: ~10 minutes | **File**: `.github/workflows/ci-cd.yml`

**Key Principle**: Each job depends on the previous one. If any fails, pipeline stops.

---

## Job 1: Unit Tests

**Purpose**: Fast feedback on code correctness

### What Happens

```yaml
- name: Checkout code
  uses: actions/checkout@v4
```
Downloads your code to GitHub runner

```yaml
- name: Set up Python
  uses: actions/setup-python@v5
  with:
    python-version: '3.13'
```
Installs Python environment

```yaml
- name: Install dependencies
  run: uv sync
```
Installs pytest, sklearn, mlflow, flask from `pyproject.toml`

```yaml
- name: Run tests
  run: |
    uv run pytest tests/test_api.py -v
    uv run pytest tests/test_train.py -v
```
Runs unit tests separately for API and training code

### Why This Matters
- **Fast**: Runs in ~30 seconds
- **Cheap**: No Docker building or model training
- **Early feedback**: Catch bugs before expensive operations

**If fails**: Pipeline stops immediately

---

## Job 2: Build Docker Image

**Purpose**: Create container image and save for testing

### What Happens

```yaml
needs: test-unit  # Waits for Job 1
```

```yaml
- name: Build Flask image
  uses: docker/build-push-action@v5
  with:
    context: .
    file: ./Dockerfile.flask
    platforms: linux/amd64
    push: false
    tags: flask-app:${{ github.sha }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
    outputs: type=docker,dest=/tmp/flask-app.tar
```

**Key Parameters**:
- `push: false` - Don't push yet, test first
- `tags: flask-app:${{ github.sha }}` - Unique tag per commit
- `cache-from/to: type=gha` - Reuse layers (5 min → 30 sec)
- `outputs: type=docker,dest=/tmp/flask-app.tar` - Save as file

```yaml
- name: Upload artifact
  uses: actions/upload-artifact@v4
  with:
    name: flask-app-image
    path: /tmp/flask-app.tar
    retention-days: 1
```
Shares image with next jobs (deleted after 1 day)

### Why This Matters
- **Efficient**: Caching makes rebuilds fast
- **Safe**: Build once, test before pushing
- **Traceable**: Git SHA in tag enables rollback

**If fails**: Build error (missing dependencies, Dockerfile syntax)

---

## Job 3: Train Model

**Purpose**: Validate training code and register model

### What Happens

```yaml
needs: build-images  # Waits for Job 2
```

```yaml
- name: Train model
  env:
    MLFLOW_TRACKING_URI: http://dsn2026hotcrp.dei.uc.pt:8080
    MLFLOW_TRACKING_USERNAME: ${{ secrets.MLFLOW_USERNAME }}
    MLFLOW_TRACKING_PASSWORD: ${{ secrets.MLFLOW_PASSWORD }}
  run: uv run python tests/train_ci.py
```

**What the script does**:
1. Trains 3 models with different hyperparameters (C=0.1, 1.0, 10.0)
2. Logs metrics to remote MLflow server
3. Registers best model
4. Transitions to "Staging" stage

**Secrets**: Stored in GitHub → Settings → Secrets → Actions (never shown in logs)

```yaml
- name: Save metadata
  run: echo "Training completed at $(date)" > training_metadata.txt

- name: Upload artifact
  uses: actions/upload-artifact@v4
  with:
    name: training-metadata
    retention-days: 7
```
Saves training info for 7 days

### Why This Matters
- **Validates**: Training code always works
- **Documents**: Model versions tracked in MLflow
- **Tests integration**: Verifies MLflow connection

**Trade-off**: Adds 3+ minutes to pipeline

**If fails**: Training broken, MLflow connection issue, or auth problem

---

## Job 4: End-to-End Tests

**Purpose**: Final quality gate - test everything together

### What Happens

```yaml
needs: train-model  # Waits for Job 3
```

```yaml
- name: Download image
  uses: actions/download-artifact@v4
  with:
    name: flask-app-image
```
Gets Docker image from Job 2

```yaml
- name: Load image
  run: docker load --input /tmp/flask-app.tar
```
Makes image available to Docker

```yaml
- name: Start Flask app
  run: |
    docker run -d \
      --name flask-e2e \
      -p 8080:8080 \
      -e MLFLOW_TRACKING_URI=${{ env.MLFLOW_TRACKING_URI }} \
      -e MLFLOW_TRACKING_USERNAME=${{ secrets.MLFLOW_USERNAME }} \
      -e MLFLOW_TRACKING_PASSWORD=${{ secrets.MLFLOW_PASSWORD }} \
      flask-app:${{ github.sha }}
    
    sleep 10
```
Starts container and waits for app to be ready

```yaml
- name: Run E2E tests
  run: uv run pytest tests/test_e2e.py -v
```
Tests health endpoint, predictions, and error handling

```yaml
- name: Cleanup
  if: always()
  run: docker stop flask-e2e && docker rm flask-e2e
```
Always cleanup containers (even on failure)

### Why This Matters
- **Comprehensive**: Tests Docker + Flask + MLflow + Model integration
- **Realistic**: Same environment as production
- **Safety gate**: Last check before deployment

**If fails**: Container won't start, model not loading, or API broken

---

## Job 5: Push to Registry

**Purpose**: Deploy tested image to production registry

### What Happens

```yaml
needs: test-e2e
if: github.ref == 'refs/heads/main'
```
Only runs if E2E passed AND on main branch

```yaml
- name: Login to registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```
Authenticates with GitHub Container Registry (GITHUB_TOKEN is automatic)

```yaml
- name: Extract metadata
  id: meta
  uses: docker/metadata-action@v5
  with:
    images: ghcr.io/${{ github.repository }}/flask-app
    tags: |
      type=ref,event=branch
      type=sha,prefix={{branch}}-
      type=raw,value=staging,enable={{is_default_branch}}
```

**Creates 3 tags**:
- `main` - branch name
- `main-abc123def` - branch + commit SHA (for rollback)
- `staging` - always points to latest (main branch only)

```yaml
- name: Build and push
  uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64
    push: true
    tags: ${{ steps.meta.outputs.tags }}
    cache-from: type=gha
```

**Key differences from Job 2**:
- `platforms: linux/amd64,linux/arm64` - Both Intel and ARM (Apple Silicon)
- `push: true` - Actually push this time!

### Why This Matters
- **Multi-platform**: Works on servers (AMD64) and Mac M1/M2 (ARM64)
- **Versioned**: Every deployment traceable via git SHA
- **Safe**: Only deploys if all tests passed

**If fails**: Auth failed, network issue, or storage quota exceeded

---

## 🎯 Key Concepts

### 1. Job Dependencies
```yaml
job3:
  needs: job2  # job3 waits for job2 to succeed
```
Pipeline stops at first failure - don't waste resources

### 2. Artifacts
Share files between jobs:
- Docker image: Job 2 → Job 4
- Training metadata: Job 3 → Job 5

Alternative would be rebuilding in each job (wasteful)

### 3. Caching
```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```
Reuses Docker layers: **5 min build → 30 sec build**

### 4. Secrets
```yaml
${{ secrets.MLFLOW_PASSWORD }}
```
Stored securely, never shown in logs. Set in repo Settings → Secrets → Actions

### 5. Conditional Execution
```yaml
if: github.ref == 'refs/heads/main'
```
Different behavior for PRs vs main branch

---

## 💬 Discussion Topics

### Should training be in CI/CD?

**For**:
- Ensures training code works
- Generates model for E2E tests
- Validates MLflow integration

**Against**:
- Slow (adds 3+ minutes)
- Expensive compute
- Not needed for every commit

**Real-world**: Small projects train in CI/CD. Large models use separate training pipelines.

### How to speed up the pipeline?

Current: ~10 minutes

**Optimizations**:
1. Parallel jobs (where no dependencies)
2. Smaller base images (`python:3.13-slim`)
3. Skip training on non-training changes (path filters)
4. Better caching (pip dependencies, test data)
5. Self-hosted runners (faster hardware)

### When to deploy automatically?

**Auto deploy**:
- ✅ Web apps with rollback
- ✅ Internal tools
- ✅ Good test coverage

**Manual approval**:
- ⚠️ Financial/healthcare systems
- ⚠️ Compliance requirements
- ⚠️ High downtime cost

**Hybrid**: Auto to staging, manual to production

---

## 🐛 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Artifact not found" | Job 2 failed or artifact expired | Check Job 2 succeeded, verify names match |
| E2E tests timeout | Flask not starting | Increase sleep, check MLflow credentials |
| "403 Forbidden" on push | No registry permissions | Enable "Read and write" in Actions settings |
| Cache not working | Branch changed or expired | Cache is per-branch, 7-day expiry |
| Secrets empty | Not configured | Add in Settings → Secrets → Actions (case-sensitive) |

---

## 🚀 What's Missing?

This pipeline is production-ready but could add:

1. **Security scanning** - `trivy-action` for vulnerabilities
2. **Linting** - `ruff` or `black` for code quality
3. **Performance tests** - Check prediction latency
4. **Notifications** - Slack/email on failure
5. **Rollback** - Auto-rollback on health check failure
6. **Production deploy** - Manual approval gate

**Advanced patterns**:
- Blue-green deployment (zero downtime)
- Canary deployment (gradual rollout)
- Feature flags (toggle without deploy)
- Model monitoring (data drift alerts)

---

## 📊 Complete Flow

```
Developer pushes to main
         ↓
GitHub Actions triggered
         ↓
Job 1: Unit tests (30s)
         ↓
Job 2: Build image (2min)
         ↓
Job 3: Train model (3min)
         ↓
Job 4: E2E tests (1min)
         ↓
Job 5: Push to registry (3min)
         ↓
✅ Image available at:
   ghcr.io/<user>/laia-tutorial/flask-app:staging
```

**Total**: ~10 minutes from push to production-ready deployment

**Artifacts created**:
- Docker image (AMD64 + ARM64) in GitHub Container Registry
- 3 experiment runs in MLflow with metrics
- Registered model in "Staging" stage
- Training metadata and logs

---

**Questions? Discuss with your instructor!**
