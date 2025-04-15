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
	@echo "  install_strmzi     ▶️  Install Strimzi Operator"
	@echo "  uninstall_strimzi     ▶️  Uninstall Strimzi Operator"
	@echo "  install_argocd     ▶️  Deploy ArgoCD and configure repository"
	@echo "  uninstall_argocd      ▶️  Uninstall ArgoCD"
	@echo "  install_argocd_cli  ▶️  Install ArgoCD CLI via Homebrew (macOS only)"
	@echo "  login_argocd        ▶️  Login to ArgoCD with default credentials"
	@echo "  start_argocd       ▶️  Start ArgoCD and port-forward to localhost"
	@echo "  add_argocd_project     ▶️  Register private GitLab repo in ArgoCD using deploy token"
	@echo ""
	@echo "🧱 Cluster Management:"
	@echo "  create_simple_cluster                  ▶️  Create a Simple Kafka Cluster"
	@echo "  destroy_simple_cluster                 ▶️  Delete the Simple Kafka Cluster"
	@echo "  create_simple_cluster_persistent       ▶️  Create Kafka Cluster with Persistent Volume"
	@echo "  destroy_simple_cluster_persistent      ▶️  Delete Kafka Cluster with Persistent Volume"
	@echo "  check_kafka_cluster_status               ▶️  Check Kafka Cluster status"
	@echo "📦 ArgoCD Applications:"
	@echo "  add_showcase_solar     ▶️  Add the 'solar-system' ApplicationSet to ArgoCD"
	@echo ""
	@echo "📊 Kafka UI Access:"
	@echo "  install_kafka_ui     ▶️  Install Kafka UI"
	@echo "  start_kafka_ui       ▶️  Start port-forwarding to Kafka UI"
	@echo "  uninstall_kafka_ui    ▶️  Uninstall Kafka UI"
	@echo ""
	@echo "📊 AKHQ UI Access:"
	@echo "  install_akhq_ui     ▶️  Install AKHQ UI"
	@echo "  uninstall_akhq_ui    ▶️  Uninstall AKHQ UI"
	@echo ""
	@echo "📚 Kafka Management:"
	@echo "  topics                 ▶️  List all Kafka topics"
	@echo "  describe               ▶️  Describe a specific Kafka topic (use: make describe TOPIC=my-topic)"
	@echo "  partitions             ▶️  View partition information"
	@echo ""
	@echo "📘 Run 'make <command>' to execute a specific task."
	@echo ""
	@echo "⚖️  Kafka Rebalance:"
	@echo "  auto-rebalnce           ▶️  Trigger automatic Kafka rebalancing"
	@echo "  upscale-rebalance       ▶️  Trigger rebalancing after adding a broker"
	@echo "  downscale-rebalance     ▶️  Trigger rebalancing before removing a broker"
	@echo ""
	@echo "📈 Broker Scaling:"
	@echo "  add_kafka_broker        ▶️  Add a Kafka broker to the cluster"
	@echo "  remove_kafka_broker     ▶️  Remove a Kafka broker from the cluster"
	@echo "═══════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────
# 🧰 Installation & Deinstallation – Strimzi, ArgoCD, UIs
# ─────────────────────────────────────────────────────────────

install_strimzi:
	@helm repo add strimzi https://strimzi.io/charts/
	@helm repo update
	@helm install strimzi-operator strimzi/strimzi-kafka-operator --namespace $(KAFKA_NAMESPACE) --create-namespace

uninstall_strimzi:
	@echo "🧹 Uninstalling Strimzi Operator..."
	@helm uninstall strimzi-operator --namespace $(KAFKA_NAMESPACE)
	@kubectl delete crd kafkas.kafka.strimzi.io --ignore-not-found
	@kubectl delete namespace $(KAFKA_NAMESPACE) --ignore-not-found
	@echo "✅ Strimzi Operator has been uninstalled."

