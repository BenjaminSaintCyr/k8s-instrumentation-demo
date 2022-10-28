all: patch build-kubelet

k8s/:
	git clone https://github.com/kubernetes/kubernetes k8s
	(cd k8s && git checkout d5fdf3135e7)
	zip -rq k8s.zip k8s/ # preserve clean k8s

clean:
	rm -rf k8s/
	unzip -q k8s.zip
	(cd k8s && git reset --hard)

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
	git clone https://github.com/BenjaminSaintCyr/k8s-lttng-tpp.git k8s/vendor/github.com/BenjaminSaintCyr/k8s-lttng-tpp/

patch: k8s/lttng-kubelet.patch

build:
	(cd k8s/vendor/github.com/BenjaminSaintCyr/k8s-lttng-tpp/ && make clean && make) # build tracer
	(cd k8s	&& KUBE_CGO_OVERRIDES=kubelet make WHAT=cmd/kubelet) # build kubelet

update-patch: k8s/
	mkdir -p bckp/
	mv lttng-kubelet.patch bckp/
	(cd k8s/ &&  git diff > lttng-kubelet.patch)
	cp k8s/lttng-kubelet.patch lttng-kubelet.patch

trace:
	lttng-sessiond --daemonize
	lttng create kubelet-tracing
	lttng enable-event -u -a
	lttng add-context -u -t vpid -t vtid -t procname
	lttng start

run:
	k8s/hack/local-up-cluster.sh -O &
