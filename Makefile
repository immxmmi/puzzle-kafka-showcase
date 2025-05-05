SHELL := /bin/bash
.DEFAULT_GOAL := help
# ANSI Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

# ANSI Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m


# Global Variables
MINIKUBE_IP := localhost
PORT := 8088
DEPLOY_TOKEN := yywHmUryjzznt15dM_nH
DEPLOY_USER := argocd-deploy

# KAFKA Variables
KAFKA_NAMESPACE := kafka
ARGOCD_APP := mykafka
KAFKA_CLUSTER_NAME := $(ARGOCD_APP)-cluster
KAFKA_BOOTSTRAP := $(KAFKA_CLUSTER_NAME)-kafka-bootstrap:9092
CONSUMER_GROUP := Group-A

help:
	@echo "═══════════════════════════════════════════════"
	@echo "🚀 Available Commands for Kafka Showcase Setup"
	@echo "═══════════════════════════════════════════════"
	@echo ""
	@echo "🔧 Required Setup:"
	@echo "  strimzi_operator_install        ▶️  Install Strimzi Operator"
	@echo "  strimzi_operator_uninstall      ▶️  Uninstall Strimzi Operator"
	@echo "  argocd_install                  ▶️  Install ArgoCD via Helm"
	@echo "  argocd_uninstall                ▶️  Uninstall ArgoCD"
	@echo "  argocd_start                    ▶️  Port-forward ArgoCD to localhost"
	@echo ""
	@echo "🧱 Cluster Management:"
	@echo "  kafka_create_simple_cluster              ▶️  Create a simple Kafka cluster"
	@echo "  kafka_destroy_simple_cluster             ▶️  Delete the simple Kafka cluster"
	@echo "  kafka_create_simple_cluster_persistent   ▶️  Create Kafka with persistent volumes"
	@echo "  kafka_destroy_simple_cluster_persistent  ▶️  Delete Kafka with persistent volumes"
	@echo "  check_kafka_cluster_status               ▶️  Check Kafka cluster status"
	@echo ""
	@echo "📦 Showcase Management:"
	@echo "  kafka_showcaseadd_solar_system           ▶️  Add 'weather-system' showcase"
	@echo "  kafka_showcase_remove_solar_system       ▶️  Remove 'weather-system' showcase"
	@echo "  kafka_showcase_add_traffic_system        ▶️  Add 'traffic-system' showcase"
	@echo "  kafka_showcase_remove_traffic_system     ▶️  Remove 'traffic-system' showcase"
	@echo "  kafka_showcase_solar_system_gui          ▶️  Open weather-system web consumer"
	@echo ""
	@echo "🌐 UI Tools:"
	@echo "  kafka_ui_install                         ▶️  Install Kafka UI"
	@echo "  kafka_ui_start                           ▶️  Port-forward Kafka UI"
	@echo "  kafka_ui_uninstall                       ▶️  Uninstall Kafka UI"
	@echo ""
	@echo "📚 Kafka Management:"
	@echo "  kafka_cluster_topics                     ▶️  List Kafka topics"
	@echo "  kafka_cluster_describe                   ▶️  Describe a Kafka topic (use TOPIC=...)"
	@echo "  kafka_cluster_partitions                 ▶️  View partition info"
	@echo ""
	@echo "⚖️  Kafka Rebalancing:"
	@echo "  kafka_cluster_auto-rebalnce              ▶️  Trigger automatic rebalance"
	@echo "  kafka_cluster_upscale-rebalance          ▶️  Rebalance after adding broker"
	@echo "  kafka_cluster_downscale-rebalance        ▶️  Rebalance before removing broker"
	@echo ""
	@echo "📈 Scaling:"
	@echo "  kafka_cluster_add_broker                 ▶️  Add Kafka broker"
	@echo "  kafka_cluster_remove_broker              ▶️  Remove Kafka broker"
	@echo ""
	@echo "💻 Minikube:"
	@echo "  minikube_start                           ▶️  Start Minikube"
	@echo "  minikube_stop                            ▶️  Stop Minikube"
	@echo "  minikube_destroy                         ▶️  Delete Minikube"
	@echo ""
	@echo "📘 Run 'make <command>' to execute a specific task."
	@echo "═══════════════════════════════════════════════"