install_kafka_ui:
	@kubectl apply -f ui/kafka-ui/application.yaml
	@echo -e "$(GREEN)✅ Kafka UI installed successfully!$(NC)"

uninstall_kafka_ui:
	@echo "🧹 Uninstalling Kafka UI..."
	@kubectl delete -f ui/kafka-ui/application.yaml
	@echo -e "$(GREEN)✅ Kafka UI has been uninstalled.$(NC)"

# ─────────────────────────────────────────────────────────────
# 🌐 UI Zugriff – Kafka UI, AKHQ
# ─────────────────────────────────────────────────────────────

start_kafka_ui:
	@kubectl -n kafka-ui port-forward services/kafka-ui-service 8089:8080 > /dev/null 2>&1 &
	@sleep 3
	@echo "🌐 Kafka UI is available at http://localhost:8089/"

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

argocd_login:
	@echo "🔐 Logging into Argo CD..."
	@PASSWORD=$$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 --decode); \
	argocd login $(MINIKUBE_IP):$(PORT) --username admin --password $$PASSWORD --insecure
	@echo -e "$(GREEN)✅ Logged into Argo CD at http://$(MINIKUBE_IP):$(PORT)/$(NC)"

argocd_add_project:
	@echo "🔐 Adding private GitLab repository to ArgoCD..."
	@argocd repo add https://gitlab.puzzle.ch/mismail/kafka-showcase.git \
	  --username $(DEPLOY_USER) \
	  --password $(DEPLOY_TOKEN)
	@echo -e "$(GREEN)✅ Repository added to ArgoCD!"

# ─────────────────────────────────────────────────────────────
# ☁️ Kafka Cluster Management – Simple / Persistent / NodePool
# ─────────────────────────────────────────────────────────────

create_simple_cluster:
	@echo "Creating Simple Kafka Cluster - $(KAFKA_CLUSTER_NAME) - ..."
	@kubectl apply -f strimzi/cluster/simple-cluster.yaml --namespace $(KAFKA_NAMESPACE)
	@$(MAKE) _wait_for_kafka_ready
	@echo "Kafka Cluster - $(KAFKA_CLUSTER_NAME) - is now Ready!"

destroy_simple_cluster:
	@echo "Deleting Simple Kafka Cluster - $(KAFKA_CLUSTER_NAME) - ..."
	@kubectl delete -f strimzi/cluster/simple-cluster.yaml --namespace $(KAFKA_NAMESPACE)
	@echo "Kafka Cluster - $(KAFKA_CLUSTER_NAME) - is now deleted!"

create_simple_cluster_persistent:
	@echo "Creating Simple Kafka Cluster - $(KAFKA_CLUSTER_NAME) - with Persistent Volume..."
	@echo "Creating directories in Minikube for hostPath volumes..."
	@minikube ssh -- "sudo mkdir -p /data/zookeeper-0 /data/zookeeper-1 /data/zookeeper-2 /data/kafka-0 /data/kafka-1; sudo chmod -R 777 /data; sudo chown -R 1000:1000 /data"
	@kubectl apply -f strimzi/cluster/simple-cluster-persistent.yaml --namespace $(KAFKA_NAMESPACE)
	@$(MAKE) _wait_for_kafka_ready
	@echo "Kafka Cluster - $(KAFKA_CLUSTER_NAME) - is now Ready!"
 
destroy_simple_cluster_persistent:
	@echo "Deleting Simple Kafka Cluster - $(KAFKA_CLUSTER_NAME) - with Persistent Volume..."
	@kubectl delete -f strimzi/cluster/simple-cluster-persistent.yaml --namespace
	@kubectl delete pvc -n kafka --all
	@echo "Removing directories in Minikube used for Persistent Volumes..."
	@minikube ssh -- "sudo rm -rf /data/zookeeper-* /data/kafka-*"
	@echo "Kafka Cluster - $(KAFKA_CLUSTER_NAME) - is now deleted!"

