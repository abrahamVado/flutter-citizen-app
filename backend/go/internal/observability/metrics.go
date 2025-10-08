package observability

import (
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	// 1.- metricsOnce garantiza un registro único de las métricas.
	metricsOnce sync.Once
	// 2.- submitQueueDepth mide los trabajos pendientes por procesar.
	submitQueueDepth prometheus.Gauge
	// 3.- lookupQueueDepth supervisa las consultas en espera.
	lookupQueueDepth prometheus.Gauge
	// 4.- broadcastLatency evalúa la duración de los envíos WebSocket.
	broadcastLatency prometheus.Histogram
	// 5.- httpRequestDuration captura la latencia de cada petición HTTP.
	httpRequestDuration *prometheus.HistogramVec
)

// 6.- EnsureMetrics inicializa y registra los recolectores personalizados.
func EnsureMetrics(reg prometheus.Registerer) {
	metricsOnce.Do(func() {
		if reg == nil {
			reg = prometheus.DefaultRegisterer
		}
		submitQueueDepth = prometheus.NewGauge(prometheus.GaugeOpts{
			Namespace: "citizenapp",
			Subsystem: "report",
			Name:      "submit_queue_depth",
			Help:      "Pending report submissions awaiting processing.",
		})
		lookupQueueDepth = prometheus.NewGauge(prometheus.GaugeOpts{
			Namespace: "citizenapp",
			Subsystem: "report",
			Name:      "lookup_queue_depth",
			Help:      "Pending folio lookup operations awaiting processing.",
		})
		broadcastLatency = prometheus.NewHistogram(prometheus.HistogramOpts{
			Namespace: "citizenapp",
			Subsystem: "realtime",
			Name:      "broadcast_latency_seconds",
			Help:      "Latency observed while broadcasting websocket payloads.",
			Buckets:   prometheus.ExponentialBuckets(0.0005, 2, 12),
		})
		httpRequestDuration = prometheus.NewHistogramVec(prometheus.HistogramOpts{
			Namespace: "citizenapp",
			Subsystem: "http",
			Name:      "request_duration_seconds",
			Help:      "Latency histogram for HTTP endpoints.",
			Buckets:   prometheus.DefBuckets,
		}, []string{"method", "path", "status"})
		reg.MustRegister(submitQueueDepth, lookupQueueDepth, broadcastLatency, httpRequestDuration)
	})
}

// 7.- SetReportSubmitQueueDepth actualiza el gauge con la profundidad actual.
func SetReportSubmitQueueDepth(depth int) {
	if submitQueueDepth != nil {
		submitQueueDepth.Set(float64(depth))
	}
}

// 8.- SetReportLookupQueueDepth sincroniza el gauge del pool de consultas.
func SetReportLookupQueueDepth(depth int) {
	if lookupQueueDepth != nil {
		lookupQueueDepth.Set(float64(depth))
	}
}

// 9.- ObserveBroadcastLatency reporta la duración de una difusión a los clientes.
func ObserveBroadcastLatency(duration time.Duration) {
	if broadcastLatency != nil {
		broadcastLatency.Observe(duration.Seconds())
	}
}

// 10.- ObserveHTTPRequestDuration alimenta el histograma de peticiones HTTP.
func ObserveHTTPRequestDuration(method, path string, status int, duration time.Duration) {
	if httpRequestDuration == nil {
		return
	}
	labels := httpRequestDuration.WithLabelValues(method, path, strconv.Itoa(status))
	labels.Observe(duration.Seconds())
}

// 11.- GinMetricsMiddleware mide automáticamente la latencia de cada solicitud.
func GinMetricsMiddleware() gin.HandlerFunc {
	EnsureMetrics(nil)
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		elapsed := time.Since(start)
		path := c.FullPath()
		if path == "" {
			path = "unmatched"
		}
		ObserveHTTPRequestDuration(c.Request.Method, path, c.Writer.Status(), elapsed)
	}
}

// 12.- PrometheusHandler expone el recolector estándar listo para registrarse en Gin.
func PrometheusHandler() http.Handler {
	EnsureMetrics(nil)
	return promhttp.Handler()
}
