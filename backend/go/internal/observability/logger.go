package observability

import (
	"os"
	"sync"

	"github.com/rs/zerolog"
)

var (
	// 1.- loggerOnce evita inicializar el registrador más de una vez.
	loggerOnce sync.Once
	// 2.- baseLogger conserva la instancia compartida para todo el proceso.
	baseLogger zerolog.Logger
)

// 3.- Logger devuelve un apuntador a un logger estructurado y con timestamp.
func Logger() *zerolog.Logger {
	loggerOnce.Do(func() {
		output := zerolog.New(os.Stdout).With().Timestamp().Str("app", "citizenapp-backend").Logger()
		baseLogger = output
	})
	return &baseLogger
}

// 4.- NamedLogger clona el logger principal y agrega la etiqueta component.
func NamedLogger(component string) zerolog.Logger {
	return Logger().With().Str("component", component).Logger()
}
