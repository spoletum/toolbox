# Herdr Pi

A Homebrew-based development container running the [Pi coding agent](https://github.com/badlogic/pi-mono), configured for a local llama.cpp server.

## Requirements

- Docker with the Compose plugin
- Linux amd64 with a Vulkan-capable GPU, exposing `/dev/dri`
- A host workspace directory (defaults to `$HOME/Projects`)
- About 30 GB free disk space for the default model

The Pi image itself is built for amd64 and arm64; the bundled Vulkan Compose stack supports both architectures.

## Usage

From the repository root:

```bash
make up                 # builds Pi, downloads the GGUF, and starts llama.cpp
make pi                 # starts Pi in the development container
make herdr              # starts Herdr in the same container
make down
```

The default is `unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF`'s 23.4 GiB `Q6_K` quant. llama.cpp uses Vulkan with full GPU offload and a 256k-token context window.

## Models

Pi includes the `hf` CLI. From Pi's shell, download another public GGUF into the shared models volume:

```bash
hf download <repository> <filename.gguf> --local-dir /home/agent/models
```

Or download from the host:

```bash
make model MODEL_REPO=<repository> MODEL_FILE=<filename.gguf>
```

llama.cpp serves one loaded model at a time. Switch to an already-downloaded model by recreating the server:

```bash
make serve MODEL_PATH=/models/<filename.gguf>
```

The Pi model entry names the default server alias. If a replacement model needs a different alias or context window, update `herdr/pi/models.json` and rebuild the `dev` service.

## Configuration

Override the defaults when starting Compose:

```bash
HOST_UID=$(id -u) HOST_GID=$(id -g) PROJECTS_DIR=/path/to/workspace make up
```

Pi's provider definition is baked into the image and synchronized to its persistent agent volume at each container start. Sessions and other Pi agent state persist, while image updates to `models.json` take effect automatically.

For an image-only build, use `make -C herdr/pi build`. Set `CONTAINER=podman` to use Podman for that build; the documented local runtime uses Docker Compose.
