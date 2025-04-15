package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/segmentio/kafka-go"
)

// Configurable settings
var (
	mqttBroker    = os.Getenv("MQTT_BROKER")
	mqttTopic     = os.Getenv("MQTT_TOPIC")
	kafkaBroker   = os.Getenv("KAFKA_BROKER")
	kafkaTopic    = os.Getenv("KAFKA_TOPIC")
	kafkaBalancer = os.Getenv("KAFKA_BALANCER")
)

// Get Kafka Balancer based on environment variable
func getKafkaBalancer() kafka.Balancer {
	switch strings.ToLower(kafkaBalancer) {
	case "leastbytes":
		log.Println("Kafka Balancer: LeastBytes (chooses the partition with the least load)")
		return &kafka.LeastBytes{}
	case "hash":
		log.Println("Kafka Balancer: Hash (distributes messages based on the key)")
		return &kafka.Hash{}
	default:
		log.Println("Kafka Balancer: RoundRobin (evenly distributes messages)")
		return &kafka.RoundRobin{}
	}
}

// MQTT Message Handler
func messageHandler(client mqtt.Client, msg mqtt.Message) {
	timestamp := time.Now().Format("02012006150405") // Format: DDMMYYYYHHMMSS
	fmt.Printf("[%s] Received MQTT message on topic: %s\n", timestamp, msg.Topic())

	// Mapping logic: Convert MQTT topic to Kafka topic dynamically
	mappedTopic := strings.ReplaceAll(msg.Topic(), "/", "-")
	if kafkaTopic != "" {
		mappedTopic = kafkaTopic
	}

	// Publish to Kafka
	publishToKafka(mappedTopic, msg.Payload(), timestamp)
}

// Kafka Producer Function
func publishToKafka(topic string, message []byte, timestamp string) {
	data := map[string]interface{}{
		"timestamp": timestamp,
		"message":   string(message),
	}

	jsonData, err := json.Marshal(data)
	if err != nil {
		log.Printf("[%s] Failed to marshal message to JSON: %v", timestamp, err)
		return
	}

	writer := kafka.NewWriter(kafka.WriterConfig{
		Brokers:  []string{kafkaBroker},
		Topic:    topic,
		Balancer: getKafkaBalancer(),
	})
	defer writer.Close()

	// Use a dynamic key for better partition distribution
	key := []byte(fmt.Sprintf("%s-%s", topic, timestamp))

	msg := kafka.Message{
		Key:   key,
		Value: jsonData,
	}

	if err := writer.WriteMessages(context.Background(), msg); err != nil {
		log.Printf("[%s] Failed to write message to Kafka: %v", timestamp, err)
	} else {
		log.Printf("[%s] Message published to Kafka topic: %s (Key: %s)", timestamp, topic, string(key))
	}
}

func main() {
	// Display configuration before starting
	log.Println("Starting MQTT-Kafka Bridge...")
	log.Printf("MQTT Broker: %s", mqttBroker)
	log.Printf("MQTT Topic: %s", mqttTopic)
	log.Printf("Kafka Broker: %s", kafkaBroker)
	log.Printf("Kafka Topic: %s", kafkaTopic)
	log.Printf("Kafka Balancer: %s", kafkaBalancer)

	opts := mqtt.NewClientOptions().AddBroker(mqttBroker)
	opts.SetDefaultPublishHandler(messageHandler)

	client := mqtt.NewClient(opts)
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		log.Fatalf("MQTT Connection failed: %v", token.Error())
	}

	if token := client.Subscribe(mqttTopic, 0, messageHandler); token.Wait() && token.Error() != nil {
		log.Fatalf("MQTT Subscription failed: %v", token.Error())
	}

	log.Println("MQTT-Kafka Bridge is running...")
	select {}
}
