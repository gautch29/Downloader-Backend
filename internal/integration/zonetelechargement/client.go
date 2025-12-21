package zonetelechargement

import (
	"fmt"
	"net/http"
	"time"
)

const BaseURL = "https://www.zone-telechargement.cam" // This domain changes often, likely needs config

func CheckConnectivity() error {
	client := &http.Client{
		Timeout: 5 * time.Second,
	}

	resp, err := client.Get(BaseURL)
	if err != nil {
		return fmt.Errorf("unreachable: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("returned status: %s", resp.Status)
	}

	return nil
}
