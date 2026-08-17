"""
Claim sampling tool for manual verification.

Usage:
    python -m scraper sample --category ontological_security --n 10 --random
    python -m scraper sample --term "духовна" --n 5
    python -m scraper sample --doc-id abc123def456
"""

import json
import random as rng
import sys
from pathlib import Path


def main(args):
    claims_path = Path(args.claims_file)
    if not claims_path.exists():
        print(f"Claims file not found: {args.claims_file}")
        print("Run analysis first: python -m scraper analyse")
        sys.exit(1)

    claims = json.loads(claims_path.read_text("utf-8"))
    print(f"Loaded {len(claims)} claims total\n")

    # Apply filters
    filtered = claims

    if args.category:
        filtered = [c for c in filtered if c["category"] == args.category]
        print(f"Filtered to category '{args.category}': {len(filtered)} claims")

    if args.term:
        term_lower = args.term.lower()
        filtered = [c for c in filtered
                    if term_lower in c["matched_term_lemma"].lower()
                    or term_lower in c["matched_surface_form"].lower()]
        print(f"Filtered to term containing '{args.term}': {len(filtered)} claims")

    if args.doc_id:
        filtered = [c for c in filtered if c["doc_id"] == args.doc_id]
        print(f"Filtered to document '{args.doc_id}': {len(filtered)} claims")

    if not filtered:
        print("\nNo claims match the filter criteria.")
        print("\nAvailable categories:")
        cats = sorted(set(c["category"] for c in claims))
        for cat in cats:
            count = sum(1 for c in claims if c["category"] == cat)
            print(f"  {cat}: {count} claims")
        return

    # Sample
    if args.random:
        sample = rng.sample(filtered, min(args.n, len(filtered)))
    else:
        sample = filtered[:args.n]

    # Display
    print(f"\nShowing {len(sample)} of {len(filtered)} matching claims:\n")
    print("=" * 70)

    for i, claim in enumerate(sample, 1):
        print(f"\n--- Claim #{claim.get('claim_id', i)} ---")
        print(f"Document:  {claim['doc_title']}")
        print(f"Date:      {claim['doc_date']}")
        print(f"Type:      {claim['content_type']}")
        print(f"URL:       {claim['doc_url']}")
        print(f"Category:  {claim['category']}")
        print(f"Term:      {claim['matched_term_lemma']} ({claim['matched_term_lang']})")
        print(f"Surface:   \"{claim['matched_surface_form']}\"")
        print(f"")

        if claim.get("context_before"):
            print(f"  [prev] {claim['context_before'][:200]}")
        print(f"  >>> {claim['sentence']}")
        if claim.get("context_after"):
            print(f"  [next] {claim['context_after'][:200]}")

        print()

    print("=" * 70)
    print(f"\nTo view the full document text, run:")
    if sample:
        print(f"  python -m scraper verify {sample[0]['doc_id']}")
