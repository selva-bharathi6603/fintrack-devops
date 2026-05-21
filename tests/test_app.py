import pytest
import json
import sys
import os
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../app"))

os.environ["DB_PATH"] = os.path.join(tempfile.gettempdir(), "fintrack_test.db")

from app import app, init_db


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        with app.app_context():
            init_db()
        yield client


def test_health_endpoint(client):
    res = client.get("/health")
    assert res.status_code == 200
    data = json.loads(res.data)
    assert data["status"] == "healthy"


def test_index_loads(client):
    res = client.get("/")
    assert res.status_code == 200
    assert b"FinTrack" in res.data


def test_add_income(client):
    payload = {
        "type": "income",
        "category": "Salary",
        "amount": 50000,
        "description": "Monthly salary",
        "date": "2024-01-15",
    }
    res = client.post(
        "/add",
        data=json.dumps(payload),
        content_type="application/json",
    )
    assert res.status_code == 201
    data = json.loads(res.data)
    assert data["message"] == "Transaction added"


def test_add_expense(client):
    payload = {
        "type": "expense",
        "category": "Food",
        "amount": 1500,
        "description": "Groceries",
        "date": "2024-01-16",
    }
    res = client.post(
        "/add",
        data=json.dumps(payload),
        content_type="application/json",
    )
    assert res.status_code == 201


def test_add_invalid_type(client):
    payload = {"type": "invalid", "category": "Food", "amount": 100, "date": "2024-01-16"}
    res = client.post(
        "/add",
        data=json.dumps(payload),
        content_type="application/json",
    )
    assert res.status_code == 400


def test_add_zero_amount(client):
    payload = {"type": "expense", "category": "Food", "amount": 0, "date": "2024-01-16"}
    res = client.post(
        "/add",
        data=json.dumps(payload),
        content_type="application/json",
    )
    assert res.status_code == 400


def test_summary_endpoint(client):
    res = client.get("/api/summary")
    assert res.status_code == 200
    assert isinstance(json.loads(res.data), list)


def test_delete_transaction(client):
    payload = {
        "type": "income",
        "category": "Freelance",
        "amount": 10000,
        "description": "Project payment",
        "date": "2024-01-20",
    }
    client.post("/add", data=json.dumps(payload), content_type="application/json")
    res = client.delete("/delete/1")
    assert res.status_code == 200


def test_metrics_endpoint(client):
    res = client.get("/metrics")
    assert res.status_code == 200
    assert b"flask_http_request_total" in res.data
