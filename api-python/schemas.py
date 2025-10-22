from pydantic import BaseModel, Field
from typing import Optional

class IngestSnapshot(BaseModel):
    songId: str
    version: int = 1
    title: Optional[str] = None
    text: str
    authoredByDefault: str = Field(default="user")

class SuggestRequest(BaseModel):
    userLyrics: str
    contextFocus: str = ""
    contextFull: str = ""
    style: str = "indie folk"
    mood: str = "neutral"
    scheme: str = "ABAB"
    syllables: str = "8-10"
    songId: Optional[str] = None
    sectionKind: Optional[str] = None
    useReferences: bool = False
    temperature: float = 0.9
    k: int = 6
    minSim: float = 0.18
    mmr: bool = True
    stream: bool = False

class SuggestResponse(BaseModel):
    suggestion: str
    usedVoiceIds: list[str] = []
    usedReferenceIds: list[str] = []
    tokens: dict = {}
    latencyMs: int = 0