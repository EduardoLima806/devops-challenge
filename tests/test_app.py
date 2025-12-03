"""
Unit tests for the FastAPI application
"""
import pytest
import os
import sys
from pathlib import Path

# Add parent directory to path to import app
sys.path.insert(0, str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient
from app import app

client = TestClient(app)


def test_health_endpoint():
    """Test the health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data


def test_health_endpoint_with_version():
    """Test health endpoint with custom version"""
    os.environ["APP_VERSION"] = "2.0.0"
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["version"] == "2.0.0"
    del os.environ["APP_VERSION"]


def test_hello_endpoint():
    """Test the hello endpoint"""
    response = client.get("/api/hello")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "environment" in data
    assert data["message"] == "Hello from Eloquent AI!"


def test_hello_endpoint_with_environment():
    """Test hello endpoint with custom environment"""
    os.environ["ENVIRONMENT"] = "test"
    response = client.get("/api/hello")
    assert response.status_code == 200
    data = response.json()
    assert data["environment"] == "test"
    del os.environ["ENVIRONMENT"]


def test_nonexistent_endpoint():
    """Test that nonexistent endpoints return 404"""
    response = client.get("/nonexistent")
    assert response.status_code == 404

