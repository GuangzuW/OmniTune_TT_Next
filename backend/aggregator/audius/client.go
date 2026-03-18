package audius

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
)

type Track struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	User  struct {
		Name string `json:"name"`
	} `json:"user"`
}

type Client struct {
	BaseURL string
}

func NewClient() *Client {
	// For production, this should be dynamically resolved or from a config.
	return &Client{BaseURL: "https://api.audius.co"}
}

func (c *Client) SearchTracks(query string) ([]Track, error) {
	u, _ := url.Parse(fmt.Sprintf("%s/v1/tracks/search", c.BaseURL))
	q := u.Query()
	q.Set("query", query)
	q.Set("app_name", "OmniTune_TT_Next")
	u.RawQuery = q.Encode()

	resp, err := http.Get(u.String())
	if (err != nil) {
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

func (c *Client) GetStreamURL(trackID string) string {
	return fmt.Sprintf("%s/v1/tracks/%s/stream?app_name=OmniTune_TT_Next", c.BaseURL, trackID)
}
