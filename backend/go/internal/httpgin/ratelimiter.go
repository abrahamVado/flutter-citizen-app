package httpgin

import (
	"sync"
	"time"

	"golang.org/x/time/rate"
)

// 1.- ipRateLimiter mantiene limitadores por clave con una política de expiración.
type ipRateLimiter struct {
	mu       sync.Mutex
	limiters map[string]*limiterEntry
	limit    rate.Limit
	burst    int
	ttl      time.Duration
}

type limiterEntry struct {
	limiter *rate.Limiter
	expires time.Time
}

// 2.- newIPRateLimiter crea un contenedor listo para emitir permisos por ventana.
func newIPRateLimiter(requests int, window time.Duration) *ipRateLimiter {
	if requests <= 0 || window <= 0 {
		return nil
	}
	limiter := rate.Every(window / time.Duration(requests))
	return &ipRateLimiter{
		limiters: make(map[string]*limiterEntry),
		limit:    limiter,
		burst:    requests,
		ttl:      window * 2,
	}
}

// 3.- Allow evalúa si la clave aún dispone de tokens para continuar la solicitud.
func (l *ipRateLimiter) Allow(key string) bool {
	if l == nil {
		return true
	}
	if key == "" {
		key = "anonymous"
	}
	now := time.Now()
	l.mu.Lock()
	defer l.mu.Unlock()
	entry, ok := l.limiters[key]
	if !ok || now.After(entry.expires) {
		entry = &limiterEntry{
			limiter: rate.NewLimiter(l.limit, l.burst),
			expires: now.Add(l.ttl),
		}
		l.limiters[key] = entry
	}
	entry.expires = now.Add(l.ttl)
	allowed := entry.limiter.Allow()
	if !allowed {
		l.pruneLocked(now)
	}
	return allowed
}

// 4.- pruneLocked elimina entradas expiradas para evitar crecimiento indefinido.
func (l *ipRateLimiter) pruneLocked(now time.Time) {
	for key, entry := range l.limiters {
		if now.After(entry.expires) {
			delete(l.limiters, key)
		}
	}
}
