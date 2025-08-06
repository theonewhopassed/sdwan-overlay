package server

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/sdwan/speedfusion-like/cmd/controller/internal/config"
	"github.com/sdwan/speedfusion-like/cmd/controller/internal/store"
)

// Server represents the HTTP server
type Server struct {
	config *config.Config
	store  store.Store
	server *http.Server
	router *gin.Engine
}

// NewServer creates a new server instance
func NewServer(cfg *config.Config, store store.Store) *Server {
	router := gin.Default()
	
	srv := &Server{
		config: cfg,
		store:  store,
		router: router,
	}

	srv.setupRoutes()
	
	return srv
}

// setupRoutes configures the HTTP routes
func (s *Server) setupRoutes() {
	// Health check endpoint
	s.router.GET("/health", s.healthHandler)
	
	// API routes
	api := s.router.Group("/api/v1")
	{
		// Device management
		api.GET("/devices", s.listDevices)
		api.POST("/devices", s.createDevice)
		api.GET("/devices/:id", s.getDevice)
		api.PUT("/devices/:id", s.updateDevice)
		api.DELETE("/devices/:id", s.deleteDevice)
		
		// Link management
		api.GET("/links", s.listLinks)
		api.POST("/links", s.createLink)
		api.GET("/links/:id", s.getLink)
		api.PUT("/links/:id", s.updateLink)
		api.DELETE("/links/:id", s.deleteLink)
		
		// Configuration management
		api.GET("/config", s.getConfig)
		api.PUT("/config", s.updateConfig)
		
		// Metrics
		api.GET("/metrics", s.getMetrics)
	}
}

// Start starts the HTTP server
func (s *Server) Start(addr string) error {
	s.server = &http.Server{
		Addr:         addr,
		Handler:      s.router,
		ReadTimeout:  time.Duration(s.config.Server.ReadTimeout) * time.Second,
		WriteTimeout: time.Duration(s.config.Server.WriteTimeout) * time.Second,
	}
	
	return s.server.ListenAndServe()
}

// Shutdown gracefully shuts down the server
func (s *Server) Shutdown(ctx context.Context) error {
	if s.server != nil {
		return s.server.Shutdown(ctx)
	}
	return nil
}

// Health check handler
func (s *Server) healthHandler(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status": "healthy",
		"time":   time.Now().UTC(),
	})
}

// Device management handlers
func (s *Server) listDevices(c *gin.Context) {
	devices, err := s.store.ListDevices()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, devices)
}

func (s *Server) createDevice(c *gin.Context) {
	var device map[string]interface{}
	if err := c.ShouldBindJSON(&device); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	
	id, err := s.store.CreateDevice(device)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	
	c.JSON(http.StatusCreated, gin.H{"id": id})
}

func (s *Server) getDevice(c *gin.Context) {
	id := c.Param("id")
	device, err := s.store.GetDevice(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "device not found"})
		return
	}
	c.JSON(http.StatusOK, device)
}

func (s *Server) updateDevice(c *gin.Context) {
	id := c.Param("id")
	var device map[string]interface{}
	if err := c.ShouldBindJSON(&device); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	
	if err := s.store.UpdateDevice(id, device); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{"status": "updated"})
}

func (s *Server) deleteDevice(c *gin.Context) {
	id := c.Param("id")
	if err := s.store.DeleteDevice(id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "deleted"})
}

// Link management handlers
func (s *Server) listLinks(c *gin.Context) {
	links, err := s.store.ListLinks()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, links)
}

func (s *Server) createLink(c *gin.Context) {
	var link map[string]interface{}
	if err := c.ShouldBindJSON(&link); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	
	id, err := s.store.CreateLink(link)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	
	c.JSON(http.StatusCreated, gin.H{"id": id})
}

func (s *Server) getLink(c *gin.Context) {
	id := c.Param("id")
	link, err := s.store.GetLink(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "link not found"})
		return
	}
	c.JSON(http.StatusOK, link)
}

func (s *Server) updateLink(c *gin.Context) {
	id := c.Param("id")
	var link map[string]interface{}
	if err := c.ShouldBindJSON(&link); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	
	if err := s.store.UpdateLink(id, link); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{"status": "updated"})
}

func (s *Server) deleteLink(c *gin.Context) {
	id := c.Param("id")
	if err := s.store.DeleteLink(id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "deleted"})
}

// Configuration handlers
func (s *Server) getConfig(c *gin.Context) {
	config, err := s.store.GetConfig()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, config)
}

func (s *Server) updateConfig(c *gin.Context) {
	var config map[string]interface{}
	if err := c.ShouldBindJSON(&config); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	
	if err := s.store.UpdateConfig(config); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	
	c.JSON(http.StatusOK, gin.H{"status": "updated"})
}

// Metrics handler
func (s *Server) getMetrics(c *gin.Context) {
	metrics, err := s.store.GetMetrics()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, metrics)
} 