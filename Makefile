# ====== User-configurable vars ======
# If PROJECT_ID is empty, we'll try to read from gcloud config.
PROJECT_ID ?= $(shell gcloud config get-value project 2>/dev/null)
REGION ?= us-east1
SERVICE ?= lyricsheets-api
IMAGE ?= gcr.io/$(PROJECT_ID)/$(SERVICE)
API_DIR ?= lyric-engine
GEMINI_MODEL ?= models/gemini-2.0-flash

# For the simple env-var deploy. Export this in your shell before make deploy:
#   export GOOGLE_API_KEY=sk-...
GOOGLE_API_KEY ?=

# ====== Helpers ======
check-project:
	@if [ -z "$(PROJECT_ID)" ]; then echo "PROJECT_ID not set and not found in gcloud config."; exit 1; fi

check-api-key:
	@if [ -z "$(GOOGLE_API_KEY)" ]; then echo "GOOGLE_API_KEY not set (export it in your shell)."; exit 1; fi

# ====== Dev tasks ======
export-reqs:
	cd $(API_DIR) && poetry run pip freeze > requirements.txt

run-local:
	cd $(API_DIR) && poetry run uvicorn main:app --reload

# ====== Build & deploy (env vars) ======
build: check-project export-reqs
	cd $(API_DIR) && gcloud builds submit --tag $(IMAGE)

deploy: check-project check-api-key
	gcloud run deploy $(SERVICE) \
	  --image $(IMAGE) \
	  --region $(REGION) \
	  --platform managed \
	  --allow-unauthenticated \
	  --set-env-vars GOOGLE_API_KEY=$(GOOGLE_API_KEY),GEMINI_MODEL=$(GEMINI_MODEL)

url:
	@echo "Service URL:"
	@gcloud run services describe $(SERVICE) --region $(REGION) --format='value(status.url)'

open:
	@open $$(gcloud run services describe $(SERVICE) --region $(REGION) --format='value(status.url)')