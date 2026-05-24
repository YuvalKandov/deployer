import pytest

from app.main import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "healthy"
    assert "timestamp" in data


def test_info(client):
    response = client.get("/info")
    assert response.status_code == 200
    data = response.get_json()
    assert data["version"]
    assert data["uptime_seconds"] >= 0
    assert data["hostname"]


def test_process_valid(client):
    response = client.post("/process", json={"text": "hello world"})
    assert response.status_code == 200
    data = response.get_json()
    assert data["reversed"] == "dlrow olleh"
    assert data["char_count"] == 11
    assert data["word_count"] == 2


def test_process_missing_text(client):
    response = client.post("/process", json={})
    assert response.status_code == 400
    assert "error" in response.get_json()


def test_process_text_not_string(client):
    response = client.post("/process", json={"text": 42})
    assert response.status_code == 400
