FROM golang:1.22 AS builder
WORKDIR /app
COPY src/ ./
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o mqqt-producer main.go

FROM alpine:latest
WORKDIR /
COPY --from=builder /app/mqqt-producer /
RUN chmod +x /mqqt-producer
CMD ["/mqqt-producer"]