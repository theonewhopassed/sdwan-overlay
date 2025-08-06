package store

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"go.etcd.io/etcd/client/v3"
)

// Store defines the interface for data storage
type Store interface {
	// Device management
	ListDevices() ([]map[string]interface{}, error)
	CreateDevice(device map[string]interface{}) (string, error)
	GetDevice(id string) (map[string]interface{}, error)
	UpdateDevice(id string, device map[string]interface{}) error
	DeleteDevice(id string) error

	// Link management
	ListLinks() ([]map[string]interface{}, error)
	CreateLink(link map[string]interface{}) (string, error)
	GetLink(id string) (map[string]interface{}, error)
	UpdateLink(id string, link map[string]interface{}) error
	DeleteLink(id string) error

	// Configuration management
	GetConfig() (map[string]interface{}, error)
	UpdateConfig(config map[string]interface{}) error

	// Metrics
	GetMetrics() (map[string]interface{}, error)
}

// EtcdStore implements Store interface using etcd
type EtcdStore struct {
	client *clientv3.Client
}

// NewEtcdStore creates a new etcd-based store
func NewEtcdStore(client *clientv3.Client) *EtcdStore {
	return &EtcdStore{
		client: client,
	}
}

// Device management methods
func (s *EtcdStore) ListDevices() ([]map[string]interface{}, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	resp, err := s.client.Get(ctx, "/devices/", clientv3.WithPrefix())
	if err != nil {
		return nil, fmt.Errorf("failed to list devices: %w", err)
	}

	var devices []map[string]interface{}
	for _, kv := range resp.Kvs {
		var device map[string]interface{}
		if err := json.Unmarshal(kv.Value, &device); err != nil {
			continue // Skip invalid entries
		}
		devices = append(devices, device)
	}

	return devices, nil
}

func (s *EtcdStore) CreateDevice(device map[string]interface{}) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Generate ID (in production, use UUID)
	id := fmt.Sprintf("device-%d", time.Now().UnixNano())
	
	data, err := json.Marshal(device)
	if err != nil {
		return "", fmt.Errorf("failed to marshal device: %w", err)
	}

	key := fmt.Sprintf("/devices/%s", id)
	_, err = s.client.Put(ctx, key, string(data))
	if err != nil {
		return "", fmt.Errorf("failed to create device: %w", err)
	}

	return id, nil
}

func (s *EtcdStore) GetDevice(id string) (map[string]interface{}, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	key := fmt.Sprintf("/devices/%s", id)
	resp, err := s.client.Get(ctx, key)
	if err != nil {
		return nil, fmt.Errorf("failed to get device: %w", err)
	}

	if len(resp.Kvs) == 0 {
		return nil, fmt.Errorf("device not found")
	}

	var device map[string]interface{}
	if err := json.Unmarshal(resp.Kvs[0].Value, &device); err != nil {
		return nil, fmt.Errorf("failed to unmarshal device: %w", err)
	}

	return device, nil
}

func (s *EtcdStore) UpdateDevice(id string, device map[string]interface{}) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	data, err := json.Marshal(device)
	if err != nil {
		return fmt.Errorf("failed to marshal device: %w", err)
	}

	key := fmt.Sprintf("/devices/%s", id)
	_, err = s.client.Put(ctx, key, string(data))
	if err != nil {
		return fmt.Errorf("failed to update device: %w", err)
	}

	return nil
}

func (s *EtcdStore) DeleteDevice(id string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	key := fmt.Sprintf("/devices/%s", id)
	_, err := s.client.Delete(ctx, key)
	if err != nil {
		return fmt.Errorf("failed to delete device: %w", err)
	}

	return nil
}

// Link management methods
func (s *EtcdStore) ListLinks() ([]map[string]interface{}, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	resp, err := s.client.Get(ctx, "/links/", clientv3.WithPrefix())
	if err != nil {
		return nil, fmt.Errorf("failed to list links: %w", err)
	}

	var links []map[string]interface{}
	for _, kv := range resp.Kvs {
		var link map[string]interface{}
		if err := json.Unmarshal(kv.Value, &link); err != nil {
			continue // Skip invalid entries
		}
		links = append(links, link)
	}

	return links, nil
}

func (s *EtcdStore) CreateLink(link map[string]interface{}) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Generate ID (in production, use UUID)
	id := fmt.Sprintf("link-%d", time.Now().UnixNano())
	
	data, err := json.Marshal(link)
	if err != nil {
		return "", fmt.Errorf("failed to marshal link: %w", err)
	}

	key := fmt.Sprintf("/links/%s", id)
	_, err = s.client.Put(ctx, key, string(data))
	if err != nil {
		return "", fmt.Errorf("failed to create link: %w", err)
	}

	return id, nil
}

func (s *EtcdStore) GetLink(id string) (map[string]interface{}, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	key := fmt.Sprintf("/links/%s", id)
	resp, err := s.client.Get(ctx, key)
	if err != nil {
		return nil, fmt.Errorf("failed to get link: %w", err)
	}

	if len(resp.Kvs) == 0 {
		return nil, fmt.Errorf("link not found")
	}

	var link map[string]interface{}
	if err := json.Unmarshal(resp.Kvs[0].Value, &link); err != nil {
		return nil, fmt.Errorf("failed to unmarshal link: %w", err)
	}

	return link, nil
}

func (s *EtcdStore) UpdateLink(id string, link map[string]interface{}) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	data, err := json.Marshal(link)
	if err != nil {
		return fmt.Errorf("failed to marshal link: %w", err)
	}

	key := fmt.Sprintf("/links/%s", id)
	_, err = s.client.Put(ctx, key, string(data))
	if err != nil {
		return fmt.Errorf("failed to update link: %w", err)
	}

	return nil
}

func (s *EtcdStore) DeleteLink(id string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	key := fmt.Sprintf("/links/%s", id)
	_, err := s.client.Delete(ctx, key)
	if err != nil {
		return fmt.Errorf("failed to delete link: %w", err)
	}

	return nil
}

// Configuration management methods
func (s *EtcdStore) GetConfig() (map[string]interface{}, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	resp, err := s.client.Get(ctx, "/config")
	if err != nil {
		return nil, fmt.Errorf("failed to get config: %w", err)
	}

	if len(resp.Kvs) == 0 {
		return make(map[string]interface{}), nil
	}

	var config map[string]interface{}
	if err := json.Unmarshal(resp.Kvs[0].Value, &config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	return config, nil
}

func (s *EtcdStore) UpdateConfig(config map[string]interface{}) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	data, err := json.Marshal(config)
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	_, err = s.client.Put(ctx, "/config", string(data))
	if err != nil {
		return fmt.Errorf("failed to update config: %w", err)
	}

	return nil
}

// Metrics method
func (s *EtcdStore) GetMetrics() (map[string]interface{}, error) {
	// For now, return basic metrics
	// In production, collect real metrics from components
	metrics := map[string]interface{}{
		"devices_count": 0,
		"links_count":   0,
		"uptime":        time.Now().Unix(),
		"version":       "1.0.0",
	}

	return metrics, nil
} 