_create_simple_cluster_with_nodepool:
	@echo "Creating Kafka Cluster - $(KAFKA_CLUSTER_NAME) - with NodePool..."
	@kubectl apply -f strimzi/cluster/simple-cluster-nodepool.yaml --namespace $(KAFKA_NAMESPACE)
	@$(MAKE) _wait_for_kafka_ready
	@echo "Kafka Cluster - $(KAFKA_CLUSTER_NAME) - with NodePool is now Ready!"

_destroy_simple_cluster_with_nodepool:
	@echo "Deleting Kafka Cluster - $(KAFKA_CLUSTER_NAME) - with NodePool..."
	@kubectl delete -f strimzi/cluster/simple-cluster-nodepool.yaml --namespace $(KAFKA_NAMESPACE)
	@echo "Kafka Cluster - $(KAFKA_CLUSTER_NAME) - with NodePool is now deleted!"


# ─────────────────────────────────────────────────────────────
# 📦 ArgoCD Applications – Showcase Solar-System
# ─────────────────────────────────────────────────────────────

add_showcase_solar:
	@echo "🚀 Adding ApplicationSet 'solar-system' to ArgoCD..."
	@echo "Creating topics and deploying applications..."
	@kubectl apply -f strimzi/topics/solar-system -n $(KAFKA_NAMESPACE)
	@kubectl apply -f showcase/solar-system/applicationset.yaml
	@kubectl -n kafka port-forward svc/kafka-web-consumer-service 3099:8080 > /dev/null 2>&1 &
	@echo "🌐 Kafka Web Consumer is available at http://localhost:3099/"
	@echo -e "$(GREEN)✅ ApplicationSet 'solar-system' added. ArgoCD will now sync your applications."

remove_showcase_solar:
	@echo "🧹 Removing ApplicationSet 'solar-system' from ArgoCD..."
	@kubectl delete -f strimzi/topics/solar-system -n $(KAFKA_NAMESPACE)
	@echo -e "$(GREEN)✅  ApplicationSet 'solar-system' removed. Namespaces and apps may still exist depending on sync policy." a

# ─────────────────────────────────────────────────────────────
# 📦 ArgoCD Applications – Showcase Traffic Data
# ─────────────────────────────────────────────────────────────

add_showcase_traffic:
	@echo "🚀 Adding Traffic Data to Kafka Cluster..."
	@echo "Creating topics and deploying applications..."
	@kubectl apply -f strimzi/traffic-data/traffic-data -n $(KAFKA_NAMESPACE)
	@kubectl apply -f showcase/traffic-data/application.yaml
	@echo -e "$(GREEN)✅ Traffic Data added. ArgoCD will now sync your applications."

remove_showcase_traffic:
	@echo "🧹 Removing Traffic Data from Kafka Cluster..."
	@kubectl delete -f strimzi/traffic-generator/traffic-data -n $(KAFKA_NAMESPACE)
	@echo -e "$(GREEN)✅ Traffic Data removed. Namespaces and apps may still exist depending on sync policy."
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

topics:
	@kubectl exec -n $(KAFKA_NAMESPACE) -it $(KAFKA_CLUSTER_NAME)-kafka-0 -- /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092

describe:
	@kubectl exec -n $(KAFKA_NAMESPACE) -it $(KAFKA_CLUSTER_NAME)-kafka-0 -- /opt/kafka/bin/kafka-topics.sh --describe --topic $(TOPIC) --bootstrap-server localhost:9092

partitions:
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

add_kafka_broker:
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

remove_kafka_broker:
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

auto-rebalnce:
	@kubectl apply -f strimzi/rebalance/auto-rebalance.yaml
	@$(MAKE) wait_for_rebalance_status REBALANCE_NAME=auto-rebalance

upscale-rebalance:
	@kubectl apply -f strimzi/rebalance/upscale-rebalance.yaml
	@$(MAKE) wait_for_rebalance_status REBALANCE_NAME=upscale-rebalance