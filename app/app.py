from flask import Flask, render_template, request, jsonify
from prometheus_flask_exporter import PrometheusMetrics
import sqlite3
import os
import datetime

app = Flask(__name__)
metrics = PrometheusMetrics(app)

metrics.info("fintrack_app_info", "FinTrack Application Info", version="1.0.0")

DB_PATH = os.environ.get("DB_PATH", "/tmp/fintrack.db")


def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("""
        CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            amount REAL NOT NULL,
            description TEXT,
            date TEXT NOT NULL
        )
    """)
    conn.commit()
    conn.close()


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


@app.route("/")
def index():
    conn = get_db()
    transactions = conn.execute(
        "SELECT * FROM transactions ORDER BY date DESC LIMIT 10"
    ).fetchall()

    totals = conn.execute("""
        SELECT
            COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0) as total_income,
            COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0) as total_expense
        FROM transactions
    """).fetchone()
    conn.close()

    balance = totals["total_income"] - totals["total_expense"]
    return render_template(
        "index.html",
        transactions=transactions,
        total_income=totals["total_income"],
        total_expense=totals["total_expense"],
        balance=balance,
    )


@app.route("/add", methods=["POST"])
def add_transaction():
    data = request.get_json()
    txn_type = data.get("type")
    category = data.get("category")
    amount = float(data.get("amount", 0))
    description = data.get("description", "")
    date = data.get("date", datetime.date.today().isoformat())

    if txn_type not in ("income", "expense") or amount <= 0:
        return jsonify({"error": "Invalid input"}), 400

    conn = get_db()
    conn.execute(
        "INSERT INTO transactions (type, category, amount, description, date) VALUES (?,?,?,?,?)",
        (txn_type, category, amount, description, date),
    )
    conn.commit()
    conn.close()
    return jsonify({"message": "Transaction added"}), 201


@app.route("/delete/<int:txn_id>", methods=["DELETE"])
def delete_transaction(txn_id):
    conn = get_db()
    conn.execute("DELETE FROM transactions WHERE id=?", (txn_id,))
    conn.commit()
    conn.close()
    return jsonify({"message": "Deleted"}), 200


@app.route("/api/summary")
def summary():
    conn = get_db()
    rows = conn.execute("""
        SELECT category, type, SUM(amount) as total
        FROM transactions
        GROUP BY category, type
    """).fetchall()
    conn.close()
    return jsonify([dict(r) for r in rows])


@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
