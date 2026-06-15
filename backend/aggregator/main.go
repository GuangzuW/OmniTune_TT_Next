package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"omnitune/backend/aggregator/audius"
	"omnitune/backend/aggregator/cache"
	"omnitune/backend/internal/httpmw"
	"omnitune/backend/internal/metrics"

	"github.com/gorilla/mux"
	"github.com/nats-io/nats.go"
)

const searchCacheTTL = 5 * time.Minute

func main() {
	r := mux.NewRouter()
	audiusClient := audius.NewClient()

	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}
	rc := cache.NewCache(redisAddr)

	// Optional event stream: publish search events to NATS so other services
	// (recommendations, analytics) can consume them. Best-effort — the API
	// works fine without it.
	var nc *nats.Conn
	if natsURL := os.Getenv("NATS_URL"); natsURL != "" {
		if conn, err := nats.Connect(natsURL, nats.Timeout(2*time.Second)); err != nil {
			log.Printf("NATS connect failed (events disabled): %v", err)
		} else {
			nc = conn
			defer nc.Drain()
			log.Printf("Connected to NATS at %s", natsURL)
		}
	}

	r.HandleFunc("/search", func(w http.ResponseWriter, r *http.Request) {
		query := r.URL.Query().Get("query")
		if query == "" {
			http.Error(w, "query required", http.StatusBadRequest)
			return
		}

		ctx := r.Context()
		cacheKey := "search:" + query
		w.Header().Set("Content-Type", "application/json")

		// Cache hit: serve the stored JSON payload directly.
		if cached, err := rc.Get(ctx, cacheKey); err == nil && cached != "" {
			w.Header().Set("X-Cache", "HIT")
			w.Write([]byte(cached))
			return
		}

		// Cache miss (or Redis unavailable): fetch live from Audius.
		tracks, err := audiusClient.SearchTracks(query)
		if err != nil {
			log.Printf("Search error: %v", err)
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		if nc != nil {
			nc.Publish("omnitune.search", []byte(query))
		}

		payload, err := json.Marshal(tracks)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		// Best-effort cache write; never fail the request if Redis is down.
		if err := rc.Set(ctx, cacheKey, string(payload), searchCacheTTL); err != nil {
			log.Printf("Cache set failed (serving live): %v", err)
		}

		w.Header().Set("X-Cache", "MISS")
		w.Write(payload)
	}).Methods("GET")

	r.HandleFunc("/stream/{id}", func(w http.ResponseWriter, r *http.Request) {
		vars := mux.Vars(r)
		id := vars["id"]

		url := audiusClient.GetStreamURL(id)

		// For a real proxy, we would pipe the response, but redirecting
		// handles most cases if CORS is configured correctly on Audius side.
		http.Redirect(w, r, url, http.StatusFound)
	}).Methods("GET")

	// Prometheus metrics endpoint.
	r.Handle("/metrics", metrics.Handler())

	// Lightweight health endpoint for container/orchestration probes.
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 500*time.Millisecond)
		defer cancel()
		redisOK := rc.Client.Ping(ctx).Err() == nil
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"status": "ok", "redis": redisOK})
	}).Methods("GET")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	log.Printf("Aggregator listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, httpmw.CORS(metrics.Middleware("aggregator", r))))
}
