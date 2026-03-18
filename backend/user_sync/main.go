package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
)

func main() {
	r := mux.NewRouter()
	
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "host=db user=postgres password=postgres dbname=postgres sslmode=disable"
	}
	db, err := sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	r.HandleFunc("/auth/login", func(w http.ResponseWriter, r *http.Request) {
		// Mock authentication
		fmt.Fprintf(w, "JWT_TOKEN_MOCK")
	}).Methods("POST")

	r.HandleFunc("/sync/playlist", func(w http.ResponseWriter, r *http.Request) {
		// Mock sync logic
		fmt.Fprintf(w, "Playlist synced to PostgreSQL")
	}).Methods("POST")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8001"
	}

	log.Printf("User Sync Service listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}
