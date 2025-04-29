package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"sync"

	"github.com/segmentio/kafka-go"
)

type TrafficData struct {
	CarsPerMinute    int     `json:"carsPerMinute"`
	AverageSpeed     float64 `json:"averageSpeed"`
	TrafficDensity   float64 `json:"trafficDensity"`
	IncidentReported bool    `json:"incidentReported"`
}

var (
	dataPoints []TrafficData
	dataMutex  sync.Mutex
	maxData    = 100
)

func main() {
	go startKafkaConsumer()

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		http.ServeFile(w, r, "./static/index.html")
	})

	http.HandleFunc("/api/data", func(w http.ResponseWriter, r *http.Request) {
		dataMutex.Lock()
		defer dataMutex.Unlock()
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(dataPoints)
	})

	log.Println("🌐 Server running at http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func startKafkaConsumer() {
	broker := os.Getenv("KAFKA_BROKER")
	topic := os.Getenv("KAFKA_TOPIC")
	if broker == "" || topic == "" {
		log.Fatal("KAFKA_BROKER and KAFKA_TOPIC must be set")
	}

	r := kafka.NewReader(kafka.ReaderConfig{
		Brokers: []string{broker},
		Topic:   topic,
		GroupID: "web-consumer-group",
	})
	defer r.Close()

	for {
		m, err := r.ReadMessage(context.Background())
		if err != nil {
			log.Printf("❌ Kafka read error: %v", err)
			continue
		}

		var msg TrafficData
		if err := json.Unmarshal(m.Value, &msg); err != nil {
			log.Printf("⚠️ Failed to unmarshal message: %v", err)
			continue
		}

		dataMutex.Lock()
		dataPoints = append(dataPoints, msg)
		if len(dataPoints) > maxData {
			dataPoints = dataPoints[1:]
		}
		dataMutex.Unlock()

		log.Printf("🚗 Cars/Min: %d | Avg Speed: %.2f km/h | Density: %.2f | Incident: %v",
			msg.CarsPerMinute, msg.AverageSpeed, msg.TrafficDensity, msg.IncidentReported)
	}
}