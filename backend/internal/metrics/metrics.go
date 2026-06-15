// Package metrics provides Prometheus instrumentation shared by the services.
package metrics

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	requests = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total HTTP requests processed, labeled by service, method, route and status.",
	}, []string{"service", "method", "route", "status"})

	duration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "http_request_duration_seconds",
		Help:    "HTTP request latency in seconds.",
		Buckets: prometheus.DefBuckets,
	}, []string{"service", "method", "route"})
)

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

// route collapses dynamic segments to the first path element to keep label
// cardinality bounded (e.g. /stream/abc123 -> /stream).
func route(p string) string {
	p = strings.Trim(p, "/")
	if p == "" {
		return "/"
	}
	return "/" + strings.SplitN(p, "/", 2)[0]
}

// Middleware records request count and latency for every request.
func Middleware(service string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		rt := route(r.URL.Path)
		duration.WithLabelValues(service, r.Method, rt).Observe(time.Since(start).Seconds())
		requests.WithLabelValues(service, r.Method, rt, strconv.Itoa(rec.status)).Inc()
	})
}

// Handler is the /metrics endpoint exposing the Prometheus registry.
func Handler() http.Handler { return promhttp.Handler() }
