SOURCE_DIR=cmd pkg
BUILD_DIR=hack build
KUBE_CONFIG=/var/run/kubernetes/admin.kubeconfig
DEATHSTAR_DIR=benchmark
SCALABILITY_DIR=perf-tests

all: | patch vendor tracer
	(cd k8s && make WHAT="cmd/kubectl cmd/kube-apiserver cmd/kube-controller-manager cmd/cloud-controller-manager cmd/kubelet cmd/kube-proxy cmd/kube-scheduler")

vagrant:
	vagrant up
	vagrant scp Makefile .
	vagrant scp lttng-kubelet.patch .
	vagrant scp k8s.zip .
	vagrant ssh -- make restore

# * Install

k8s/:
	git clone https://github.com/kubernetes/kubernetes k8s
	(cd k8s && git checkout d5fdf3135e7)
	zip -rq k8s.zip k8s/ # preserve clean k8s

clean:
	rm -r k8s/ *.zip

restore:
	rm -rf k8s/
	(unzip -q k8s.zip && cd k8s && git reset --hard)

# * Build

unpatch: k8s/
	(cd k8s && git reset --hard)

build-unpatch: k8s/ unpatch # assume unpatched
	(cd k8s && make WHAT="cmd/kubectl cmd/kube-apiserver cmd/kube-controller-manager cmd/cloud-controller-manager cmd/kubelet cmd/kube-proxy cmd/kube-scheduler")

vendor: k8s/
	(cd k8s && go get github.com/BenjaminSaintCyr/k8s-lttng-tpp)
	(cd k8s && go mod vendor)
	(cd k8s && git checkout -- vendor/k8s.io)

patch: k8s/
	cp lttng-kubelet.patch k8s
	(cd k8s && git apply lttng-kubelet.patch)

tracer:
	(cd k8s/vendor/github.com/BenjaminSaintCyr/k8s-lttng-tpp/ && make clean && make) # build tracer

build: | k8s/ tracer
	(cd k8s	&& KUBE_CGO_OVERRIDES=kubelet make WHAT=cmd/kubelet) # build kubelet

update-patch: k8s/
	mkdir -p bckp/
	mv lttng-kubelet.patch bckp/$(date +"%Y-%m-%d:%H:%S").patch
	(cd k8s/ && git add $(SOURCE_DIR) $(BUILD_DIR))
	(cd k8s/ && git diff --cached > lttng-kubelet.patch)
	cp k8s/lttng-kubelet.patch lttng-kubelet.patch

# * Experiment

trace:
	-lttng-sessiond --daemonize
	lttng create kubelet-tracing
	lttng enable-event -u -a
	lttng enable-event -k -a
	lttng add-context -u -t vpid -t vtid -t procname
	lttng add-context -k -t pid -t tid -t procname
	lttng start

run: etcd
	sudo swapoff -a
	sudo rm -r /tmp/kube*
	k8s/hack/local-up-cluster.sh -O &
	export KUBECONFIG=/var/run/kubernetes/admin.kubeconfig && alias kubectl="bash /home/ben/Documents/DORSAL/Projects/codebase/k8s/cluster/kubectl.sh"

# * Benchmark

benchmark-simple: trace
	-k8s/cluster/kubectl.sh apply --wait=true -f https://k8s.io/examples/controllers/nginx-deployment.yaml
	sleep 5
	-k8s/cluster/kubectl.sh  delete --wait=true -f https://k8s.io/examples/controllers/nginx-deployment.yaml
	sleep 5
	lttng destroy

# ** Deathstar benchmark

$(DEATHSTAR_DIR)/:
	git clone https://github.com/huaqiangwang/DeathStarBench-1/ $(DEATHSTAR_DIR)
	(cd $(DEATHSTAR_DIR) && git checkout 5a08c1ddf429d19b6549d3a24e13da98834d2b36)
	find ./$(DEATHSTAR_DIR)/mediaMicroservices/k8s/scripts/ -type f -exec sed -i -e 's/kubectl/\/home\/vagrant\/k8s\/cluster\/kubectl.sh/g' {} \; # HACK replace kubectl with local version

benchmark-deathstar: $(DEATHSTAR_DIR)/ trace
	-./$(DEATHSTAR_DIR)/mediaMicroservices/k8s/scripts/deploy-all-services-and-configurations.sh
	lttng destroy


# ** Clusterloader benchmark

$(SCALABILITY_DIR)/:
	git clone --depth 1 https://github.com/kubernetes/perf-tests.git $(SCALABILITY_DIR)/

clusterloader-demo/:
	vagrant scp clusterloader-demo/ .
	vagrant ssh -- make benchmark-clusterloader-demo

benchmark-clusterloader-demo: $(SCALABILITY_DIR)/ trace
	-(cd $(SCALABILITY_DIR)/clusterloader2 && go run cmd/clusterloader.go --testconfig=$(HOME)/clusterloader-demo/config.yaml --provider=local --kubeconfig=$(KUBE_CONFIG) --v=2)
	lttng destroy

benchmark-clusterloader2: $(SCALABILITY_DIR)/ trace
	-(cd $(SCALABILITY_DIR)/clusterloader2 && go run cmd/clusterloader.go --testconfig=testing/load/config.yaml --provider=local --kubeconfig=$(KUBE_CONFIG) --v=2)
	lttng destroy

