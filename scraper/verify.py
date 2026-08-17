"""
Document verification tool: view the full text of a scraped document.

Usage:
    python -m scraper verify <doc_id>
"""

import json
import re
import sys
from pathlib import Path

from . import config


def verify_document(doc_id: str, corpus_dir: str = "output/corpus"):
    """Display the full text of a document, with matched terms highlighted."""
    doc_path = Path(corpus_dir) / f"{doc_id}.json"

    if not doc_path.exists():
        print(f"Document not found: {doc_path}")
        print(f"\nAvailable documents:")
        corpus = Path(corpus_dir)
        if corpus.exists():
            for f in sorted(corpus.glob("*.json"))[:20]:
                try:
                    d = json.loads(f.read_text("utf-8"))
                    print(f"  {f.stem}  {d.get('date', '?'):<12} {d.get('title', '?')[:60]}")
                except Exception:
                    pass
        sys.exit(1)

    doc = json.loads(doc_path.read_text("utf-8"))

    print("=" * 70)
    print(f"DOCUMENT: {doc.get('title', 'N/A')}")
    print(f"Date:     {doc.get('date', 'N/A')}")
    print(f"Type:     {doc.get('content_type', 'N/A')}")
    print(f"URL:      {doc.get('url', 'N/A')}")
    print(f"Words:    {doc.get('word_count', 'N/A')}")
    print(f"Doc ID:   {doc.get('id', doc_id)}")
    print("=" * 70)
    print()
    print(doc.get("body_text", "(no text)"))
    print()
    print("=" * 70)
