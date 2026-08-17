"""
Corpus analysis: term frequency, document filtering, and claim extraction.

Usage:
    python -m scraper.analyse [--corpus-dir output/corpus]

This module:
  1. Loads all scraped documents from the corpus directory.
  2. Builds morphologically-expanded regex patterns for all seed terms.
  3. For each document, checks which seed terms appear.
  4. Extracts individual claims (sentences/statements containing terms).
  5. Produces summary statistics and a claims file for manual verification.

Output files:
  - output/results.json     Per-document analysis with matched terms
  - output/claims.json      Individual claims with context, for sampling
  - output/summary.json     Aggregate statistics
"""

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

from . import config
from .lemmatiser import build_all_regexes


def load_corpus(corpus_dir: str) -> list[dict]:
    """Load all .json documents from the corpus directory."""
    docs = []
    corpus_path = Path(corpus_dir)
    if not corpus_path.exists():
        print(f"Corpus directory not found: {corpus_dir}")
        print("Run the scraper first: python -m scraper.scrape")
        sys.exit(1)

    for f in sorted(corpus_path.glob("*.json")):
        try:
            doc = json.loads(f.read_text("utf-8"))
            if "body_text" in doc and doc["body_text"]:
                docs.append(doc)
        except (json.JSONDecodeError, KeyError) as e:
            print(f"  Warning: skipping {f.name}: {e}")

    print(f"Loaded {len(docs)} documents from {corpus_dir}")
    return docs


def split_into_sentences(text: str) -> list[str]:
    """
    Split Ukrainian/Russian text into sentences.
    Handles abbreviations, initials, and other edge cases.
    """
    # Protect common abbreviations from splitting
    protected = text
    abbrevs = [
        r"ст\.", r"п\.", r"м\.", r"р\.", r"рр\.", r"гр\.",
        r"тис\.", r"млн\.", r"млрд\.", r"грн\.",
        r"напр\.", r"див\.", r"т\.д\.", r"т\.п\.", r"т\.ін\.",
        r"проф\.", r"акад\.", r"д\.ю\.н\.", r"к\.ю\.н\.",
    ]
    for a in abbrevs:
        protected = re.sub(a, a.replace(r"\.", "<<<DOT>>>"), protected)

    # Split on sentence-ending punctuation followed by space + uppercase
    sentences = re.split(
        r'(?<=[.!?»"])\s+(?=[A-ZА-ЯІЇЄҐЁ«"])',
        protected
    )

    # Also split on newlines that look like paragraph breaks
    result = []
    for s in sentences:
        parts = re.split(r"\n\s*\n", s)
        result.extend(parts)

    # Restore dots and clean up
    cleaned = []
    for s in result:
        s = s.replace("<<<DOT>>>", ".").strip()
        if s and len(s) > 10:
            cleaned.append(s)

    return cleaned


def analyse_document(doc: dict, term_regexes: dict) -> dict:
    """
    Analyse a single document against all seed term regexes.

    Returns an enriched document dict with:
      - matched_categories: which coding dimensions are present
      - matched_terms: {category: [term, ...]}
      - match_count: total number of term matches
      - claims: list of {sentence, category, matched_term, context}
    """
    text = doc.get("body_text", "")
    if not text:
        return {**doc, "matched_categories": [], "matched_terms": {},
                "match_count": 0, "claims": [], "is_relevant": False}

    sentences = split_into_sentences(text)
    matched_terms = defaultdict(list)
    matched_categories = set()
    claims = []
    total_matches = 0
    # Track (category, sentence_index, match_span) to deduplicate
    # when Ukrainian and Russian regexes match the same surface form
    seen_matches = set()

    for category, terms in term_regexes.items():
        for term_key, term_data in terms.items():
            regex = term_data["regex"]
            lemma = term_data["lemma"]
            lang = term_data["lang"]

            for i, sentence in enumerate(sentences):
                matches = list(regex.finditer(sentence))
                if matches:
                    for match in matches:
                        dedup_key = (category, i, match.start(), match.end())
                        if dedup_key in seen_matches:
                            continue
                        seen_matches.add(dedup_key)

                        matched_categories.add(category)
                        if lemma not in matched_terms[category]:
                            matched_terms[category].append(lemma)
                        total_matches += 1

                        context_before = sentences[i - 1] if i > 0 else ""
                        context_after = sentences[i + 1] if i < len(sentences) - 1 else ""

                        claims.append({
                            "doc_id": doc.get("id", ""),
                            "doc_title": doc.get("title", ""),
                            "doc_date": doc.get("date", ""),
                            "doc_url": doc.get("url", ""),
                            "content_type": doc.get("content_type", ""),
                            "category": category,
                            "matched_term_lemma": lemma,
                            "matched_term_lang": lang,
                            "matched_surface_form": match.group(),
                            "sentence": sentence,
                            "sentence_index": i,
                            "context_before": context_before,
                            "context_after": context_after,
                            "match_start": match.start(),
                            "match_end": match.end(),
                        })

    # A document is "relevant" if it contains at least one church_actors
    # term AND at least one term from another category
    has_church = "church_actors" in matched_categories
    has_other = bool(matched_categories - {"church_actors"})
    is_relevant = has_church and has_other

    return {
        **doc,
        "matched_categories": sorted(matched_categories),
        "matched_terms": dict(matched_terms),
        "match_count": total_matches,
        "claims": claims,
        "is_relevant": is_relevant,
        "sentence_count": len(sentences),
    }


