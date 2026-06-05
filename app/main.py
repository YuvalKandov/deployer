import socket
import time
from datetime import datetime, timezone

from flask import Flask, jsonify, request

from app.metrics import init_metrics

APP_VERSION = "0.1.0"
START_TIME = time.monotonic()

app = Flask(__name__)
init_metrics(app)


@app.get("/health")
def health():
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    })


@app.get("/info")
def info():
    return jsonify({
        "version": APP_VERSION,
        "uptime_seconds": round(time.monotonic() - START_TIME, 2),
        "hostname": socket.gethostname(),
    })


@app.post("/process")
def process():
    payload = request.get_json(silent=True) or {}
    text = payload.get("text")
    if not isinstance(text, str):
        return jsonify({"error": "field 'text' must be a string"}), 400

    return jsonify({
        "reversed": text[::-1],
        "char_count": len(text),
        "word_count": len(text.split()),
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
