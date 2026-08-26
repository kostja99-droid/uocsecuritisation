#!/usr/bin/env python3
"""
Multi-source scraper for Ukraine securitisation thesis.

Scrapes four sources:
  1. president.gov.ua — speeches (Poroshenko 2018-19 + Zelensky 2019-present)
  2. president.gov.ua — press releases (/news/all)
  3. rada.gov.ua — plenary stenograms
  4. sbu.gov.ua — press releases

Outputs JSON files to output/corpus/ in the same format as the R scraper,
so the existing NLP pipeline (03_analyse.R etc.) can ingest them directly.

Usage:
  pip install requests beautifulsoup4 lxml
  python scrape_ukraine_sources.py [--source speeches|press|rada|sbu|all]
                                   [--start 2018-01-01] [--end 2025-12-31]
                                   [--resume]
"""

import argparse
import hashlib
import json
import os
import re
import sys
import time
from datetime import date, datetime
from pathlib import Path
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup

CORPUS_DIR = Path("output/corpus")
OUTPUT_DIR = Path("output")

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
)

UK_MONTHS = {
    "січня": 1, "лютого": 2, "березня": 3, "квітня": 4,
    "травня": 5, "червня": 6, "липня": 7, "серпня": 8,
    "вересня": 9, "жовтня": 10, "листопада": 11, "грудня": 12,
}

DELAY_RANGE = (1.5, 3.0)


def doc_id(url: str) -> str:
    return hashlib.md5(url.encode()).hexdigest()[:12]


def parse_uk_date(text: str) -> str | None:
    if not text:
        return None
    text = text.strip()
    # ISO
    m = re.match(r"(\d{4}-\d{2}-\d{2})", text)
    if m:
        return m.group(1)
    # dd.mm.yyyy
    m = re.match(r"(\d{2})\.(\d{2})\.(\d{4})", text)
    if m:
        return f"{m.group(3)}-{m.group(2)}-{m.group(1)}"
    # "dd monthname yyyy"
    m = re.match(r"(\d{1,2})\s+(\S+)\s+(\d{4})", text)
    if m:
        month = UK_MONTHS.get(m.group(2).lower())
        if month:
            return f"{m.group(3)}-{month:02d}-{int(m.group(1)):02d}"
    return None


def in_range(date_str: str | None, start: date, end: date) -> bool | None:
    if not date_str:
        return None
    try:
        d = date.fromisoformat(date_str)
        return start <= d <= end
    except ValueError:
        return None


