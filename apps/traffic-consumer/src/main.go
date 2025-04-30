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
	maxData    = 20
)

func main() {
	go startKafkaConsumer()

	http.HandleFunc("/", serveIndex)
	http.HandleFunc("/api/data", serveAPI)

	log.Println("🌐 Server running at http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func serveIndex(w http.ResponseWriter, r *http.Request) {
	http.ServeFile(w, r, "./static/index.html")
}

func serveAPI(w http.ResponseWriter, r *http.Request) {
	dataMutex.Lock()
	defer dataMutex.Unlock()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dataPoints)
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

		var raw map[string]interface{}
		if err := json.Unmarshal(m.Value, &raw); err != nil {
			log.Printf("⚠️ Failed to unmarshal outer message: %v", err)
			continue
		}

		messageStr, _ := raw["message"].(string)

		var msg TrafficData
		if err := json.Unmarshal([]byte(messageStr), &msg); err != nil {
			log.Printf("⚠️ Failed to unmarshal TrafficData: %v", err)
			continue
		}
		dataMutex.Lock()
		dataPoints = append(dataPoints, msg)
		if len(dataPoints) > maxData {
			dataPoints = dataPoints[1:]
		}
		dataMutex.Unlock()

		log.Printf("🚗 Cars: %d/min | 🛣️ Speed: %.2f km/h | 🚦 Density: %.2f | 🚨 Incident: %v",
			msg.CarsPerMinute, msg.AverageSpeed, msg.TrafficDensity, msg.IncidentReported)
	}
}