def compute_summary(results: list[dict]) -> dict:
    """Compute aggregate statistics across the corpus."""

    # Basic counts
    total_docs = len(results)
    speeches = [r for r in results if r.get("content_type") == "speech"]
    press_releases = [r for r in results if r.get("content_type") == "press_release"]
    relevant_docs = [r for r in results if r.get("is_relevant")]
    relevant_speeches = [r for r in relevant_docs if r.get("content_type") == "speech"]
    relevant_press = [r for r in relevant_docs if r.get("content_type") == "press_release"]

    # Claims counts
    all_claims = []
    for r in results:
        all_claims.extend(r.get("claims", []))

    claims_by_category = Counter()
    claims_by_term = Counter()
    for c in all_claims:
        claims_by_category[c["category"]] += 1
        claims_by_term[c["matched_term_lemma"]] += 1

    # Per-year breakdown
    yearly = defaultdict(lambda: {
        "total_docs": 0, "speeches": 0, "press_releases": 0,
        "relevant_docs": 0, "relevant_speeches": 0, "relevant_press": 0,
        "total_claims": 0,
    })
    for r in results:
        date = r.get("date", "")
        year = date[:4] if date and len(date) >= 4 else "unknown"
        yearly[year]["total_docs"] += 1
        if r.get("content_type") == "speech":
            yearly[year]["speeches"] += 1
        else:
            yearly[year]["press_releases"] += 1
        if r.get("is_relevant"):
            yearly[year]["relevant_docs"] += 1
            if r.get("content_type") == "speech":
                yearly[year]["relevant_speeches"] += 1
            else:
                yearly[year]["relevant_press"] += 1
        yearly[year]["total_claims"] += len(r.get("claims", []))

    # Per-juncture breakdown (thesis-defined)
    junctures = {
        "J1_autocephaly_2018-19": ("2018-01-01", "2019-05-19"),
        "J2_invasion_2022": ("2022-02-24", "2023-12-31"),
        "J3_law_2024": ("2024-01-01", "2024-12-31"),
        "J4_enforcement_2025": ("2025-01-01", "2025-12-31"),
        "interstitial_2019-2022": ("2019-05-20", "2022-02-23"),
    }
    juncture_stats = {}
    for jname, (jstart, jend) in junctures.items():
        j_docs = [r for r in results
                   if r.get("date", "") >= jstart and r.get("date", "") <= jend]
        j_relevant = [r for r in j_docs if r.get("is_relevant")]
        j_claims = sum(len(r.get("claims", [])) for r in j_docs)
        juncture_stats[jname] = {
            "date_range": f"{jstart} to {jend}",
            "total_docs": len(j_docs),
            "relevant_docs": len(j_relevant),
            "total_claims": j_claims,
        }

    # Category co-occurrence in relevant documents
    category_cooccurrence = Counter()
    for r in relevant_docs:
        cats = tuple(sorted(r.get("matched_categories", [])))
        category_cooccurrence[str(cats)] += 1

    summary = {
        "generated_at": datetime.now().isoformat(),
        "overview": {
            "total_documents_scraped": total_docs,
            "total_speeches": len(speeches),
            "total_press_releases": len(press_releases),
            "documents_containing_relevant_terms": len(relevant_docs),
            "relevant_speeches": len(relevant_speeches),
            "relevant_press_releases": len(relevant_press),
            "total_claims_extracted": len(all_claims),
            "unique_claims_sentences": len(set(c["sentence"] for c in all_claims)),
        },
        "claims_by_category": dict(claims_by_category.most_common()),
        "top_matched_terms": dict(claims_by_term.most_common(30)),
        "yearly_breakdown": dict(sorted(yearly.items())),
        "juncture_breakdown": juncture_stats,
        "category_cooccurrence_in_relevant_docs": dict(
            category_cooccurrence.most_common(20)
        ),
    }
    return summary


