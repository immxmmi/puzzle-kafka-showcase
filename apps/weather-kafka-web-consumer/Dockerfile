FROM golang:1.22 AS builder
WORKDIR /app/src
COPY src/ ./
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o ../kafka-consumer main.go

FROM alpine:latest
WORKDIR /
COPY --from=builder /app/kafka-consumer /
COPY --from=builder /app/src/static /static
RUN chmod +x /kafka-consumer
EXPOSE 8080
CMD ["/kafka-consumer"]