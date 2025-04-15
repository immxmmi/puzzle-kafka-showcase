FROM golang:1.22 AS builder
WORKDIR /app
COPY src/ ./
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o mqtt-bridge main.go

FROM alpine:latest
WORKDIR /
COPY --from=builder /app/mqtt-bridge /
RUN chmod +x /mqtt-bridge
CMD ["/mqtt-bridge"]