def print_summary(summary: dict):
    """Pretty-print the summary to console."""
    ov = summary["overview"]

    print("\n" + "=" * 70)
    print("CORPUS ANALYSIS SUMMARY")
    print("=" * 70)

    print(f"\n1. TOTAL DOCUMENTS SCRAPED")
    print(f"   Speeches:        {ov['total_speeches']:>6}")
    print(f"   Press releases:  {ov['total_press_releases']:>6}")
    print(f"   TOTAL:           {ov['total_documents_scraped']:>6}")

    print(f"\n2. DOCUMENTS CONTAINING RELEVANT TERMS")
    print(f"   (= contains church/religion term + at least one securitisation term)")
    print(f"   Speeches:        {ov['relevant_speeches']:>6}")
    print(f"   Press releases:  {ov['relevant_press_releases']:>6}")
    print(f"   TOTAL:           {ov['documents_containing_relevant_terms']:>6}")

    print(f"\n3. CLAIMS (sentences with matched terms)")
    print(f"   Total claims extracted:   {ov['total_claims_extracted']:>6}")
    print(f"   Unique sentence matches:  {ov['unique_claims_sentences']:>6}")

    print(f"\n4. CLAIMS BY CODING DIMENSION")
    for cat, count in summary["claims_by_category"].items():
        desc = config.SEED_TERMS.get(cat, {}).get("description", cat)
        print(f"   {desc:<50} {count:>6}")

    print(f"\n5. TOP 15 MATCHED TERMS")
    for term, count in list(summary["top_matched_terms"].items())[:15]:
        print(f"   {term:<40} {count:>6}")

    print(f"\n6. YEARLY BREAKDOWN")
    print(f"   {'Year':<8} {'Total':>6} {'Speeches':>9} {'Press':>6} {'Relevant':>9} {'Claims':>7}")
    print(f"   {'-'*50}")
    for year, data in sorted(summary["yearly_breakdown"].items()):
        print(f"   {year:<8} {data['total_docs']:>6} {data['speeches']:>9} "
              f"{data['press_releases']:>6} {data['relevant_docs']:>9} {data['total_claims']:>7}")

    print(f"\n7. JUNCTURE BREAKDOWN")
    for jname, jdata in summary["juncture_breakdown"].items():
        print(f"   {jname}")
        print(f"     Period:    {jdata['date_range']}")
        print(f"     Documents: {jdata['total_docs']}  Relevant: {jdata['relevant_docs']}  Claims: {jdata['total_claims']}")

    print("\n" + "=" * 70)


def main():
    parser = argparse.ArgumentParser(description="Analyse scraped corpus")
    parser.add_argument("--corpus-dir", default=config.CORPUS_DIR)
    args = parser.parse_args()

    # Load corpus
    docs = load_corpus(args.corpus_dir)
    if not docs:
        print("No documents to analyse.")
        sys.exit(1)

    # Build morphologically-expanded regex patterns
    print("\nBuilding morphologically-expanded search patterns...")
    print("(This expands each seed term into all Ukrainian/Russian declensions)")
    term_regexes = build_all_regexes(config.SEED_TERMS)
    total_patterns = sum(len(terms) for terms in term_regexes.values())
    print(f"Built {total_patterns} term patterns across {len(term_regexes)} categories")

    # Analyse each document
    print("\nAnalysing documents...")
    results = []
    for i, doc in enumerate(docs):
        result = analyse_document(doc, term_regexes)
        results.append(result)
        if (i + 1) % 50 == 0:
            print(f"  Processed {i+1}/{len(docs)}...")

    # Extract all claims into a separate file
    all_claims = []
    claim_id = 0
    for r in results:
        for c in r.get("claims", []):
            claim_id += 1
            c["claim_id"] = claim_id
            all_claims.append(c)

    # Compute summary
    summary = compute_summary(results)

    # Save outputs
    output_dir = Path(config.OUTPUT_DIR)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Results: per-document analysis (without full body text to keep file manageable)
    results_slim = []
    for r in results:
        slim = {k: v for k, v in r.items() if k not in ("body_text", "body_html", "claims")}
        slim["claim_count"] = len(r.get("claims", []))
        results_slim.append(slim)

    results_path = output_dir / "results.json"
    results_path.write_text(
        json.dumps(results_slim, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\nPer-document results saved to {results_path}")

    # Claims file
    claims_path = output_dir / "claims.json"
    claims_path.write_text(
        json.dumps(all_claims, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Claims saved to {claims_path} ({len(all_claims)} claims)")

    # Summary
    summary_path = output_dir / "summary.json"
    summary_path.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Summary saved to {summary_path}")

    # Print summary
    print_summary(summary)


if __name__ == "__main__":
    main()