minikube_start:
	@echo "🚀 Starting Minikube..."
	@minikube start --driver=docker --memory=4000 --cpus=3 --force

minikube_stop:
	@echo "🛑 Stopping Minikube..."
	@minikube stop

minikube_destroy:
	@echo "🗑️  Destroying Minikube..."
	@minikube delete
	@echo -e "$(GREEN)✅ Minikube has been destroyed.$(NC)"
# ─────────────────────────────────────────────────────────────
# 🧭 ArgoCD – Setup, Login & Projektanbindung
# ─────────────────────────────────────────────────────────────

argocd_install:
	@helm repo add argo https://argoproj.github.io/argo-helm
	@helm repo update
	@helm install argocd argo/argo-cd --version 7.8.11 --namespace argocd --create-namespace
	@echo "Waiting for ArgoCD to be ready..."
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
	@echo "ArgoCD is ready!"

argocd_credentials:
	@echo "🔐 Getting ArgoCD credentials..."
	@PASSWORD=$$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode); \
	if [[ -z "$$PASSWORD" ]]; then \
	  echo "❌ Secret 'argocd-initial-admin-secret' not found. It may have been overridden via Helm values."; \
	else \
	  echo "🪪 Credentials for ArgoCD Login:"; \
	  echo "  username: admin"; \
	  echo "  password: $$PASSWORD"; \
	fi
argocd_start:
	@kubectl port-forward svc/argocd-server -n argocd 8088:443 > /dev/null 2>&1 &
	@echo "ArgoCD is available at http://localhost:8088/"
	@make argocd_credentials


argocd_uninstall:
	@echo "🧹 Uninstalling ArgoCD..."
	@helm uninstall argocd --namespace argocd
	@kubectl delete namespace argocd --ignore-not-found
	@echo -e "$(GREEN)✅ ArgoCD has been uninstalled."


# ─────────────────────────────────────────────────────────────
# 🧰 Installation & Deinstallation – Strimzi, ArgoCD, UIs
# ─────────────────────────────────────────────────────────────

strimzi_operator_install:
	@echo "🚀 Installing Strimzi Operator via ArgoCD Application..."
	@kubectl apply -f strimzi/application.yaml
	@echo -e "$(GREEN)✅ Strimzi Operator Application has been applied via ArgoCD.$(NC)"

strimzi_operator_uninstall:
	@echo "🧹 Uninstalling Strimzi Operator Application from ArgoCD..."
	@kubectl delete -f strimzi/application.yaml --ignore-not-found
	@kubectl delete namespace $(KAFKA_NAMESPACE) --ignore-not-found
	@echo -e "$(GREEN)✅ Strimzi Operator has been removed via ArgoCD.$(NC)"


# ─────────────────────────────────────────────────────────────
# ☁️ Kafka Cluster Management – Simple / Persistent / NodePool
# ─────────────────────────────────────────────────────────────

kafka_create_simple_cluster:
	@echo "Creating Simple Kafka Cluster - $(KAFKA_CLUSTER_NAME) - ..."
	@kubectl apply -f strimzi/cluster/simple-cluster/ephemeral/application.yaml --namespace $(KAFKA_NAMESPACE)
	@$(MAKE) _wait_for_kafka_ready
	@echo "Kafka Cluster - $(KAFKA_CLUSTER_NAME) - is now Ready!"