class Scraper:
    def __init__(self, delay_range=DELAY_RANGE, max_retries=3, timeout=30):
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": UA,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "uk-UA,uk;q=0.9,en-US;q=0.8,en;q=0.7",
            "Accept-Encoding": "gzip, deflate, br",
        })
        self.delay_range = delay_range
        self.max_retries = max_retries
        self.timeout = timeout
        self.stats = {"fetched": 0, "saved": 0, "skipped": 0, "errors": 0}

    def fetch(self, url: str) -> str | None:
        import random
        time.sleep(random.uniform(*self.delay_range))
        for attempt in range(1, self.max_retries + 1):
            try:
                resp = self.session.get(url, timeout=self.timeout)
                if resp.status_code == 200:
                    self.stats["fetched"] += 1
                    return resp.text
                print(f"  [attempt {attempt}/{self.max_retries}] HTTP {resp.status_code} for {url}")
            except requests.RequestException as e:
                print(f"  [attempt {attempt}/{self.max_retries}] Error: {e}")
            if attempt < self.max_retries:
                time.sleep(2 ** attempt)
        self.stats["errors"] += 1
        return None

    def save_doc(self, doc: dict, resume: bool = False) -> bool:
        CORPUS_DIR.mkdir(parents=True, exist_ok=True)
        path = CORPUS_DIR / f"{doc['id']}.json"
        if resume and path.exists():
            self.stats["skipped"] += 1
            return False
        with open(path, "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, indent=2)
        self.stats["saved"] += 1
        return True


# ── Source 1 & 2: president.gov.ua ───────────────────────

class PresidentScraper:
    BASE = "https://www.president.gov.ua"

    def __init__(self, scraper: Scraper, content_type: str, path: str):
        self.s = scraper
        self.content_type = content_type
        self.path = path

    def scrape(self, start: date, end: date, resume: bool = False):
        print(f"\n{'='*60}")
        print(f"Scraping president.gov.ua {self.path}")
        print(f"Date range: {start} to {end}")
        print(f"{'='*60}")

        url = f"{self.BASE}{self.path}"
        page_num = 0
        consecutive_oor = 0
        docs = []

        while url and consecutive_oor < 5:
            page_num += 1
            print(f"\n--- Listing page {page_num}: {url}")
            html = self.s.fetch(url)
            if not html:
                print("  Failed to fetch listing page, stopping.")
                break

            items, next_url = self._parse_listing(html)
            print(f"  Found {len(items)} items")
            if not items:
                break

            for item in items:
                did = doc_id(item["url"])
                doc_path = CORPUS_DIR / f"{did}.json"
                if resume and doc_path.exists():
                    print(f"  [skip] {item['title'][:60]}...")
                    self.s.stats["skipped"] += 1
                    continue

                print(f"  Fetching: {item['title'][:60]}...")
                article_html = self.s.fetch(item["url"])
                if not article_html:
                    continue

                article = self._parse_article(article_html)
                date_str = article.get("date") or parse_uk_date(item.get("date_text", ""))

                check = in_range(date_str, start, end)
                if check is False:
                    consecutive_oor += 1
                    print(f"    Date {date_str} out of range, skipping.")
                    continue
                if check is True:
                    consecutive_oor = 0

                body = article.get("body_text", "")
                doc = {
                    "id": did,
                    "url": item["url"],
                    "title": article.get("title") or item["title"],
                    "date": date_str,
                    "content_type": self.content_type,
                    "source": "president.gov.ua",
                    "body_text": body,
                    "word_count": len(body.split()),
                    "scraped_at": datetime.now().isoformat(timespec="seconds"),
                }
                self.s.save_doc(doc, resume)
                docs.append(doc)
                print(f"    Saved: {did}.json ({doc['word_count']} words)")

            url = next_url
            if not url and page_num < 500:
                constructed = f"{self.BASE}{self.path}/page/{page_num + 1}"
                test_html = self.s.fetch(constructed)
                if test_html:
                    test_items, _ = self._parse_listing(test_html)
                    if test_items:
                        url = constructed

        print(f"\nTotal documents saved for {self.path}: {len(docs)}")
        return docs

    def _parse_listing(self, html: str):
        soup = BeautifulSoup(html, "lxml")
        items = []
        urls_seen = set()

        for sel in ["div.item_stat_headline", "div.news_item",
                     "li.item_stat_headline_line", "div.col-md-8 div.item", "article"]:
            articles = soup.select(sel)
            if articles:
                break
        else:
            articles = []

        if not articles:
            for link in soup.select("a[href*='/news/']"):
                href = link.get("href", "")
                title = link.get_text(strip=True)
                if len(title) < 10 or "page" in href:
                    continue
                full = href if href.startswith("http") else urljoin(self.BASE, href)
                if full not in urls_seen:
                    urls_seen.add(full)
                    items.append({"title": title, "url": full, "date_text": ""})
        else:
            for art in articles:
                link = art.find("a")
                if not link:
                    continue
                href = link.get("href", "")
                title = link.get_text(strip=True)
                if len(title) < 5:
                    continue
                full = href if href.startswith("http") else urljoin(self.BASE, href)
                if full in urls_seen:
                    continue
                urls_seen.add(full)

                date_text = ""
                time_el = art.find("time")
                if time_el:
                    date_text = time_el.get("datetime", "") or time_el.get_text(strip=True)
                else:
                    date_el = art.find(class_=re.compile(r"date"))
                    if date_el:
                        date_text = date_el.get_text(strip=True)

                items.append({"title": title, "url": full, "date_text": date_text})

        # Next page
        next_url = None
        next_link = soup.select_one("a.next, a.pager-next")
        if next_link and next_link.get("href"):
            href = next_link["href"]
            next_url = href if href.startswith("http") else urljoin(self.BASE, href)

        if not next_url:
            pager = soup.find(class_=re.compile(r"pag"))
            if pager:
                active = pager.find(class_=["active", "current"])
                if active:
                    siblings = pager.find_all("a")
                    active_text = active.get_text(strip=True)
                    found = False
                    for s in siblings:
                        if found and s.get("href"):
                            href = s["href"]
                            next_url = href if href.startswith("http") else urljoin(self.BASE, href)
                            break
                        if s.get_text(strip=True) == active_text:
                            found = True

        return items, next_url

    def _parse_article(self, html: str) -> dict:
        soup = BeautifulSoup(html, "lxml")

        title = ""
        for sel in ["h1", "h2.entry-title", ".article_header h2", ".headline"]:
            el = soup.select_one(sel)
            if el:
                title = el.get_text(strip=True)
                break

        date_text = ""
        for sel in ["time", ".date", ".article_date", ".news_date", ".created"]:
            el = soup.select_one(sel)
            if el:
                date_text = el.get("datetime", "") or el.get_text(strip=True)
                break

        body = ""
        for sel in [".article_content", ".field-name-body", ".text",
                    ".news_content", ".entry-content", "article .content",
                    "#content .field-item"]:
            el = soup.select_one(sel)
            if el:
                body = el.get_text("\n", strip=True)
                break
        if not body:
            for sel in ["main", "article", "#content"]:
                el = soup.select_one(sel)
                if el:
                    body = el.get_text("\n", strip=True)
                    break

        return {"title": title, "date": parse_uk_date(date_text), "body_text": body}


# ── Source 3: Rada stenograms ────────────────────────────

class RadaScraper:
    BASE = "https://www.rada.gov.ua"

    # 8th convocation: 2014-11-27 to 2019-08-29 (sessions 1-11)
    # 9th convocation: 2019-08-29 to present (sessions 1-ongoing)
    CONVOCATIONS = {
        8: {"start": "2014-11-27", "end": "2019-08-28", "sessions": range(1, 12)},
        9: {"start": "2019-08-29", "end": "2030-01-01", "sessions": range(1, 16)},
    }

    def __init__(self, scraper: Scraper):
        self.s = scraper

    def scrape(self, start: date, end: date, resume: bool = False):
        print(f"\n{'='*60}")
        print(f"Scraping Rada stenograms (rada.gov.ua)")
        print(f"Date range: {start} to {end}")
        print(f"{'='*60}")

        docs = []

        # Determine which convocations/sessions overlap with date range
        for conv_num, conv_info in self.CONVOCATIONS.items():
            conv_start = date.fromisoformat(conv_info["start"])
            conv_end = date.fromisoformat(conv_info["end"])

            if conv_end < start or conv_start > end:
                continue

            print(f"\n  Convocation {conv_num}")
            # First get the list of plenary sessions
            index_url = f"{self.BASE}/meeting/stenogr/"
            html = self.s.fetch(index_url)
            if not html:
                # Try alternative URL patterns
                for session_num in conv_info["sessions"]:
                    session_docs = self._scrape_session(conv_num, session_num, start, end, resume)
                    docs.extend(session_docs)
                continue

            session_links = self._parse_stenogram_index(html, conv_num)
            print(f"  Found {len(session_links)} session links")

            for link_info in session_links:
                date_str = link_info.get("date")
                check = in_range(date_str, start, end)
                if check is False:
                    continue

                did = doc_id(link_info["url"])
                if resume and (CORPUS_DIR / f"{did}.json").exists():
                    self.s.stats["skipped"] += 1
                    continue

                print(f"  Fetching stenogram: {link_info.get('title', '')[:60]}...")
                steno_html = self.s.fetch(link_info["url"])
                if not steno_html:
                    continue

                body = self._parse_stenogram(steno_html)
                doc = {
                    "id": did,
                    "url": link_info["url"],
                    "title": link_info.get("title", f"Rada stenogram {date_str}"),
                    "date": date_str,
                    "content_type": "rada_stenogram",
                    "source": "rada.gov.ua",
                    "convocation": conv_num,
                    "body_text": body,
                    "word_count": len(body.split()),
                    "scraped_at": datetime.now().isoformat(timespec="seconds"),
                }
                self.s.save_doc(doc, resume)
                docs.append(doc)
                print(f"    Saved: {did}.json ({doc['word_count']} words)")

        print(f"\nTotal Rada stenograms saved: {len(docs)}")
        return docs

    def _scrape_session(self, conv: int, session: int, start: date, end: date, resume: bool):
        url = f"{self.BASE}/meeting/stenogr/{session}"
        html = self.s.fetch(url)
        if not html:
            return []

        links = self._parse_stenogram_index(html, conv)
        docs = []
        for link_info in links:
            check = in_range(link_info.get("date"), start, end)
            if check is False:
                continue

            did = doc_id(link_info["url"])
            if resume and (CORPUS_DIR / f"{did}.json").exists():
                self.s.stats["skipped"] += 1
                continue

            steno_html = self.s.fetch(link_info["url"])
            if not steno_html:
                continue

            body = self._parse_stenogram(steno_html)
            doc = {
                "id": did,
                "url": link_info["url"],
                "title": link_info.get("title", ""),
                "date": link_info.get("date"),
                "content_type": "rada_stenogram",
                "source": "rada.gov.ua",
                "convocation": conv,
                "body_text": body,
                "word_count": len(body.split()),
                "scraped_at": datetime.now().isoformat(timespec="seconds"),
            }
            self.s.save_doc(doc, resume)
            docs.append(doc)
        return docs

    def _parse_stenogram_index(self, html: str, conv: int) -> list[dict]:
        soup = BeautifulSoup(html, "lxml")
        links = []
        seen = set()

        for a in soup.find_all("a", href=True):
            href = a["href"]
            if "/meeting/stenogr/" not in href and "/stenogr" not in href:
                continue
            if href in seen:
                continue
            seen.add(href)

            title = a.get_text(strip=True)
            full_url = href if href.startswith("http") else urljoin(self.BASE, href)

            # Try to extract date from title or surrounding text
            date_str = None
            text = title + " " + (a.parent.get_text(strip=True) if a.parent else "")
            date_str = parse_uk_date(text)
            if not date_str:
                m = re.search(r"(\d{2})\.(\d{2})\.(\d{4})", text)
                if m:
                    date_str = f"{m.group(3)}-{m.group(2)}-{m.group(1)}"

            links.append({"url": full_url, "title": title, "date": date_str})

        return links

    def _parse_stenogram(self, html: str) -> str:
        soup = BeautifulSoup(html, "lxml")
        # Rada stenograms have the text in the main content area
        for sel in [".stenograma", ".steno-text", ".session_text",
                    "#stenograma", ".main-content", ".content-main",
                    "article", "#content", "main"]:
            el = soup.select_one(sel)
            if el:
                return el.get_text("\n", strip=True)
        return soup.get_text("\n", strip=True)


# ── Source 4: SBU press releases ─────────────────────────

class SBUScraper:
    BASE = "https://sbu.gov.ua"

    def __init__(self, scraper: Scraper):
        self.s = scraper

    def scrape(self, start: date, end: date, resume: bool = False):
        print(f"\n{'='*60}")
        print(f"Scraping SBU press releases (sbu.gov.ua)")
        print(f"Date range: {start} to {end}")
        print(f"{'='*60}")

        docs = []
        # SBU news pages — try common URL patterns
        news_paths = ["/news/archive", "/news", "/ua/news"]
        page_num = 0

        for base_path in news_paths:
            url = f"{self.BASE}{base_path}"
            html = self.s.fetch(url)
            if html:
                print(f"  Found working path: {base_path}")
                break
        else:
            print("  Could not find SBU news listing. Trying direct page enumeration...")
            html = None

        if not html:
            # Try paginated news
            for page in range(1, 50):
                url = f"{self.BASE}/news/page/{page}"
                html = self.s.fetch(url)
                if not html:
                    break
                page_docs = self._process_listing(html, start, end, resume)
                if not page_docs and page > 1:
                    break
                docs.extend(page_docs)
        else:
            consecutive_empty = 0
            current_url = url
            while current_url and consecutive_empty < 3:
                page_num += 1
                print(f"\n--- SBU listing page {page_num}")

                if page_num > 1:
                    html = self.s.fetch(current_url)
                    if not html:
                        break

                page_docs = self._process_listing(html, start, end, resume)
                if not page_docs:
                    consecutive_empty += 1
                else:
                    consecutive_empty = 0
                    docs.extend(page_docs)

                current_url = self._find_next_page(html, current_url)

        print(f"\nTotal SBU press releases saved: {len(docs)}")
        return docs

    def _process_listing(self, html: str, start: date, end: date, resume: bool) -> list:
        soup = BeautifulSoup(html, "lxml")
        items = []
        seen = set()

        for a in soup.find_all("a", href=True):
            href = a["href"]
            if not re.search(r"/news/\d+|/press/|/article/", href):
                continue
            title = a.get_text(strip=True)
            if len(title) < 10:
                continue
            full = href if href.startswith("http") else urljoin(self.BASE, href)
            if full in seen:
                continue
            seen.add(full)

            # Date from surrounding context
            date_text = ""
            parent = a.parent
            if parent:
                time_el = parent.find("time")
                if time_el:
                    date_text = time_el.get("datetime", "") or time_el.get_text(strip=True)
                else:
                    date_el = parent.find(class_=re.compile(r"date"))
                    if date_el:
                        date_text = date_el.get_text(strip=True)

            items.append({"title": title, "url": full, "date_text": date_text})

        docs = []
        for item in items:
            did = doc_id(item["url"])
            if resume and (CORPUS_DIR / f"{did}.json").exists():
                self.s.stats["skipped"] += 1
                continue

            print(f"  Fetching: {item['title'][:60]}...")
            article_html = self.s.fetch(item["url"])
            if not article_html:
                continue

            article = self._parse_article(article_html)
            date_str = article.get("date") or parse_uk_date(item.get("date_text", ""))

            check = in_range(date_str, start, end)
            if check is False:
                continue

            body = article.get("body_text", "")
            doc = {
                "id": did,
                "url": item["url"],
                "title": article.get("title") or item["title"],
                "date": date_str,
                "content_type": "sbu_press_release",
                "source": "sbu.gov.ua",
                "body_text": body,
                "word_count": len(body.split()),
                "scraped_at": datetime.now().isoformat(timespec="seconds"),
            }
            self.s.save_doc(doc, resume)
            docs.append(doc)
            print(f"    Saved: {did}.json ({doc['word_count']} words)")

        return docs

    def _parse_article(self, html: str) -> dict:
        soup = BeautifulSoup(html, "lxml")

        title = ""
        for sel in ["h1", ".article-title", ".news-title", "h2.title"]:
            el = soup.select_one(sel)
            if el:
                title = el.get_text(strip=True)
                break

        date_text = ""
        for sel in ["time", ".date", ".article-date", ".news-date", ".created"]:
            el = soup.select_one(sel)
            if el:
                date_text = el.get("datetime", "") or el.get_text(strip=True)
                break

        body = ""
        for sel in [".article-body", ".article-content", ".news-body",
                    ".news-content", ".field-name-body", ".text",
                    "article .content", "#content .field-item"]:
            el = soup.select_one(sel)
            if el:
                body = el.get_text("\n", strip=True)
                break
        if not body:
            for sel in ["main", "article", "#content"]:
                el = soup.select_one(sel)
                if el:
                    body = el.get_text("\n", strip=True)
                    break

        return {"title": title, "date": parse_uk_date(date_text), "body_text": body}

    def _find_next_page(self, html: str, current_url: str) -> str | None:
        soup = BeautifulSoup(html, "lxml")
        next_link = soup.select_one("a.next, a.pager-next, li.next a, .pagination .next a")
        if next_link and next_link.get("href"):
            href = next_link["href"]
            return href if href.startswith("http") else urljoin(self.BASE, href)
        return None


# ── Main ─────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Multi-source Ukraine securitisation scraper")
    parser.add_argument("--source", default="all",
                        choices=["speeches", "press", "rada", "sbu", "all"],
                        help="Which source to scrape")
    parser.add_argument("--start", default="2018-01-01", help="Start date (YYYY-MM-DD)")
    parser.add_argument("--end", default="2025-12-31", help="End date (YYYY-MM-DD)")
    parser.add_argument("--resume", action="store_true", help="Skip already-scraped documents")
    args = parser.parse_args()

    start = date.fromisoformat(args.start)
    end = date.fromisoformat(args.end)

    CORPUS_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    scraper = Scraper()
    all_docs = []

    sources = {
        "speeches": lambda: PresidentScraper(scraper, "speech", "/news/speeches").scrape(start, end, args.resume),
        "press": lambda: PresidentScraper(scraper, "press_release", "/news/all").scrape(start, end, args.resume),
        "rada": lambda: RadaScraper(scraper).scrape(start, end, args.resume),
        "sbu": lambda: SBUScraper(scraper).scrape(start, end, args.resume),
    }

    if args.source == "all":
        for name, func in sources.items():
            print(f"\n{'#'*60}")
            print(f"# SOURCE: {name}")
            print(f"{'#'*60}")
            docs = func()
            all_docs.extend(docs)
    else:
        all_docs = sources[args.source]()

    # Write scrape index
    index_path = OUTPUT_DIR / "scrape_index.json"
    index_data = []
    for doc in all_docs:
        index_data.append({
            k: v for k, v in doc.items() if k != "body_text"
        })
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(index_data, f, ensure_ascii=False, indent=2)

    print(f"\n{'='*60}")
    print(f"SCRAPING COMPLETE")
    print(f"  Fetched:  {scraper.stats['fetched']}")
    print(f"  Saved:    {scraper.stats['saved']}")
    print(f"  Skipped:  {scraper.stats['skipped']}")
    print(f"  Errors:   {scraper.stats['errors']}")
    print(f"  Index:    {index_path}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
