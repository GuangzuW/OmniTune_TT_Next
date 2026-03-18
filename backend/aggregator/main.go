package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"omnitune/backend/aggregator/audius"
	"omnitune/backend/aggregator/cache"
	"github.com/gorilla/mux"
)

func main() {
	r := mux.NewRouter()
	audiusClient := audius.NewClient()
	
	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}
	_ = cache.NewCache(redisAddr) // Cache integration can be more complex

	r.HandleFunc("/search", func(w http.ResponseWriter, r *http.Request) {
		query := r.URL.Query().Get("query")
		if query == "" {
			http.Error(w, "query required", http.StatusBadRequest)
			return
		}

		tracks, err := audiusClient.SearchTracks(query)
		if err != nil {
			log.Printf("Search error: %v", err)
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		// Map to internal model if needed, but for now we return Tracks
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(tracks)
	}).Methods("GET")

	r.HandleFunc("/stream/{id}", func(w http.ResponseWriter, r *http.Request) {
		vars := mux.Vars(r)
		id := vars["id"]
		
		url := audiusClient.GetStreamURL(id)
		
		// For a real proxy, we would pipe the response, but redirecting 
		// handles most cases if CORS is configured correctly on Audius side.
		http.Redirect(w, r, url, http.StatusFound)
	}).Methods("GET")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	log.Printf("Aggregator listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}
