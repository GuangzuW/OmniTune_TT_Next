package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"omnitune/backend/internal/httpmw"
	"omnitune/backend/internal/metrics"

	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
	"golang.org/x/crypto/bcrypt"
)

var (
	db        *sql.DB
	jwtSecret []byte
)

type ctxKey string

const userIDKey ctxKey = "userID"

// ---- models -----------------------------------------------------------------

type credentials struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type track struct {
	Ref      string `json:"ref"`    // local path or audius id
	Title    string `json:"title"`
	Artist   string `json:"artist"`
	Position int    `json:"position"`
}

type playlist struct {
	Name   string  `json:"name"`
	Tracks []track `json:"tracks"`
}

// ---- schema -----------------------------------------------------------------

func initSchema(db *sql.DB) error {
	stmts := []string{
		`CREATE TABLE IF NOT EXISTS users (
			id SERIAL PRIMARY KEY,
			username TEXT UNIQUE NOT NULL,
			password_hash TEXT NOT NULL,
			created_at TIMESTAMPTZ NOT NULL DEFAULT now()
		)`,
		`CREATE TABLE IF NOT EXISTS playlists (
			id SERIAL PRIMARY KEY,
			user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			name TEXT NOT NULL,
			updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
			UNIQUE(user_id, name)
		)`,
		`CREATE TABLE IF NOT EXISTS playlist_tracks (
			id SERIAL PRIMARY KEY,
			playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
			track_ref TEXT NOT NULL,
			title TEXT,
			artist TEXT,
			position INTEGER NOT NULL DEFAULT 0
		)`,
	}
	for _, s := range stmts {
		if _, err := db.Exec(s); err != nil {
			return err
		}
	}
	return nil
}

// ---- auth helpers -----------------------------------------------------------

func issueToken(userID int) (string, error) {
	claims := jwt.MapClaims{
		"sub": userID,
		"exp": time.Now().Add(72 * time.Hour).Unix(),
		"iat": time.Now().Unix(),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

func parseUserID(tokenStr string) (int, error) {
	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return jwtSecret, nil
	})
	if err != nil || !token.Valid {
		return 0, errors.New("invalid token")
	}
	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return 0, errors.New("invalid claims")
	}
	sub, ok := claims["sub"].(float64)
	if !ok {
		return 0, errors.New("missing subject")
	}
	return int(sub), nil
}

// authMiddleware validates the Bearer token and injects the user id.
func authMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		auth := r.Header.Get("Authorization")
		if !strings.HasPrefix(auth, "Bearer ") {
			http.Error(w, "missing bearer token", http.StatusUnauthorized)
			return
		}
		userID, err := parseUserID(strings.TrimPrefix(auth, "Bearer "))
		if err != nil {
			http.Error(w, "invalid token", http.StatusUnauthorized)
			return
		}
		ctx := context.WithValue(r.Context(), userIDKey, userID)
		next(w, r.WithContext(ctx))
	}
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

// ---- handlers ---------------------------------------------------------------

