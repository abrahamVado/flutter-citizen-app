package realtime

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"sync/atomic"
	"time"

	"citizenapp/backend/internal/observability"
	"citizenapp/backend/internal/service"
	"github.com/gorilla/websocket"
)

// 1.- Conn define la interfaz mínima que reutilizamos para las conexiones WebSocket.
type Conn interface {
	SetReadLimit(limit int64)
	SetReadDeadline(t time.Time) error
	SetWriteDeadline(t time.Time) error
	SetPongHandler(h func(string) error)
	ReadMessage() (messageType int, p []byte, err error)
	WriteMessage(messageType int, data []byte) error
	WriteControl(messageType int, data []byte, deadline time.Time) error
	Close() error
}

// 2.- Hub coordina a millones de clientes concurrentes mediante particiones.
type Hub struct {
	shards            []clientShard
	shardMask         uint64
	broadcastQueue    chan []byte
	workerGroup       sync.WaitGroup
	stopOnce          sync.Once
	nextID            atomic.Uint64
	clientBuffer      int
	pongWait          time.Duration
	pingInterval      time.Duration
	shutdownCompleted chan struct{}
}

type clientShard struct {
	mu      sync.RWMutex
	clients map[uint64]*Client
}

// 3.- Client encapsula el ciclo de vida y los buffers de cada conexión WebSocket.
type Client struct {
	id        uint64
	conn      Conn
	hub       *Hub
	outbound  chan []byte
	closeOnce sync.Once
}

const (
	defaultPongWait     = 55 * time.Second
	defaultPingInterval = 45 * time.Second
)

// 4.- NewHub inicializa las estructuras en paralelo y lanza los workers de difusión.
func NewHub(shardPower, workerCount, queueSize, clientBuffer int) *Hub {
	if shardPower <= 0 {
		shardPower = 4
	}
	if workerCount <= 0 {
		workerCount = 4
	}
	if queueSize <= 0 {
		queueSize = 1024
	}
	if clientBuffer <= 0 {
		clientBuffer = 64
	}
	shardCount := 1 << shardPower
	shards := make([]clientShard, shardCount)
	for i := range shards {
		shards[i].clients = make(map[uint64]*Client)
	}
	observability.EnsureMetrics(nil)
	h := &Hub{
		shards:            shards,
		shardMask:         uint64(shardCount - 1),
		broadcastQueue:    make(chan []byte, queueSize),
		clientBuffer:      clientBuffer,
		pongWait:          defaultPongWait,
		pingInterval:      defaultPingInterval,
		shutdownCompleted: make(chan struct{}),
	}
	for i := 0; i < workerCount; i++ {
		h.workerGroup.Add(1)
		go h.broadcastWorker()
	}
	return h
}

// 5.- Register asigna un identificador incremental y agrega al cliente a su partición.
func (h *Hub) Register(conn Conn) *Client {
	client := &Client{
		id:       h.nextID.Add(1),
		conn:     conn,
		hub:      h,
		outbound: make(chan []byte, h.clientBuffer),
	}
	shard := h.shardFor(client.id)
	shard.mu.Lock()
	shard.clients[client.id] = client
	shard.mu.Unlock()
	return client
}

// 6.- Broadcast encola el mensaje para procesamiento paralelo sin bloquear al caller.
func (h *Hub) Broadcast(message []byte) error {
	select {
	case h.broadcastQueue <- message:
		return nil
	default:
		return errors.New("broadcast queue full")
	}
}

// 7.- BroadcastReport serializa el reporte y lo distribuye entre los clientes.
func (h *Hub) BroadcastReport(report service.Report) error {
	payload := map[string]any{
		"type":    "report.created",
		"payload": report,
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	return h.Broadcast(data)
}

// 8.- Shutdown detiene a los workers y cierra cada conexión de forma ordenada.
func (h *Hub) Shutdown(ctx context.Context) error {
	h.stopOnce.Do(func() {
		close(h.broadcastQueue)
	})
	done := make(chan struct{})
	go func() {
		h.workerGroup.Wait()
		for i := range h.shards {
			shard := &h.shards[i]
			shard.mu.Lock()
			for id, client := range shard.clients {
				delete(shard.clients, id)
				client.close()
			}
			shard.mu.Unlock()
		}
		close(h.shutdownCompleted)
		close(done)
	}()
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-done:
		return nil
	}
}

// 9.- shardFor obtiene la partición responsable del identificador solicitado.
func (h *Hub) shardFor(id uint64) *clientShard {
	index := id & h.shardMask
	return &h.shards[index]
}

// 10.- broadcastWorker distribuye los mensajes a cada cliente con buffers limitados.
func (h *Hub) broadcastWorker() {
	defer h.workerGroup.Done()
	for message := range h.broadcastQueue {
		start := time.Now()
		for i := range h.shards {
			shard := &h.shards[i]
			shard.mu.RLock()
			for _, client := range shard.clients {
				client.enqueue(message)
			}
			shard.mu.RUnlock()
		}
		observability.ObserveBroadcastLatency(time.Since(start))
	}
}

// 11.- enqueue coloca el mensaje o descarta el más antiguo si el buffer está lleno.
func (c *Client) enqueue(message []byte) {
	select {
	case c.outbound <- message:
	default:
		select {
		case <-c.outbound:
		default:
		}
		select {
		case c.outbound <- message:
		default:
		}
	}
}

// 12.- Run inicia los ciclos de lectura y escritura para la conexión WebSocket.
func (c *Client) Run(ctx context.Context) {
	ctx, cancel := context.WithCancel(ctx)
	defer cancel()
	go c.writeLoop(ctx)
	c.readLoop(ctx)
	cancel()
	c.hub.unregister(c.id)
}

// 13.- readLoop consume los mensajes entrantes para detectar desconexiones oportunamente.
func (c *Client) readLoop(ctx context.Context) {
	c.conn.SetReadLimit(1024)
	_ = c.conn.SetReadDeadline(time.Now().Add(c.hub.pongWait))
	c.conn.SetPongHandler(func(string) error {
		return c.conn.SetReadDeadline(time.Now().Add(c.hub.pongWait))
	})
	for {
		if ctx.Err() != nil {
			return
		}
		if _, _, err := c.conn.ReadMessage(); err != nil {
			return
		}
	}
}

// 14.- writeLoop atiende el buffer de salida y emite pings periódicos.
func (c *Client) writeLoop(ctx context.Context) {
	ticker := time.NewTicker(c.hub.pingInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case message, ok := <-c.outbound:
			if !ok {
				return
			}
			_ = c.conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}
		case <-ticker.C:
			deadline := time.Now().Add(5 * time.Second)
			if err := c.conn.WriteControl(websocket.PingMessage, nil, deadline); err != nil {
				return
			}
		}
	}
}

// 15.- Messages expone un canal de solo lectura útil para pruebas unitarias.
func (c *Client) Messages() <-chan []byte {
	return c.outbound
}

// 16.- close garantiza el cierre único de los recursos asociados al cliente.
func (c *Client) close() {
	c.closeOnce.Do(func() {
		close(c.outbound)
		_ = c.conn.Close()
	})
}

// 17.- unregister elimina al cliente de la partición y libera sus recursos.
func (h *Hub) unregister(id uint64) {
	shard := h.shardFor(id)
	shard.mu.Lock()
	client, ok := shard.clients[id]
	if ok {
		delete(shard.clients, id)
	}
	shard.mu.Unlock()
	if ok {
		client.close()
	}
}
