# Utils

Esta carpeta concentra utilidades reutilizables para la capa de datos:

- `retry/`: políticas de reintento con backoff exponencial parametrizable.
- `network/`: adaptadores para mapear excepciones de red y ejecutar operaciones resilientes.
- `cache/`: envoltorios seguros para acceder a `LocalCache` de forma secuencial y con serialización tipada.

Cada helper incluye comentarios paso a paso (`//1.-`, `//2.-`, …) que documentan el flujo dentro de los métodos públicos.
