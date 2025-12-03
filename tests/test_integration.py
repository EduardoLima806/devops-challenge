"""
Integration tests for the FastAPI application
"""
import pytest
import sys
from pathlib import Path

# Add parent directory to path to import app
sys.path.insert(0, str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient
from app import app

client = TestClient(app)


def test_health_and_hello_workflow():
    """Integration test: verify health and hello endpoints work together"""
    # First check health
    health_response = client.get("/health")
    assert health_response.status_code == 200
    health_data = health_response.json()
    assert health_data["status"] == "healthy"
    
    # Then check hello
    hello_response = client.get("/api/hello")
    assert hello_response.status_code == 200
    hello_data = hello_response.json()
    assert "message" in hello_data


def test_response_format():
    """Test that all endpoints return proper JSON format"""
    endpoints = ["/health", "/api/hello"]
    
    for endpoint in endpoints:
        response = client.get(endpoint)
        assert response.status_code == 200
        assert response.headers["content-type"] == "application/json"
        data = response.json()
        assert isinstance(data, dict)

