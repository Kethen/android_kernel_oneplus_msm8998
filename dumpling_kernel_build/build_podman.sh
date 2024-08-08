SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR"

IMAGE_NAME="dumpling_kernel_build"

if ! podman image exists "$IMAGE_NAME"
then
	podman image build -f Dockerfile -t "$IMAGE_NAME"
fi

cd ../

podman run \
	--rm -it \
	-v ./:/workdir \
	-w /workdir/dumpling_kernel_build \
	--entrypoint /bin/bash \
	"$IMAGE_NAME" \
	build.sh
