package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	MQTT "github.com/eclipse/paho.mqtt.golang"
)

var (
	mqttBroker    = os.Getenv("MQTT_BROKER")
	mqttTopic     = os.Getenv("MQTT_TOPIC")
	fetchInterval = getEnvInt("FETCH_INTERVAL", 10)
)

func getEnvInt(key string, defaultValue int) int {
	if value, exists := os.LookupEnv(key); exists {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

type TrafficData struct {
	CarsPerMinute    int     `json:"carsPerMinute"`
	AverageSpeed     float64 `json:"averageSpeed"`
	TrafficDensity   float64 `json:"trafficDensity"`
	IncidentReported bool    `json:"incidentReported"`
}

func generateRandomTrafficData() *TrafficData {
	return &TrafficData{
		CarsPerMinute:    rand.Intn(500),
		AverageSpeed:     rand.Float64()*100.0 + 10.0,
		TrafficDensity:   rand.Float64(),
		IncidentReported: rand.Intn(10) == 0, // 10% Chance für einen Vorfall
	}
}

func publishToMQTT(client MQTT.Client, topic string, payload []byte) {
	token := client.Publish(topic, 0, false, payload)
	token.Wait()
}

func main() {
	rand.Seed(time.Now().UnixNano())

	opts := MQTT.NewClientOptions()
	opts.AddBroker(mqttBroker)
	opts.SetClientID("mqqt-producer")

	client := MQTT.NewClient(opts)
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		fmt.Println("MQTT Connection failed:", token.Error())
		return
	}
	defer client.Disconnect(250)

	ticker := time.NewTicker(time.Duration(fetchInterval) * time.Second)
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	fmt.Printf("Starting MQTT publisher with interval: %d seconds\n", fetchInterval)

	for {
		select {
		case <-ticker.C:
			data := generateRandomTrafficData()
			payload, err := json.Marshal(data)
			if err != nil {
				fmt.Println("Error encoding JSON:", err)
				continue
			}
			publishToMQTT(client, mqttTopic, payload)
			fmt.Println("Published:", string(payload))

		case <-sigChan:
			fmt.Println("Shutting down...")
			ticker.Stop()
			return
		}
	}
}
