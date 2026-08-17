"""
Lemmatisation and morphological expansion for Ukrainian and Russian.

Uses pymorphy3 to:
  1. Expand seed-term lemmas into all known inflected surface forms,
     so that a regex search catches every declension / conjugation.
  2. Lemmatise raw text for normalised comparison.

Ukrainian is an inflected Slavic language: a single noun like
"загроза" (threat) appears as загрози, загрозу, загрозою, загроз,
загрозам, загрозами, загрозах in different cases. The same applies
to adjectives, verbs, and participles. This module ensures that
the search catches all of them.
"""

import re
from functools import lru_cache
from typing import Optional

import pymorphy3


_morph_uk: Optional[pymorphy3.MorphAnalyzer] = None
_morph_ru: Optional[pymorphy3.MorphAnalyzer] = None


def get_morph_uk() -> pymorphy3.MorphAnalyzer:
    global _morph_uk
    if _morph_uk is None:
        _morph_uk = pymorphy3.MorphAnalyzer(lang="uk")
    return _morph_uk


def get_morph_ru() -> pymorphy3.MorphAnalyzer:
    global _morph_ru
    if _morph_ru is None:
        _morph_ru = pymorphy3.MorphAnalyzer(lang="ru")
    return _morph_ru


def expand_term(term: str, lang: str = "uk") -> set[str]:
    """
    Given a lemma (dictionary form), return the set of all known
    inflected surface forms, including the lemma itself.

    For multi-word terms (e.g. "національна безпека"), each word is
    expanded independently and the result is returned as a set containing
    the original multi-word term — the matching logic handles multi-word
    patterns separately via regex.
    """
    morph = get_morph_uk() if lang == "uk" else get_morph_ru()
    words = term.strip().split()

    if len(words) == 1:
        return _expand_single_word(words[0], morph)
    else:
        return _expand_multiword(words, morph)


def _expand_single_word(word: str, morph: pymorphy3.MorphAnalyzer) -> set[str]:
    forms = set()
    forms.add(word)
    forms.add(word.lower())

    parses = morph.parse(word)
    if not parses:
        return forms

    for parse in parses[:3]:
        lexeme = parse.lexeme
        for form in lexeme:
            forms.add(form.word)
            forms.add(form.word.lower())

    return forms


def _expand_multiword(words: list[str], morph: pymorphy3.MorphAnalyzer) -> set[str]:
    """
    For multi-word terms, expand each word independently
    and return the combined set. The matching logic will use
    regex patterns that allow for inflected forms of each word.
    """
    all_forms = set()
    all_forms.add(" ".join(words))
    all_forms.add(" ".join(w.lower() for w in words))

    expanded_per_word = []
    for w in words:
        expanded_per_word.append(_expand_single_word(w, morph))

    all_forms.update(expanded_per_word[0] if len(expanded_per_word) == 1
                     else expanded_per_word[0])
    return all_forms


def build_term_regex(term: str, lang: str = "uk") -> re.Pattern:
    """
    Build a compiled regex that matches any inflected form of the term.
    For multi-word terms, each word is expanded and joined with
    flexible whitespace.
    """
    morph = get_morph_uk() if lang == "uk" else get_morph_ru()
    words = term.strip().split()

    if len(words) == 1:
        forms = _expand_single_word(words[0], morph)
        alternatives = sorted(forms, key=len, reverse=True)
        pattern = r"\b(?:" + "|".join(re.escape(f) for f in alternatives) + r")\b"
        return re.compile(pattern, re.IGNORECASE | re.UNICODE)
    else:
        word_patterns = []
        for w in words:
            forms = _expand_single_word(w, morph)
            alternatives = sorted(forms, key=len, reverse=True)
            word_patterns.append(
                r"(?:" + "|".join(re.escape(f) for f in alternatives) + r")"
            )
        pattern = r"\b" + r"\s+".join(word_patterns) + r"\b"
        return re.compile(pattern, re.IGNORECASE | re.UNICODE)


def build_all_regexes(seed_terms: dict) -> dict:
    """
    Build compiled regex patterns for every seed term across all
    categories and both languages.

    Returns:
        {
            "category_name": {
                "term_original": {
                    "lang": "uk"|"ru",
                    "regex": compiled_pattern,
                    "lemma": original_term,
                }
            }
        }
    """
    result = {}
    for category, data in seed_terms.items():
        result[category] = {}
        for term in data.get("terms_uk", []):
            key = f"uk:{term}"
            result[category][key] = {
                "lang": "uk",
                "regex": build_term_regex(term, "uk"),
                "lemma": term,
            }
        for term in data.get("terms_ru", []):
            key = f"ru:{term}"
            result[category][key] = {
                "lang": "ru",
                "regex": build_term_regex(term, "ru"),
                "lemma": term,
            }
    return result


@lru_cache(maxsize=4096)
def lemmatise_word(word: str, lang: str = "uk") -> str:
    """Lemmatise a single word. Returns the most likely lemma."""
    morph = get_morph_uk() if lang == "uk" else get_morph_ru()
    parses = morph.parse(word)
    if parses:
        return parses[0].normal_form
    return word.lower()


def lemmatise_text(text: str, lang: str = "uk") -> str:
    """Lemmatise an entire text, returning space-separated lemmas."""
    tokens = re.findall(r"[а-яіїєґёА-ЯІЇЄҐЁ''-]+", text)
    return " ".join(lemmatise_word(t, lang) for t in tokens)