kafka_destroy_simple_cluster:
	@echo "Deleting Simple Kafka Cluster - $(KAFKA_CLUSTER_NAME) - ..."
	@kubectl delete -f strimzi/cluster/simple-cluster.yaml --namespace $(KAFKA_NAMESPACE)
	@echo "Kafka Cluster - $(KAFKA_CLUSTER_NAME) - is now deleted!"

kafka_create_simple_cluster_persistent:
	@echo "Creating Simple Kafka Cluster - $(KAFKA_CLUSTER_NAME) - with Persistent Volume..."
	@echo "Creating directories in Minikube for hostPath volumes..."
	@minikube ssh -- "sudo mkdir -p /data/zookeeper-0 /data/zookeeper-1 /data/zookeeper-2 /data/kafka-0 /data/kafka-1; sudo chmod -R 777 /data; sudo chown -R 1000:1000 /data"
	@kubectl apply -f strimzi/cluster/simple-cluster/ephemeral/application.yaml --namespace $(KAFKA_NAMESPACE)
	@$(MAKE) _wait_for_kafka_ready
	@echo "Kafka Cluster - $(KAFKA_CLUSTER_NAME) - is now Ready!"
 
kafka_destroy_simple_cluster_persistent:
	@echo "Deleting Simple Kafka Cluster - $(KAFKA_CLUSTER_NAME) - with Persistent Volume..."
	@kubectl delete -f sstrimzi/cluster/simple-cluster/persistent/application.yaml --namespace
	@kubectl delete pvc -n kafka --all
	@echo "Removing directories in Minikube used for Persistent Volumes..."
	@minikube ssh -- "sudo rm -rf /data/zookeeper-* /data/kafka-*"
	@echo "Kafka Cluster - $(KAFKA_CLUSTER_NAME) - is now deleted!"

_create_simple_cluster_with_nodepool:
	@echo "Creating Kafka Cluster - $(KAFKA_CLUSTER_NAME) - with NodePool..."
	@kubectl apply -f sstrimzi/cluster/simple-cluster-nodepool/ephemeral/application.yaml --namespace $(KAFKA_NAMESPACE)
	@$(MAKE) _wait_for_kafka_ready
	@echo "Kafka Cluster - $(KAFKA_CLUSTER_NAME) - with NodePool is now Ready!"

_destroy_simple_cluster_with_nodepool:
	@echo "Deleting Kafka Cluster - $(KAFKA_CLUSTER_NAME) - with NodePool..."
	@kubectl delete -f strimzi/cluster/simple-cluster-nodepool/ephemeral/application.yaml--namespace $(KAFKA_NAMESPACE)
	@echo "Kafka Cluster - $(KAFKA_CLUSTER_NAME) - with NodePool is now deleted!"


# ─────────────────────────────────────────────────────────────
# 🌐 UI Zugriff – Kafka UI
# ─────────────────────────────────────────────────────────────

kafka_ui_install:
	@kubectl apply -f kafka-ui/application.yaml
	@echo -e "$(GREEN)✅ Kafka UI installed successfully!$(NC)"

kafka_ui_start:
	@kubectl -n kafka-ui port-forward services/kafka-ui-service 8089:8080 > /dev/null 2>&1 &
	@sleep 3
	@echo "🌐 Kafka UI is available at http://localhost:8089/"


kafka_ui_uninstall:
	@echo "🧹 Uninstalling Kafka UI..."
	@kubectl delete -f ui/kafka-ui/application.yaml
	@echo -e "$(GREEN)✅ Kafka UI has been uninstalled.$(NC)"

# ─────────────────────────────────────────────────────────────
# 📦  Kafka Showcase
# ─────────────────────────────────────────────────────────────

kafka_showcase_weather_system_add:
	@echo "🚀 Adding ApplicationSet 'weather-system' to Kafka Cluster..."
	@echo "Creating topics and deploying applications..."
	@kubectl apply -f strimzi/topics/weather-system/application.yaml -n $(KAFKA_NAMESPACE)
	@kubectl apply -f showcase/weather-system/application.yaml
	@echo -e "$(GREEN)✅ Weather System added. ArgoCD will now sync your applications."

