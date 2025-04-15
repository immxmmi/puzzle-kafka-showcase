package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/signal"
	"sync"
	"syscall"

	"github.com/segmentio/kafka-go"
)

type WeatherData struct {
	Temperature   float64 `json:"temperature"`
	Windspeed     float64 `json:"windspeed"`
	Winddirection float64 `json:"winddirection"`
	Humidity      float64 `json:"humidity"`
	Cloudcover    float64 `json:"cloudcover"`
	Windgusts     float64 `json:"windgusts"`
	Precipitation float64 `json:"precipitation"`
}

var (
	kafkaBroker        = os.Getenv("KAFKA_BROKER")
	kafkaTopic         = os.Getenv("KAFKA_TOPIC")
	kafkaConsumerGroup = os.Getenv("KAFKA_CONSUMER_GROUP")

	dataStore []WeatherData
	dataMutex sync.Mutex
)

func consumeKafkaMessages() {
	r := kafka.NewReader(kafka.ReaderConfig{
		Brokers: []string{kafkaBroker},
		Topic:   kafkaTopic,
		GroupID: kafkaConsumerGroup,
	})

	log.Printf("Kafka Consumer started in group '%s', listening on topic '%s'...\n", kafkaConsumerGroup, kafkaTopic)

	for {
		msg, err := r.ReadMessage(context.Background())
		if err != nil {
			log.Printf("Error reading from Kafka (Consumer Group: %s): %v\n", kafkaConsumerGroup, err)
			continue
		}

		var weatherData WeatherData
		err = json.Unmarshal(msg.Value, &weatherData)
		if err != nil {
			log.Printf("Error decoding message (Consumer Group: %s): %v\n", kafkaConsumerGroup, err)
			continue
		}

		dataMutex.Lock()
		dataStore = append(dataStore, weatherData)
		dataMutex.Unlock()

		log.Printf("[Consumer Group: %s] Received: Temperature %.2f°C, Wind %.2f km/h\n",
			kafkaConsumerGroup, weatherData.Temperature, weatherData.Windspeed)
	}
}

func main() {
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	go consumeKafkaMessages()

	<-sigChan
	fmt.Printf("Shutdown detected. Stopping Kafka Consumer (Group: %s)...\n", kafkaConsumerGroup)
}
