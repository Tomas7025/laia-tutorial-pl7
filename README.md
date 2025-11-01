# ML Pipeline in Production - Iris Classification

A production-ready ML pipeline demonstrating MLOps best practices for deploying and managing machine learning models.

## 🎓 For Students

**👉 Read [TUTORIAL.md](TUTORIAL.md) - Deep dive into CI/CD for ML systems!**

This project demonstrates an automated deployment of ML models. The tutorial focuses on:
- **CI/CD Pipeline**: Step-by-step explanation of each job
- **GitHub Actions**: How automated testing and deployment works
- **Best practices**: Caching, secrets, multi-platform builds
- **Discussion topics**: Trade-offs and real-world considerations

## 🚀 Quick Start

### Local Development (with local MLflow)

```bash
# Start the entire stack
docker-compose up --build

# In another terminal, train a model
pip install uv
uv sync
uv run python tests/train_ci.py

# Access services
# MLflow UI: http://localhost:5050
# Flask API: http://localhost:8080
```

### Using Remote MLflow

```bash
# Set credentials
export MLFLOW_USERNAME=your_username
export MLFLOW_PASSWORD=your_password

# Start Flask app only
docker-compose -f docker-compose.remote.yml up --build
```

### Using Pre-built Images from CI/CD

After pushing to `main`, the CI/CD pipeline builds and publishes images to GitHub Container Registry:

```bash
# Pull the latest staging image
docker pull ghcr.io/<your-github-username>/laia-tutorial/flask-app:staging

# Run with remote MLflow
docker run -d \
  --name flask_app \
  -p 8080:8080 \
  -e MLFLOW_TRACKING_URI=http://dsn2026hotcrp.dei.uc.pt:8080 \
  -e MLFLOW_TRACKING_USERNAME=your_username \
  -e MLFLOW_TRACKING_PASSWORD=your_password \
  ghcr.io/<your-github-username>/laia-tutorial/flask-app:staging
```

**Available tags**: `staging` (latest), `main` (branch), `main-<sha>` (specific commit)

## 📁 Project Structure

```
.
├── app.py                      # Flask API for serving predictions
├── train.py                    # Training script (development)
├── docker-compose.yml          # Local stack (MLflow + Flask)
├── docker-compose.remote.yml   # Remote MLflow config
├── Dockerfile.flask            # Flask container
├── Dockerfile.mlflow           # MLflow container
├── .github/workflows/ci-cd.yml # CI/CD pipeline ⭐
├── tests/
│   ├── train_ci.py            # Training script (CI/CD)
│   ├── test_api.py            # Unit tests for API
│   ├── test_train.py          # Unit tests for training
│   └── test_e2e.py            # End-to-end tests
├── pyproject.toml             # Python dependencies
└── TUTORIAL.md                # CI/CD pipeline tutorial ⭐
```

## 🔧 API Endpoints

### Health Check
```bash
curl http://localhost:8080/health
```

### Make Prediction
```bash
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{
    "data": [[5.1, 3.5, 1.4, 0.2]],
    "columns": ["sepal_length", "sepal_width", "petal_length", "petal_width"]
  }'
```

### Reload Model
```bash
curl -X POST http://localhost:8080/reload
```

## 🧪 Testing

```bash
# Install dependencies
uv sync

# Run unit tests
uv run pytest tests/test_api.py tests/test_train.py -v

# Run E2E tests (requires running services)
docker-compose -f docker-compose.remote.yml up -d
uv run pytest tests/test_e2e.py -v
docker-compose -f docker-compose.remote.yml down
```

## 🏗️ Architecture

```
Training → MLflow (Experiments/Models) → Flask API → Predictions
    ↓                                          ↑
 CI/CD Pipeline ────────────────────────────────┘
```

**Components:**
- **Training**: scikit-learn with hyperparameter tuning
- **Tracking**: MLflow for experiments and model registry
- **Serving**: Flask REST API
- **Testing**: pytest (unit, integration, E2E)
- **CI/CD**: GitHub Actions
- **Deployment**: Docker containers

## 🔄 CI/CD Pipeline

**Automated on every push to `main` (~10 minutes)**

```
1. Unit Tests       → Verify code works (30s)
2. Build Image      → Create Docker container (2min)
3. Train Model      → Register to MLflow (3min)
4. E2E Tests        → Test complete system (1min)
5. Push to Registry → Deploy to staging (3min)
```

**Result**: Multi-platform image (AMD64 + ARM64) in GitHub Container Registry

**📖 See [TUTORIAL.md](TUTORIAL.md) for detailed explanation of each step**

## 📊 MLflow Model Registry

Models go through stages:
- **None** → Newly registered
- **Staging** → Ready for testing
- **Production** → Serving traffic
- **Archived** → Deprecated

The Flask app loads models from the **Production** stage.

## 🎯 Key Concepts Demonstrated

✅ Experiment tracking  
✅ Model versioning and registry  
✅ REST API for inference  
✅ Containerization  
✅ Automated testing (unit, integration, E2E)  
✅ CI/CD for ML workflows  
✅ Remote ML infrastructure  
✅ Model lifecycle management  

## 🛠️ Technology Stack

| Category | Technology |
|----------|-----------|
| **ML Framework** | scikit-learn |
| **Experiment Tracking** | MLflow |
| **API Framework** | Flask |
| **Containerization** | Docker, Docker Compose |
| **CI/CD** | GitHub Actions |
| **Testing** | pytest |
| **Package Manager** | uv |
| **Language** | Python 3.13 |

## 🔐 Environment Variables

### Flask App
```bash
MLFLOW_TRACKING_URI=http://localhost:5050
MLFLOW_TRACKING_USERNAME=user1
MLFLOW_TRACKING_PASSWORD=password
```

### Training Scripts
```bash
MLFLOW_TRACKING_URI=http://dsn2026hotcrp.dei.uc.pt:8080
MLFLOW_TRACKING_USERNAME=user1
MLFLOW_TRACKING_PASSWORD=password
```

## 📚 Learning Resources

- **[TUTORIAL.md](TUTORIAL.md)** - CI/CD pipeline deep dive
- **[GitHub Actions Docs](https://docs.github.com/en/actions)** - Workflow automation
- **[MLflow Docs](https://mlflow.org/docs/latest/index.html)** - Experiment tracking
- **[Docker Build Docs](https://docs.docker.com/build/)** - Multi-platform builds

---

**Happy Learning! 🚀**

For step-by-step CI/CD pipeline explanation, see [TUTORIAL.md](TUTORIAL.md)