kafka_showcase_weather_system_start:
	@kubectl -n weather-system port-forward services/weather-system-kafka-web-consumer-service 3099:8080 > /dev/null 2>&1 &
	@echo "🌐 Kafka Web Consumer is available at http://localhost:3099/"
	@echo -e "$(GREEN)✅ ApplicationSet 'weather-system' added. ArgoCD will now sync your applications."

kafka_showcase_weather_system_remove:
	@echo "🧹 Removing ApplicationSet 'weather-system' from Kafka Cluster..."
	@kubectl delete -f strimzi/topics/weather-system/application.yaml -n $(KAFKA_NAMESPACE)
	@kubectl delete -f showcase/weather-system/application.yaml
	@echo -e "$(GREEN)✅  ApplicationSet 'weather-system' removed. Namespaces and apps may still exist depending on sync policy." a


kafka_showcase_solar_system_add:
	@echo "🚀 Adding ApplicationSet 'solar-system' to Kafka Cluster..."
	@echo "Creating topics and deploying applications..."
	@kubectl apply -f strimzi/topics/solar-system/application.yaml -n $(KAFKA_NAMESPACE)
	@kubectl apply -f showcase/solar-system/application.yaml
	@echo -e "$(GREEN)✅ Solar System added. ArgoCD will now sync your applications."

kafka_showcase_solar_system_start:
	@kubectl -n solar-system port-forward services/solar-system-kafka-web-consumer-service 3098:8080 > /dev/null 2>&1 &
	@echo "🌐 Kafka Web Consumer is available at http://localhost:3098/"
	@echo -e "$(GREEN)✅ ApplicationSet 'solar-system' added. ArgoCD will now sync your applications."

kafka_showcase_solar_system_remove:
	@echo "🧹 Removing ApplicationSet 'solar-system' from Kafka Cluster..."
	@kubectl delete -f strimzi/topics/solar-system/applicaion.yaml -n $(KAFKA_NAMESPACE)
	@kubectl delete -f showcase/solar-system/application.yaml
	@echo -e "$(GREEN)✅  ApplicationSet 'solar-system' removed. Namespaces and apps may still exist depending on sync policy." a

kafka_showcase_traffic_system_add:
	@echo "🚀 Adding Traffic System to Kafka Cluster..."
	@echo "Creating topics and deploying applications..."
	@kubectl apply -f strimzi/topics/traffic-system/application.yaml -n $(KAFKA_NAMESPACE)
	@kubectl apply -f showcase/traffic-system/application.yaml
	@echo -e "$(GREEN)✅ Traffic System added. ArgoCD will now sync your applications."

kafka_showcase_remove_traffic_system:
	@echo "🧹 Removing Traffic System from Kafka Cluster..."
	@kubectl delete -f strimzi/topics/traffic-system/application.yaml -n $(KAFKA_NAMESPACE)
	@kubectl delete -f showcase/traffic-system/application.yaml
	@echo -e "$(GREEN)✅ Traffic System removed. Namespaces and apps may still exist depending on sync policy."

kafka_showcase_traffic_system_gui:
	@kubectl -n traffic-system port-forward services/traffic-system-kafka-web-consumer-service 3097:8080 > /dev/null 2>&1 &
	@echo "🌐 Kafka Web Consumer is available at http://localhost:3097/"
	@echo -e "$(GREEN)✅ ApplicationSet 'traffic-system' added. ArgoCD will now sync your applications."

# ─────────────────────────────────────────────────────────────
# 📈 Cluster Status / Health
# ─────────────────────────────────────────────────────────────

_wait_for_kafka_ready:
	@kubectl wait kafka/$(KAFKA_CLUSTER_NAME) --for=condition=Ready --timeout=300s --namespace $(KAFKA_NAMESPACE)
	@kubectl get kafka --namespace $(KAFKA_NAMESPACE)

