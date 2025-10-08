package realtime

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"citizenapp/backend/internal/service"
)

// 1.- mockConn implementa la interfaz Conn utilizando canales simples para pruebas.
type mockConn struct {
	closed     atomic.Bool
	readErr    error
	writeErr   error
	controlErr error
}

func (c *mockConn) SetReadLimit(int64)                        {}
func (c *mockConn) SetReadDeadline(time.Time) error           { return nil }
func (c *mockConn) SetWriteDeadline(time.Time) error          { return nil }
func (c *mockConn) SetPongHandler(func(string) error)         {}
func (c *mockConn) ReadMessage() (int, []byte, error)         { return 0, nil, c.readErr }
func (c *mockConn) WriteMessage(int, []byte) error            { return c.writeErr }
func (c *mockConn) WriteControl(int, []byte, time.Time) error { return c.controlErr }
func (c *mockConn) Close() error {
	if c.closed.Swap(true) {
		return errors.New("already closed")
	}
	return nil
}

func TestBroadcastEnqueuesForAllClients(t *testing.T) {
	// 2.- Creamos un hub con múltiples particiones y clientes de prueba.
	hub := NewHub(2, 2, 8, 2)
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		if err := hub.Shutdown(ctx); err != nil {
			t.Fatalf("shutdown failed: %v", err)
		}
	})
	clientA := hub.Register(&mockConn{})
	clientB := hub.Register(&mockConn{})

	// 3.- Difundimos un reporte simulando tráfico real.
	report := service.Report{ID: "F-0001", Description: "demo"}
	if err := hub.BroadcastReport(report); err != nil {
		t.Fatalf("broadcast failed: %v", err)
	}

	// 4.- Validamos que ambos clientes reciben el payload serializado.
	waitFor := func(ch <-chan []byte) []byte {
		select {
		case msg := <-ch:
			return msg
		case <-time.After(2 * time.Second):
			t.Fatalf("timeout waiting for broadcast")
		}
		return nil
	}
	msgA := waitFor(clientA.Messages())
	msgB := waitFor(clientB.Messages())
	if string(msgA) != string(msgB) {
		t.Fatalf("expected identical payloads, got %q vs %q", msgA, msgB)
	}
}

func TestBroadcastQueueBackpressure(t *testing.T) {
	// 5.- Configuramos un hub con cola reducida para probar el control de presión.
	hub := NewHub(1, 1, 1, 1)
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		_ = hub.Shutdown(ctx)
	}()
	client := hub.Register(&mockConn{})
	_ = client // evitamos advertencias de compilación.

	// 6.- Saturamos la cola y verificamos que se notifica el error apropiado.
	if err := hub.Broadcast([]byte("a")); err != nil {
		t.Fatalf("unexpected error broadcasting first message: %v", err)
	}
	if err := hub.Broadcast([]byte("b")); err == nil {
		t.Fatalf("expected backpressure error when queue is full")
	}
}
