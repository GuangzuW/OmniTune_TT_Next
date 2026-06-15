// Package httpmw holds small HTTP middlewares shared by the services.
package httpmw

import (
	"net/http"
	"os"
)

// CORS allows the web frontend (a different origin/port) to call the API from
// the browser. Origin is configurable via CORS_ALLOW_ORIGIN (default "*").
// Auth uses a Bearer header (not cookies), so a wildcard origin is safe here.
func CORS(next http.Handler) http.Handler {
	origin := os.Getenv("CORS_ALLOW_ORIGIN")
	if origin == "" {
		origin = "*"
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", origin)
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		w.Header().Set("Access-Control-Max-Age", "86400")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