check_kafka_cluster_status:
	@echo "🔍 Checking Kafka Cluster status in namespace '$(KAFKA_NAMESPACE)'..."
	@kubectl get kafka $(KAFKA_CLUSTER_NAME) -n $(KAFKA_NAMESPACE) -o jsonpath="{.status}" | jq
	@kubectl get pods -n $(KAFKA_NAMESPACE) -l strimzi.io/cluster=$(KAFKA_CLUSTER_NAME) -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[*].ready

# ─────────────────────────────────────────────────────────────
# 🧪 Kafka Management – Topics, Partitionen, Storage
# ─────────────────────────────────────────────────────────────

kafka_cluster_topics:
	@kubectl exec -n $(KAFKA_NAMESPACE) -it $(KAFKA_CLUSTER_NAME)-kafka-0 -- /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092

kafka_cluster_describe:
	@kubectl exec -n $(KAFKA_NAMESPACE) -it $(KAFKA_CLUSTER_NAME)-kafka-0 -- /opt/kafka/bin/kafka-topics.sh --describe --topic $(TOPIC) --bootstrap-server localhost:9092

kafka_cluster_partitions:
	@kubectl exec -n $(KAFKA_NAMESPACE) -it $(KAFKA_CLUSTER_NAME)-kafka-0 -- /opt/kafka/bin/kafka-log-dirs.sh --bootstrap-server localhost:9092 --describe

# 📌 Kafka Rebalance
approve_rebalance:
	@echo "📌 Annotating KafkaRebalance '$(REBALANCE_NAME)' to approve the proposal:"
	@echo "    kubectl annotate kafkarebalance $(REBALANCE_NAME) strimzi.io/rebalance=approve -n $(KAFKA_NAMESPACE)"
	@kubectl annotate kafkarebalance $(REBALANCE_NAME) strimzi.io/rebalance=approve --overwrite -n $(KAFKA_NAMESPACE)
	@echo -e "$(GREEN)✅ Rebalance '$(REBALANCE_NAME)' has been approved."

wait_for_rebalance_status:
	@echo "⏳ Waiting for KafkaRebalance '$(REBALANCE_NAME)' to reach 'ProposalReady' status..."
	@while [[ "$$(kubectl get kafkarebalance -n $(KAFKA_NAMESPACE) $(REBALANCE_NAME) -o custom-columns=STATUS:.status.conditions[0].type --no-headers)" != "ProposalReady" ]]; do \
		echo "🔄 Waiting for ProposalReady..."; sleep 30; \
	done
	@echo -e "$(GREEN)✅ KafkaRebalance '$(REBALANCE_NAME)' is ProposalReady."
	@$(MAKE) approve_rebalance REBALANCE_NAME=$(REBALANCE_NAME)
	@echo "⏳ Waiting for KafkaRebalance '$(REBALANCE_NAME)' to reach 'Ready' status..."
	@while [[ "$$(kubectl get kafkarebalance $(REBALANCE_NAME) -n $(KAFKA_NAMESPACE) -o json | jq -r '.status.conditions[] | select(.type=="Ready") | .status')" != "True" ]]; do \
		echo "🔄 Waiting for Ready..."; sleep 30; \
	done
	@echo -e "$(GREEN)✅ KafkaRebalance '$(REBALANCE_NAME)' is complete!"
	@kubectl get kafkarebalance $(REBALANCE_NAME) -n $(KAFKA_NAMESPACE)
	@$(MAKE) cleanup_rebalance REBALANCE_NAME=$(REBALANCE_NAME)

cleanup_rebalance:
	@echo "🧹 Cleaning up KafkaRebalance '$(REBALANCE_NAME)'..."
	@kubectl delete kafkarebalance $(REBALANCE_NAME) -n $(KAFKA_NAMESPACE) --ignore-not-found
	@echo -e "$(GREEN)✅ KafkaRebalance '$(REBALANCE_NAME)' deleted."

