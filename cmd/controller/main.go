package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/sdwan/speedfusion-like/cmd/controller/internal/config"
	"github.com/sdwan/speedfusion-like/cmd/controller/internal/server"
	"github.com/sdwan/speedfusion-like/cmd/controller/internal/store"
	"go.etcd.io/etcd/client/v3"
)

var (
	configFile = flag.String("config", "config/controller.yml", "Configuration file path")
	port       = flag.Int("port", 8080, "HTTP server port")
	etcdEndpoints = flag.String("etcd", "http://localhost:2379", "Etcd endpoints")
	logLevel   = flag.String("log-level", "info", "Log level")
)

func main() {
	flag.Parse()

	// Load configuration
	cfg, err := config.Load(*configFile)
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Initialize etcd client
	etcdClient, err := clientv3.New(clientv3.Config{
		Endpoints:   []string{*etcdEndpoints},
		DialTimeout: 5 * time.Second,
	})
	if err != nil {
		log.Fatalf("Failed to connect to etcd: %v", err)
	}
	defer etcdClient.Close()

	// Initialize store
	store := store.NewEtcdStore(etcdClient)

	// Initialize server
	srv := server.NewServer(cfg, store)

	// Start HTTP server
	go func() {
		addr := fmt.Sprintf(":%d", *port)
		log.Printf("Starting HTTP server on %s", addr)
		if err := srv.Start(addr); err != nil && err != http.ErrServerClosed {
			log.Fatalf("HTTP server error: %v", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server shutdown error: %v", err)
	}

	log.Println("Server stopped")
} 