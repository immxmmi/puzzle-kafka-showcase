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

type SolarData struct {
	Timestamp        string  `json:"timestamp"`
	SolarInputPower  float64 `json:"solarInputPower"`
	OutputHomePower  float64 `json:"outputHomePower"`
	ElectricLevel    float64 `json:"electricLevel"`
	OutputPackPower  float64 `json:"outputPackPower"`
}

var (
	dataPoints []SolarData
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
		GroupID: "web-consumer-solar-group",
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

		timestamp, _ := raw["timestamp"].(string)
		messageStr, _ := raw["message"].(string)

		var msg SolarData
		if err := json.Unmarshal([]byte(messageStr), &msg); err != nil {
			log.Printf("⚠️ Failed to unmarshal inner message: %v", err)
			continue
		}
		msg.Timestamp = timestamp

		dataMutex.Lock()
		dataPoints = append(dataPoints, msg)
		if len(dataPoints) > maxData {
			dataPoints = dataPoints[1:]
		}
		dataMutex.Unlock()

		log.Printf("📥 %s | SolarInputPower: %.2f | OutputHomePower: %.2f | ElectricLevel: %.2f | OutputPackPower: %.2f",
			msg.Timestamp, msg.SolarInputPower, msg.OutputHomePower, msg.ElectricLevel, msg.OutputPackPower)
	}
}