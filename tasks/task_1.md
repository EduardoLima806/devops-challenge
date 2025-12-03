You are a DevOps Engineer. You will create a simple Python web application to deploy to AWS ECS using infrastructure as code and automated CI/CD pipelines.

Be concerned about these topics (I will provide instructions later):

- Terraform code quality and best practices
- CI/CD pipeline design and implementation
- AWS architecture decisions
- Security consciousness
- Documentation and communication

Initially I've provided a simple Python FastAPI application that exposes a health check endpoint
and a basic API. Your task is create the first application strucuture inside in this existing folder called devops-challenge (don't create anything outsie of this folder) aims to deploy the app to AWS.

### Application Code (save as app.py):

```python
from fastapi import FastAPI
from fastapi.responses import JSONResponse
import os

app = FastAPI()

@app.get("/health")
def health():
    return JSONResponse(content={"status": "healthy","version": os.getenv("APP_VERSION", "1.0.0")})

@app.get("/api/hello")
def hello():
    return JSONResponse(content={"message": "Hello from Eloquent AI!", "environment": os.getenv("ENVIRONMENT","unknown")})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)

```