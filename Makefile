all: patch vendor build

k8s/:
	git clone https://github.com/kubernetes/kubernetes k8s
	(cd k8s && git checkout d5fdf3135e7)
	zip -rq k8s.zip k8s/ # preserve clean k8s

clean:
	rm -rf k8s/
	unzip -q k8s.zip
	unzip -q bin.zip
	(cd k8s && git reset --hard)

build-all: # assume unpatched
	(cd k8s && make all)
	zip -rq bin.zip k8s/_output/bin

# k8s/vendor/github.com/BenjaminSaintCyr/k8s-lttng-tpp/Makefile: k8s/
# 	(cd k8s && go get ...)
vendor:
	(cd k8s && go get github.com/BenjaminSaintCyr/k8s-lttng-tpp)
	(cd k8s && go mod vendor)
	(cd k8s && git checkout -- vendor/k8s.io)

# vendor: k8s/vendor/github.com/BenjaminSaintCyr/k8s-lttng-tpp/Makefile

k8s/lttng-kubelet.patch: k8s/ 
	cp lttng-kubelet.patch k8s
	(cd k8s && git apply lttng-kubelet.patch)

patch: k8s/lttng-kubelet.patch

tracer:
	(cd k8s/vendor/github.com/BenjaminSaintCyr/k8s-lttng-tpp/ && make clean && make) # build tracer

build: k8s/ tracer
	(cd k8s	&& KUBE_CGO_OVERRIDES=kubelet make WHAT=cmd/kubelet) # build kubelet

update-patch: k8s/
	mkdir -p bckp/
	mv lttng-kubelet.patch bckp/
	(cd k8s/ &&  git diff > lttng-kubelet.patch)
	cp k8s/lttng-kubelet.patch lttng-kubelet.patch

trace:
	-lttng-sessiond --daemonize
	lttng create kubelet-tracing
	lttng enable-event -u -a
	lttng add-context -u -t vpid -t vtid -t procname
	lttng start

etcd:
	k8s/hack/install-etcd.sh | tail -n 1 | sh

run: etcd
	sudo swapoff -a
	k8s/hack/local-up-cluster.sh -O &

clean-run:
	sudo rm -r /tmp/kube*

experiment: patch vendor trace
	KUBE_CGO_OVERRIDES=kubelet k8s/hack/local-up-cluster.sh &

deploy:
	kubectl apply -f https://k8s.io/examples/controllers/nginx-deployment.yaml

benchmark/:
    git clone https://github.com/huaqiangwang/DeathStarBench-1/ benchmark
    (cd benchmark && git checkout 5a08c1ddf429d19b6549d3a24e13da98834d2b36)
