package onefichier

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

const BaseURL = "https://api.1fichier.com/v1"

type Client struct {
	APIKey string
}

func NewClient(apiKey string) *Client {
	return &Client{APIKey: apiKey}
}

// CheckAPI verifies if the API key is valid by making a dummy request (e.g., getting user info or usage)
// Since 1fichier API documentation might vary, we'll try a generic endpoint or just check if we can make a request.
// For now, checks "account/info" if available, or just considers it reachable if no network error.
// To be safe and minimal: checking "folder/ls" on root or similar.
// A better simple check is usually account info.
func (c *Client) CheckAPI() error {
	if c.APIKey == "" {
		return fmt.Errorf("API key is missing")
	}

	// Payload for many 1fichier requests
	payload := map[string]interface{}{}
	jsonPayload, _ := json.Marshal(payload)

	req, err := http.NewRequest("POST", BaseURL+"/user/info.cgi", bytes.NewBuffer(jsonPayload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.APIKey)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("network error: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("API returned error: %s", resp.Status)
	}

	return nil
}
