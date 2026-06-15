package audius

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"sync"
	"time"
)

const appName = "OmniTune_TT_Next"

// Artwork holds the CDN URLs Audius returns at a few resolutions.
type Artwork struct {
	Small  string `json:"150x150"`
	Medium string `json:"480x480"`
	Large  string `json:"1000x1000"`
}

type Track struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	User  struct {
		Name string `json:"name"`
	} `json:"user"`
	Duration int     `json:"duration"`
	Artwork  Artwork `json:"artwork"`
}

type Client struct {
	discoveryURL string
	httpClient   *http.Client

	mu   sync.Mutex
	host string // resolved discovery-provider host (e.g. https://discoveryprovider.audius.co)
}

func NewClient() *Client {
	return &Client{
		discoveryURL: "https://api.audius.co",
		httpClient:   &http.Client{Timeout: 15 * time.Second},
	}
}

// resolveHost fetches the list of discovery providers from api.audius.co and
// caches the first one. api.audius.co is a *selector*, not the API itself — the
// real /v1 endpoints live on the returned hosts. (This was the original bug:
// calling api.audius.co/v1/... directly returns nothing.)
func (c *Client) resolveHost() (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.host != "" {
		return c.host, nil
	}

	resp, err := c.httpClient.Get(c.discoveryURL)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var result struct {
		Data []string `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}
	if len(result.Data) == 0 {
		return "", fmt.Errorf("no Audius discovery providers available")
	}
	c.host = result.Data[0]
	return c.host, nil
}

func (c *Client) SearchTracks(query string) ([]Track, error) {
	host, err := c.resolveHost()
	if err != nil {
		return nil, err
	}

	u, _ := url.Parse(fmt.Sprintf("%s/v1/tracks/search", host))
	q := u.Query()
	q.Set("query", query)
	q.Set("app_name", appName)
	u.RawQuery = q.Encode()

	resp, err := c.httpClient.Get(u.String())
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result struct {
		Data []Track `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return result.Data, nil
}

// GetStreamURL returns a direct stream URL on the resolved discovery host.
// Falls back to the selector host if resolution fails (best effort).
func (c *Client) GetStreamURL(trackID string) string {
	host, err := c.resolveHost()
	if err != nil {
		host = c.discoveryURL
	}
	return fmt.Sprintf("%s/v1/tracks/%s/stream?app_name=%s", host, trackID, appName)
}
