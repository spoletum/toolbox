COMPOSE ?= docker compose
MODEL_REPO ?= agentionai/Qwen3.8-Flash-Next-AP-GGUF
MODEL_FILE ?= Qwen3.8-Flash-Next-AP-Q4_K_M.gguf
MODEL_PATH ?= /models/$(MODEL_FILE)
export MODEL_PATH

.PHONY: build up down model serve herdr pi

build:
	$(COMPOSE) build dev

# Downloading is idempotent: Hugging Face reuses an already-complete file.
model: build
	$(COMPOSE) run --rm --no-deps dev hf download $(MODEL_REPO) $(MODEL_FILE) --local-dir /home/agent/models

up: model
	$(COMPOSE) up -d

# Start or replace llama.cpp after changing MODEL_PATH or another server option.
serve:
	MODEL_PATH=$(MODEL_PATH) $(COMPOSE) up -d --force-recreate llama

down:
	$(COMPOSE) down

herdr:
	$(COMPOSE) exec -it dev herdr

pi:
	$(COMPOSE) exec -it dev pi
