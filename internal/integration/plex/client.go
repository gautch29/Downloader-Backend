package plex

import (
	"fmt"
	"net/http"
	"time"
)

type Client struct {
	URL   string
	Token string
}

func NewClient(url, token string) *Client {
	return &Client{URL: url, Token: token}
}

func (c *Client) CheckConnection() error {
	if c.URL == "" {
		return fmt.Errorf("Plex URL is missing")
	}
	// "identity" endpoint is a lightweight way to check server status
	url := fmt.Sprintf("%s/identity", c.URL)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return err
	}

	req.Header.Set("Accept", "application/json")
	if c.Token != "" {
		req.Header.Set("X-Plex-Token", c.Token)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("network error: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("Plex returned error: %s", resp.Status)
	}

	return nil
}
