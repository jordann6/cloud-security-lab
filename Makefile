# Cloud Security Lab — one-command operation of the deploy/attack/verify/destroy loop.
.PHONY: help deploy cluster falco gatekeeper policy-test attack runtime-attack verify destroy

TF := terraform -chdir=terraform

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

deploy: ## terraform init + apply the AWS threat surface, detection, and remediation
	$(TF) init
	$(TF) apply -auto-approve

cluster: ## Create the local K3d cluster
	k3d cluster create cloud-security-lab --agents 1

falco: ## Install Falco runtime detection
	cd k8s/falco && bash install.sh

gatekeeper: ## Install Gatekeeper and apply the admission policies
	cd k8s/gatekeeper && bash install.sh
	kubectl apply -f k8s/gatekeeper/policies/templates/
	kubectl apply -f k8s/gatekeeper/policies/constraints/

policy-test: ## Run the gator unit tests for the admission policies (no cluster needed)
	gator verify k8s/gatekeeper/tests/

attack: ## Run the full AWS MITRE ATT&CK kill chain against the deployed lab
	bash attack/run-killchain.sh

runtime-attack: ## Run the Kubernetes runtime attack scenarios against Falco
	bash k8s/attack-scenarios/run-runtime-attacks.sh

verify: ## Show the blue-team reaction: alarms, GuardDuty findings, key status
	@aws cloudwatch describe-alarms --alarm-name-prefix cloud-security-lab \
	  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue}' --output table
	@aws iam list-access-keys --user-name cloud-security-lab-compromised-user \
	  --query 'AccessKeyMetadata[].{Key:AccessKeyId,Status:Status}' --output table

destroy: ## Tear down everything (K3d cluster + AWS resources)
	bash teardown.sh
