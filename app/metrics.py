"""Prometheus instrumentation for the Flask app.

We MEASURE and EXPOSE here; Prometheus COLLECTS and STORES by scraping /metrics.
The app never opens a connection to Prometheus — it only publishes numbers.
"""

import time

from flask import Response, request
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)

# --- Metric definitions (module-level: created ONCE, registered globally) ---
# These objects live in the default registry. Defining them at import time
# means there is exactly one of each — re-defining would raise a duplicate error.

# Counter: monotonically increasing. Answers "how many requests, ever?"
# (and via rate() in PromQL, "how many per second?"). Labels let us slice by
# method/endpoint/status without creating a separate metric for each combo.
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests served.",
    ["method", "endpoint", "http_status"],
)

# Histogram: buckets observations so we can compute percentiles (p50/p95/p99
# latency) in PromQL. Answers "what's the distribution of request durations?"
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds.",
    ["method", "endpoint"],
)

# Gauge: goes up AND down. Answers "how many requests are in flight RIGHT NOW?"
REQUESTS_IN_PROGRESS = Gauge(
    "http_requests_in_progress",
    "HTTP requests currently being processed.",
    ["method", "endpoint"],
)


def _endpoint_label():
    """Use the matched route TEMPLATE (e.g. '/process'), not the raw path.

    This bounds label cardinality: a path like /users/<id> would otherwise
    create a new time series per id and blow up Prometheus' memory. Unmatched
    requests (404s) collapse into a single 'unmatched' label.
    """
    if request.url_rule is not None:
        return request.url_rule.rule
    return "unmatched"


def init_metrics(app):
    """Wire the metrics hooks and the /metrics endpoint onto a Flask app."""

    @app.before_request
    def _before():
        # Don't instrument the scrape endpoint itself — Prometheus hits it every
        # scrape interval, which would dominate the request counts with noise.
        if request.path == "/metrics":
            return
        request._prom_start = time.perf_counter()
        REQUESTS_IN_PROGRESS.labels(request.method, _endpoint_label()).inc()

    @app.after_request
    def _after(response):
        if request.path == "/metrics":
            return response
        endpoint = _endpoint_label()
        elapsed = time.perf_counter() - getattr(request, "_prom_start", time.perf_counter())
        REQUESTS_IN_PROGRESS.labels(request.method, endpoint).dec()
        REQUEST_LATENCY.labels(request.method, endpoint).observe(elapsed)
        REQUEST_COUNT.labels(request.method, endpoint, response.status_code).inc()
        return response

    @app.get("/metrics")
    def metrics():
        # generate_latest() renders ALL registered metrics in the Prometheus
        # text exposition format; the content-type tells Prometheus how to parse.
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)