func handleRegister(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil || c.Username == "" || c.Password == "" {
		http.Error(w, "username and password required", http.StatusBadRequest)
		return
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(c.Password), bcrypt.DefaultCost)
	if err != nil {
		http.Error(w, "hash error", http.StatusInternalServerError)
		return
	}
	var id int
	err = db.QueryRow(
		`INSERT INTO users (username, password_hash) VALUES ($1, $2) RETURNING id`,
		c.Username, string(hash),
	).Scan(&id)
	if err != nil {
		http.Error(w, "user already exists", http.StatusConflict)
		return
	}
	tok, err := issueToken(id)
	if err != nil {
		http.Error(w, "token error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{"token": tok})
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	var c credentials
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	var id int
	var hash string
	err := db.QueryRow(`SELECT id, password_hash FROM users WHERE username = $1`, c.Username).Scan(&id, &hash)
	if err != nil {
		http.Error(w, "invalid credentials", http.StatusUnauthorized)
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(c.Password)) != nil {
		http.Error(w, "invalid credentials", http.StatusUnauthorized)
		return
	}
	tok, err := issueToken(id)
	if err != nil {
		http.Error(w, "token error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"token": tok})
}

// handleSyncPlaylist upserts the caller's playlist and replaces its tracks.
func handleSyncPlaylist(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(userIDKey).(int)
	var p playlist
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil || p.Name == "" {
		http.Error(w, "playlist name required", http.StatusBadRequest)
		return
	}

	tx, err := db.Begin()
	if err != nil {
		http.Error(w, "db error", http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	var playlistID int
	err = tx.QueryRow(
		`INSERT INTO playlists (user_id, name, updated_at) VALUES ($1, $2, now())
		 ON CONFLICT (user_id, name) DO UPDATE SET updated_at = now()
		 RETURNING id`,
		userID, p.Name,
	).Scan(&playlistID)
	if err != nil {
		http.Error(w, "db error", http.StatusInternalServerError)
		return
	}

	if _, err := tx.Exec(`DELETE FROM playlist_tracks WHERE playlist_id = $1`, playlistID); err != nil {
		http.Error(w, "db error", http.StatusInternalServerError)
		return
	}
	for i, t := range p.Tracks {
		pos := t.Position
		if pos == 0 {
			pos = i
		}
		if _, err := tx.Exec(
			`INSERT INTO playlist_tracks (playlist_id, track_ref, title, artist, position)
			 VALUES ($1, $2, $3, $4, $5)`,
			playlistID, t.Ref, t.Title, t.Artist, pos,
		); err != nil {
			http.Error(w, "db error", http.StatusInternalServerError)
			return
		}
	}

	if err := tx.Commit(); err != nil {
		http.Error(w, "db error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "synced", "playlistId": playlistID, "tracks": len(p.Tracks)})
}

// handleGetPlaylists returns all playlists (with tracks) owned by the caller.
func handleGetPlaylists(w http.ResponseWriter, r *http.Request) {
	userID := r.Context().Value(userIDKey).(int)

	rows, err := db.Query(`SELECT id, name FROM playlists WHERE user_id = $1 ORDER BY updated_at DESC`, userID)
	if err != nil {
		http.Error(w, "db error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	result := []playlist{}
	type pl struct {
		id   int
		name string
	}
	var pls []pl
	for rows.Next() {
		var p pl
		if err := rows.Scan(&p.id, &p.name); err != nil {
			http.Error(w, "db error", http.StatusInternalServerError)
			return
		}
		pls = append(pls, p)
	}

	for _, p := range pls {
		trows, err := db.Query(
			`SELECT track_ref, title, artist, position FROM playlist_tracks WHERE playlist_id = $1 ORDER BY position`, p.id)
		if err != nil {
			http.Error(w, "db error", http.StatusInternalServerError)
			return
		}
		out := playlist{Name: p.name, Tracks: []track{}}
		for trows.Next() {
			var t track
			if err := trows.Scan(&t.Ref, &t.Title, &t.Artist, &t.Position); err != nil {
				trows.Close()
				http.Error(w, "db error", http.StatusInternalServerError)
				return
			}
			out.Tracks = append(out.Tracks, t)
		}
		trows.Close()
		result = append(result, out)
	}

	writeJSON(w, http.StatusOK, result)
}

func main() {
	r := mux.NewRouter()

	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "host=db user=postgres password=postgres dbname=postgres sslmode=disable"
	}
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "dev-insecure-secret-change-me"
		log.Println("WARNING: JWT_SECRET not set, using insecure development default")
	}
	jwtSecret = []byte(secret)

	var err error
	db, err = sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	// Postgres may not be ready the instant this container starts.
	for i := 0; i < 30; i++ {
		if err = db.Ping(); err == nil {
			break
		}
		log.Printf("waiting for database... (%d)", i)
		time.Sleep(2 * time.Second)
	}
	if err != nil {
		log.Fatalf("database unreachable: %v", err)
	}
	if err := initSchema(db); err != nil {
		log.Fatalf("schema init failed: %v", err)
	}

	r.HandleFunc("/auth/register", handleRegister).Methods("POST")
	r.HandleFunc("/auth/login", handleLogin).Methods("POST")
	r.HandleFunc("/sync/playlist", authMiddleware(handleSyncPlaylist)).Methods("POST")
	r.HandleFunc("/playlists", authMiddleware(handleGetPlaylists)).Methods("GET")
	r.Handle("/metrics", metrics.Handler())
	r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	}).Methods("GET")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8001"
	}

	log.Printf("User Sync Service listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, httpmw.CORS(metrics.Middleware("user_sync", r))))
}
