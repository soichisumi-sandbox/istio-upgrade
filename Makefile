# init
## default
ifndef ISTIO_VERSION
ISTIO_VERSION=1.4
endif

## latest patch versions
ISTIOCTL_1.4=1.4.7
ISTIOCTL_1.5=1.5.10
ISTIOCTL_1.6=1.6.14
ISTIOCTL_1.7=1.7.8
ISTIOCTL_1.8=1.8.6
ISTIOCTL_1.9=1.9.5
ISTIOCTL_1.10=1.10.3

ISTIOCTL_VERSION=$(ISTIOCTL_$(ISTIO_VERSION))
ISTIOCTL_PATH=releases/istio-$(ISTIOCTL_VERSION)/bin/istioctl
ISTIO_REVISION=$(shell echo $(ISTIO_VERSION) | sed 's/\./-/g')


# COMMANDS_FOR_UPGRADE

## upgrade control plane (for 1.5)
upgrade-istio-1.5-w-operator:
	./$(ISTIOCTL_PATH) analyze
	./$(ISTIOCTL_PATH) upgrade -f ./customfiles/istio-$(ISTIOCTL_VERSION)/istio-operator.yaml --force


## install new control plane
istio-canary-install:
	./$(ISTIOCTL_PATH) analyze
	./$(ISTIOCTL_PATH) install -f ./customfiles/istio-$(ISTIOCTL_VERSION)/istio-operator.yaml --set revision=$(ISTIO_REVISION)

## enable new control plane
istio-canary-apply:
	kubectl label namespace default istio-injection- istio.io/rev=$(ISTIO_REVISION) --overwrite
	kubectl -n default rollout restart deployment

rollout-all:
	kubectl -n default rollout restart deploy

# COMMANDS_FOR_SETUP

install-istio-init:
	kubectl create ns istio-system
	helm template ./releases/istio-$(ISTIOCTL_VERSION)/install/kubernetes/helm/istio-init --name istio-init --namespace istio-system | kubectl apply -f -
	kubectl -n istio-system wait --for=condition=complete job --all
	kubectl label namespace default istio-injection=enabled --overwrite

expose-grafana:
	kubectl patch svc grafana -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

deploy-sampleapp:
	kubectl apply -f ./customfiles/istio-1.4.7/bookinfo-gateway.yaml
	kubectl apply -f ./customfiles/istio-1.4.7/bookinfo.yaml

# install argocd v1.3.5
# https://argo-cd.readthedocs.io/en/release-1.8/
# initial password: kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2
install-argocd:
	kubectl create namespace argocd
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/3e150df0ede862c476d2ad0b90717ae00a890551/manifests/install.yaml
	kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

## get new istio version
dl-istio:
	mkdir -p customfiles/istio-$(ISTIOCTL_VERSION)
	mkdir -p releases/
	pushd releases/ && \
	curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$(ISTIOCTL_VERSION) sh - && \
	popd

dl-istio-initial:
	make dl-istio ISTIOCTL_VERSION=$(ISTIOCTL_1.4) 
	make dl-istio ISTIOCTL_VERSION=$(ISTIOCTL_1.5) 
	make dl-istio ISTIOCTL_VERSION=$(ISTIOCTL_1.6) 
	make dl-istio ISTIOCTL_VERSION=$(ISTIOCTL_1.7) 
	make dl-istio ISTIOCTL_VERSION=$(ISTIOCTL_1.8) 
	make dl-istio ISTIOCTL_VERSION=$(ISTIOCTL_1.9) 
	make dl-istio ISTIOCTL_VERSION=$(ISTIOCTL_1.10) 

## migrate values file to istio-controlplane
migrate-istio1.4-values-to-istio1.5-operator:
	./releases/istio-$(ISTIOCTL_1.5)/bin/istioctl manifest migrate ./customfiles/istio-$(ISTIOCTL_1.4)/values-istio-custom.yaml > ./customfiles/istio-$(ISTIOCTL_1.5)/istio-operator.yaml

