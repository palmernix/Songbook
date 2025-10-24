from __future__ import annotations
from typing import Dict
import os
import re

from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

load_dotenv()

# Fast, cheap model; you can swap to "gemini-1.5-pro" later if desired.
_LLM = ChatGoogleGenerativeAI(
    model="models/gemini-2.0-flash",
    temperature=0.9,
    max_output_tokens=500,
    api_key=os.getenv("GOOGLE_API_KEY"),
)

# Prompt: strongly constrain to ONE line + honor constraints.
_PROMPT = ChatPromptTemplate.from_messages(
    [
        (
            "system",
            (
                "You are a lyric writing assistant. Produce exactly ONE LINE of lyrics.\n"
                "Constraints:\n"
                "• Output must be a single line (no newlines). \n"
                "• Keep it under ~120 characters. \n"
                "• Respect style, mood, rhyme scheme, and syllable hints when provided. \n"
                "• Avoid repeating the user's last line verbatim; continue with fresh imagery.\n"
                "• Never include explanations or quotes — just the line."
            ),
        ),
        (
            "user",
            (
                "USER LYRICS (last line focus):\n{userLyrics}\n\n"
                "RECENT CONTEXT (last ~8 lines):\n{contextFocus}\n\n"
                "FULL SONG CONTEXT (entire text):\n{contextFull}\n\n"
                "{hints}\n"
                "Now write exactly one new line that fits."
            ),
        ),
    ]
)

_OUTPUT = StrOutputParser()

_CHAIN = _PROMPT | _LLM | _OUTPUT

def _hints_from_payload(p: Dict) -> str:
    parts: List[str] = []
    if p.get("style"):      parts.append(f"Style: {p['style']}")
    if p.get("mood"):       parts.append(f"Mood: {p['mood']}")
    if p.get("scheme"):     parts.append(f"Rhyme scheme: {p['scheme']}")
    if p.get("syllables"):  parts.append(f"Target syllables: {p['syllables']}")
    if p.get("sectionKind"):parts.append(f"Section: {p['sectionKind']}")
    return "HINTS:\n" + " | ".join(parts) if parts else ""

def _postprocess_single_line(text: str) -> str:
    """Ensure single-line, trimmed, no trailing punctuation spam, <= 180 chars hard cap."""
    # Take only first line if model slipped a newline
    line = text.splitlines()[0]
    # Collapse internal whitespace
    line = re.sub(r"\s+", " ", line).strip()
    # Trim quotes/backticks if model wrapped output
    line = line.strip("\"'` ")
    # Hard cap (defensive)
    return line[:180]


def inspire_one_line(payload: Dict) -> str:
    """
    Expects keys: userLyrics, contextFocus, contextFull, style, mood, scheme, syllables, sectionKind
    Returns a single, cleaned line.
    """

    inputs = {
        "userLyrics": payload.get("userLyrics", "") or "",
        "contextFocus": payload.get("contextFocus", "") or "",
        "contextFull": payload.get("contextFull", ""),
        "hints": _hints_from_payload(payload),
    }
    raw = _CHAIN.invoke(inputs)
    
    if (raw == "" ):
        debugResponse = (_PROMPT | _LLM).invoke(inputs)
        print(debugResponse)

        raise Exception("No response from LLM")

    text = getattr(raw, "content", raw) or ""
    return _postprocess_single_line(text)