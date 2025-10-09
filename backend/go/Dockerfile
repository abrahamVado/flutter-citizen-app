# //1.- Etapa de construcción: descarga dependencias y compila el binario.
FROM golang:1.23-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -o /app/bin/server ./cmd/server

# //2.- Etapa final: imagen ligera lista para producción.
FROM alpine:3.20
RUN adduser -D -g '' citizen && apk add --no-cache ca-certificates
WORKDIR /home/citizen/app
COPY --from=builder /app/bin/server ./server
EXPOSE 8080
ENV PORT=8080
USER citizen
ENTRYPOINT ["./server"]
