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

func generateRandomSolarData() map[string]interface{} {
	types := []func() map[string]interface{}{
		func() map[string]interface{} {
			return map[string]interface{}{
				"packInputPower": rand.Intn(200),
				"electricLevel":  rand.Intn(100),
				"packData": []map[string]interface{}{
					{"maxVol": rand.Intn(400), "minVol": rand.Intn(400), "sn": "CO4HMDWMEK04999"},
				},
				"sn": "EE1LYMFEM270974",
			}
		},
		func() map[string]interface{} {
			return map[string]interface{}{
				"outputHomePower": rand.Intn(500),
				"solarPower2":     rand.Intn(500),
				"electricLevel":   rand.Intn(100),
				"solarPower1":     rand.Intn(500),
				"solarInputPower": rand.Intn(600),
				"sn":              "EE1LYMFEM270974",
				"outputPackPower": rand.Intn(300),
			}
		},
		func() map[string]interface{} {
			return map[string]interface{}{
				"inverseMaxPower": rand.Intn(1000),
				"inputLimit":      rand.Intn(2000),
				"outputLimit":     rand.Intn(500),
				"acMode":          rand.Intn(5),
				"sn":              "EE1LYMFEM270974",
			}
		},
		func() map[string]interface{} {
			return map[string]interface{}{
				"wifiState":       rand.Intn(2) == 1,
				"electricLevel":   rand.Intn(100),
				"solarInputPower": rand.Intn(600),
				"buzzerSwitch":    rand.Intn(2) == 1,
				"sn":              "EE1LYMFEM270974",
				"socSet":          rand.Intn(2000),
			}
		},
		func() map[string]interface{} {
			return map[string]interface{}{
				"hubState":        rand.Intn(5),
				"remainInputTime": rand.Intn(100000),
				"packState":       rand.Intn(5),
				"sn":              "EE1LYMFEM270974",
				"remainOutTime":   rand.Intn(100000),
			}
		},
		func() map[string]interface{} {
			return map[string]interface{}{
				"gridInputPower": rand.Intn(2000),
				"electricLevel":  rand.Intn(100),
				"packData": []map[string]interface{}{
					{"socLevel": rand.Intn(100), "sn": "CO4HMDWMEK04999"},
				},
				"sn": "EE1LYMFEM270974",
			}
		},
		func() map[string]interface{} {
			return map[string]interface{}{
				"hyperTmp": rand.Intn(4000),
				"packData": []map[string]interface{}{
					{"maxVol": rand.Intn(400), "minVol": rand.Intn(400), "sn": "CO4HMDWMEK04999"},
				},
				"sn": "EE1LYMFEM270974",
			}
		},
	}
	return types[rand.Intn(len(types))]()
}

func publishToMQTT(client MQTT.Client, topic string, payload []byte) {
	token := client.Publish(topic, 0, false, payload)
	token.Wait()
}

func main() {
	rand.Seed(time.Now().UnixNano())

	opts := MQTT.NewClientOptions()
	opts.AddBroker(mqttBroker)
	opts.SetClientID("solar-producer")

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
			data := generateRandomSolarData()
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
