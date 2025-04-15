package main

import (
	"encoding/json"
	"fmt"
	"io"
	"math/rand"
	"net/http"
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
	apiURL        = os.Getenv("WEATHER_API_URL")
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

type WeatherData struct {
	CurrentWeather struct {
		Temperature   float64 `json:"temperature"`
		Windspeed     float64 `json:"windspeed"`
		Winddirection float64 `json:"winddirection"`
	} `json:"current_weather"`
	Hourly struct {
		RelativeHumidity2m []float64 `json:"relative_humidity_2m"`
		Cloudcover         []float64 `json:"cloudcover"`
		Windgusts10m       []float64 `json:"windgusts_10m"`
		Precipitation      []float64 `json:"precipitation"`
	} `json:"hourly"`
}

func fetchWeatherData() (*WeatherData, error) {
	if apiURL == "" {
		return generateRandomWeatherData(), nil
	}

	resp, err := http.Get(apiURL)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var data WeatherData
	err = json.Unmarshal(body, &data)
	if err != nil {
		return nil, err
	}

	return &data, nil
}

func generateRandomWeatherData() *WeatherData {
	return &WeatherData{
		CurrentWeather: struct {
			Temperature   float64 `json:"temperature"`
			Windspeed     float64 `json:"windspeed"`
			Winddirection float64 `json:"winddirection"`
		}{
			Temperature:   rand.Float64()*30 - 5,
			Windspeed:     rand.Float64() * 20,
			Winddirection: rand.Float64() * 360,
		},
		Hourly: struct {
			RelativeHumidity2m []float64 `json:"relative_humidity_2m"`
			Cloudcover         []float64 `json:"cloudcover"`
			Windgusts10m       []float64 `json:"windgusts_10m"`
			Precipitation      []float64 `json:"precipitation"`
		}{
			RelativeHumidity2m: []float64{rand.Float64() * 100},
			Cloudcover:         []float64{rand.Float64() * 100},
			Windgusts10m:       []float64{rand.Float64() * 30},
			Precipitation:      []float64{rand.Float64()},
		},
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
			data, err := fetchWeatherData()
			if err != nil {
				fmt.Println("Error fetching weather data:", err)
				continue
			}

			payload, err := json.Marshal(map[string]interface{}{
				"temperature":   data.CurrentWeather.Temperature,
				"windspeed":     data.CurrentWeather.Windspeed,
				"winddirection": data.CurrentWeather.Winddirection,
				"humidity":      data.Hourly.RelativeHumidity2m[0],
				"cloudcover":    data.Hourly.Cloudcover[0],
				"windgusts":     data.Hourly.Windgusts10m[0],
				"precipitation": data.Hourly.Precipitation[0],
			})

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
