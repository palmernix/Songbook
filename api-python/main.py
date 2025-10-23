from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from schemas import IngestSnapshot, SuggestRequest, SuggestResponse
from dotenv import load_dotenv
import os
import time

# --- env & app ---
load_dotenv()
app = FastAPI(title="LyricSheets API", version="0.1.0")

# Allow your iOS app (debug + prod). For now, be permissive in dev:
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- health ---
@app.get("/health")
def health():
    return {"status": "ok"}

# --- NOTE: place to initialize LangChain & Chroma singletons later ---
# Example skeleton:
# from langchain_openai import ChatOpenAI, OpenAIEmbeddings
# import chromadb
# _llm = ChatOpenAI(model="gpt-4o-mini", temperature=0.9, api_key=os.getenv("OPENAI_API_KEY"))
# _emb = OpenAIEmbeddings(model="text-embedding-3-small", api_key=os.getenv("OPENAI_API_KEY"))
# _chroma = chromadb.PersistentClient(path=os.getenv("CHROMA_PERSIST_DIR", "./chroma_db"))
# _voice = _chroma.get_or_create_collection("voice")
# _reference = _chroma.get_or_create_collection("reference")

# --- util: naive line splitting; you can upgrade to header-aware later ---
def split_lines(full_text: str) -> list[str]:
    # drop empty lines; strip whitespace
    return [ln.strip() for ln in full_text.splitlines() if ln.strip()]

# --- /ingest/snapshot ---
@app.post("/ingest/snapshot")
def ingest_snapshot(payload: IngestSnapshot):
    # TODO:
    # 1) parse sections from headers like [Verse]/[Chorus] to set metadata
    # 2) embed each line & upsert into Chroma "voice" with metadata
    # For now, just simulate success & count lines
    lines = split_lines(payload.text)
    return {"ok": True, "linesProcessed": len(lines)}

# --- /suggest ---
@app.post("/suggest", response_model=SuggestResponse)
def suggest(req: SuggestRequest):
    t0 = time.time()

    # TODO:
    # 1) embed req.contextFocus or req.userLyrics
    # 2) query Chroma "voice" (k=req.k, mmr=req.mmr, min score req.minSim)
    # 3) (optional) mix in 0–2 "reference" hits if req.useReferences
    # 4) build prompt template (system+user) with examples + constraints
    # 5) call LLM; enforce single-line output; compute token stats

    # Temporary stub so you can wire iOS now:
    seed = req.userLyrics.strip()
    fake_line = f"{seed} — and the streetlights shake the snow from their sleeves"
    latency = int((time.time() - t0) * 1000)

    return SuggestResponse(
        suggestion=fake_line.splitlines()[0][:280],  # guarantee single line
        usedVoiceIds=[],
        usedReferenceIds=[],
        tokens={"prompt": 0, "completion": 0, "total": 0},
        latencyMs=latency,
    )