kafka_cluster_add_broker:
	@echo "═══════════════════════════════════════════════"
	@echo "📈 Adding Kafka Broker to Cluster '$(KAFKA_CLUSTER_NAME)'..."
	@CURRENT=$$(kubectl get kafka $(KAFKA_CLUSTER_NAME) -n $(KAFKA_NAMESPACE) -o jsonpath="{.spec.kafka.replicas}"); \
	echo "🔢 Current number of brokers: $$CURRENT"
	@echo "🔼 Scaling up Kafka cluster '$(KAFKA_CLUSTER_NAME)' by 1 broker..."
	@REPLICAS=$$(kubectl get kafka $(KAFKA_CLUSTER_NAME) -n $(KAFKA_NAMESPACE) -o jsonpath="{.spec.kafka.replicas}"); \
	NEW_REPLICAS=$$((REPLICAS + 1)); \
	kubectl patch kafka $(KAFKA_CLUSTER_NAME) -n $(KAFKA_NAMESPACE) --type=merge -p "{\"spec\":{\"kafka\":{\"replicas\":$$NEW_REPLICAS}}}"
	@echo "⏳ Waiting for new Kafka broker pod to be ready..."
	@$(MAKE) _wait_for_kafka_ready
	@FINAL=$$(kubectl get kafka $(KAFKA_CLUSTER_NAME) -n $(KAFKA_NAMESPACE) -o jsonpath="{.spec.kafka.replicas}"); \
	echo -e "$(GREEN)✅ Number of brokers after scale-up: $$FINAL"
	@echo "Please Manually Update strimzi/rebalance/upscale-rebalance.yaml with new broker ID: $$FINAL"
	#@echo "═══════════════════════════════════════════════"

kafka_cluster_remove_broker:
	@echo "═══════════════════════════════════════════════"
	@echo "📉 Removing a Kafka Broker from Cluster '$(KAFKA_CLUSTER_NAME)'..."
	@CURRENT=$$(kubectl get kafka $(KAFKA_CLUSTER_NAME) -n $(KAFKA_NAMESPACE) -o jsonpath="{.spec.kafka.replicas}"); \
	if [[ $$CURRENT -le 1 ]]; then \
		echo -e "$(RED)❌ Cannot remove broker: only $$CURRENT broker(s) present."; \
		exit 1; \
	fi; \
	echo "🔽 Current number of brokers: $$CURRENT"; \
	NEW_REPLICAS=$$((CURRENT - 1)); \
	echo "🧹 Scaling down Kafka cluster '$(KAFKA_CLUSTER_NAME)' to $$NEW_REPLICAS broker(s)..."; \
	kubectl patch kafka $(KAFKA_CLUSTER_NAME) -n $(KAFKA_NAMESPACE) --type=merge -p "{\"spec\":{\"kafka\":{\"replicas\":$$NEW_REPLICAS}}}"; \
	echo "⏳ Waiting for Kafka cluster to be ready..."; \
	$(MAKE) _wait_for_kafka_ready; \
	echo -e "$(GREEN)✅ Number of brokers after scale-down: $$NEW_REPLICAS"
	@echo "Please Manually Update strimzi/rebalance/downscale-rebalance.yaml with new broker ID: $$FINAL"
	@echo "═══════════════════════════════════════════════"

kafka_cluster_auto-rebalnce:
	@kubectl apply -f strimzi/rebalance/auto-rebalance.yaml
	@$(MAKE) wait_for_rebalance_status REBALANCE_NAME=auto-rebalance

kafka_cluster_upscale-rebalance:
	@kubectl apply -f strimzi/rebalance/upscale-rebalance.yaml
	@$(MAKE) wait_for_rebalance_status REBALANCE_NAME=upscale-rebalance