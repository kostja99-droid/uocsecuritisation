"""
Browser-based scraper using Playwright for president.gov.ua.

Use this when the regular HTTP scraper (scrape.py) gets blocked with
HTTP 403 errors. Playwright drives a real Chromium browser, which
bypasses anti-bot protections.

REQUIRES:
    pip install playwright
    playwright install chromium

Usage:
    python -m scraper.scrape_browser [--category speeches|press_releases|all]
                                     [--start 2018-01-01] [--end 2025-12-31]
                                     [--resume]
"""

import argparse
import hashlib
import json
import re
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

from bs4 import BeautifulSoup

from . import config


def doc_id(url: str) -> str:
    return hashlib.md5(url.encode()).hexdigest()[:12]


class BrowserScraper:
    def __init__(self):
        self.browser = None
        self.page = None

    def start(self):
        from playwright.sync_api import sync_playwright
        self._pw = sync_playwright().start()
        self.browser = self._pw.chromium.launch(headless=True)
        self.page = self.browser.new_page(
            user_agent=config.USER_AGENT,
            locale="uk-UA",
        )
        print("Browser started.")

    def stop(self):
        if self.browser:
            self.browser.close()
            self._pw.stop()
            self.browser = None
            self.page = None
            print("Browser closed.")

    def fetch_page(self, url: str) -> Optional[str]:
        for attempt in range(config.MAX_RETRIES):
            try:
                time.sleep(max(1.5, config.REQUEST_DELAY[0]))
                self.page.goto(url, timeout=30000, wait_until="domcontentloaded")
                time.sleep(2)
                html = self.page.content()
                if html and len(html) > 200:
                    return html
                print(f"  [attempt {attempt+1}] Page too small ({len(html or '')} chars)")
            except Exception as e:
                print(f"  [attempt {attempt+1}/{config.MAX_RETRIES}] Error: {e}")
            if attempt < config.MAX_RETRIES - 1:
                time.sleep(2 ** (attempt + 1))
        return None


def _parse_date(text: str) -> Optional[str]:
    text = text.strip()
    for fmt in ["%d %B %Y року", "%d %B %Y", "%d.%m.%Y", "%Y-%m-%d", "%d/%m/%Y"]:
        try:
            return datetime.strptime(text, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    uk_months = {
        "січня": "01", "лютого": "02", "березня": "03", "квітня": "04",
        "травня": "05", "червня": "06", "липня": "07", "серпня": "08",
        "вересня": "09", "жовтня": "10", "листопада": "11", "грудня": "12",
    }
    m = re.search(r"(\d{1,2})\s+(\w+)\s+(\d{4})", text)
    if m:
        day, month_name, year = m.group(1), m.group(2).lower(), m.group(3)
        month_num = uk_months.get(month_name)
        if month_num:
            return f"{year}-{month_num}-{int(day):02d}"
    return None


def _parse_listing_page(html: str) -> tuple[list[dict], Optional[str]]:
    soup = BeautifulSoup(html, "lxml")
    items = []
    article_selectors = [
        "div.item_stat_headline", "div.news_item",
        "li.item_stat_headline_line", "div.col-md-8 div.item",
        "article", "div.view-content div.views-row",
    ]
    articles = []
    for selector in article_selectors:
        articles = soup.select(selector)
        if articles:
            break
    if not articles:
        for a in soup.find_all("a", href=True):
            href = a["href"]
            if "/news/" in href and href != "/news/" and "page" not in href:
                title = a.get_text(strip=True)
                if title and len(title) > 10:
                    full_url = href if href.startswith("http") else config.BASE_URL + href
                    items.append({"title": title, "url": full_url, "date_text": ""})
    else:
        for art in articles:
            link = art.find("a", href=True)
            if not link:
                continue
            href = link["href"]
            title = link.get_text(strip=True)
            if not title or len(title) < 5:
                continue
            full_url = href if href.startswith("http") else config.BASE_URL + href
            date_el = art.find("time") or art.find(class_=re.compile(r"date|time"))
            date_text = ""
            if date_el:
                date_text = date_el.get("datetime", "") or date_el.get_text(strip=True)
            items.append({"title": title, "url": full_url, "date_text": date_text})

    next_url = None
    next_link = soup.find("a", class_=re.compile(r"next|pager-next"))
    if next_link and next_link.get("href"):
        href = next_link["href"]
        next_url = href if href.startswith("http") else config.BASE_URL + href
    else:
        pager = soup.find(class_=re.compile(r"pag|page"))
        if pager:
            active = pager.find(class_=re.compile(r"active|current"))
            if active:
                next_sibling = active.find_next_sibling("a") or active.find_next("a")
                if next_sibling and next_sibling.get("href"):
                    href = next_sibling["href"]
                    next_url = href if href.startswith("http") else config.BASE_URL + href

    seen = set()
    unique_items = []
    for item in items:
        if item["url"] not in seen:
            seen.add(item["url"])
            unique_items.append(item)
    return unique_items, next_url


def _parse_article_page(html: str) -> dict:
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
    parsed_date = _parse_date(date_text) if date_text else None
    body_text = ""
    for sel in [".article_content", ".field-name-body", ".text",
                ".news_content", ".entry-content", "article .content",
                "#content .field-item"]:
        el = soup.select_one(sel)
        if el:
            body_text = el.get_text(separator="\n", strip=True)
            break
    if not body_text:
        main = soup.find("main") or soup.find("article") or soup.find(id="content")
        if main:
            body_text = main.get_text(separator="\n", strip=True)
    return {"title": title, "date": parsed_date or date_text, "body_text": body_text}


def scrape_category(scraper: BrowserScraper, category_key: str,
                    start_date: str, end_date: str, resume: bool = False) -> list[dict]:
    cat = config.CATEGORIES[category_key]
    corpus_dir = Path(config.CORPUS_DIR)
    corpus_dir.mkdir(parents=True, exist_ok=True)
    all_docs = []
    start_dt = datetime.strptime(start_date, "%Y-%m-%d")
    end_dt = datetime.strptime(end_date, "%Y-%m-%d")

    for listing_path in cat["listing_paths"]:
        page_url = config.BASE_URL + listing_path
        page_num = 0
        consecutive_out_of_range = 0

        print(f"\n{'='*60}")
        print(f"Scraping: {cat['label_en']} ({listing_path})")
        print(f"Date range: {start_date} to {end_date}")
        print(f"{'='*60}")

        while page_url and consecutive_out_of_range < 5:
            page_num += 1
            print(f"\n--- Listing page {page_num}: {page_url}")
            html = scraper.fetch_page(page_url)
            if not html:
                print("  Failed to fetch listing page, stopping.")
                break
            items, next_url = _parse_listing_page(html)
            print(f"  Found {len(items)} items on this page")
            if not items:
                print("  No items found.")
                break
            for item in items:
                url = item["url"]
                did = doc_id(url)
                doc_path = corpus_dir / f"{did}.json"
                if resume and doc_path.exists():
                    try:
                        existing = json.loads(doc_path.read_text("utf-8"))
                        all_docs.append(existing)
                        print(f"  [skip] {item['title'][:60]}...")
                        continue
                    except (json.JSONDecodeError, KeyError):
                        pass
                print(f"  Fetching: {item['title'][:60]}...")
                article_html = scraper.fetch_page(url)
                if not article_html:
                    print(f"    Failed to fetch article.")
                    continue
                article = _parse_article_page(article_html)
                date_str = article["date"]
                if not date_str and item["date_text"]:
                    date_str = _parse_date(item["date_text"]) or item["date_text"]
                try:
                    doc_dt = datetime.strptime(date_str[:10], "%Y-%m-%d")
                    if doc_dt < start_dt or doc_dt > end_dt:
                        consecutive_out_of_range += 1
                        print(f"    Date {date_str} out of range, skipping.")
                        continue
                    consecutive_out_of_range = 0
                except (ValueError, TypeError):
                    consecutive_out_of_range = 0
                doc = {
                    "id": did, "url": url,
                    "title": article["title"] or item["title"],
                    "date": date_str, "content_type": cat["content_type"],
                    "body_text": article["body_text"],
                    "word_count": len(article["body_text"].split()),
                    "scraped_at": datetime.now().isoformat(),
                }
                doc_path.write_text(
                    json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8")
                all_docs.append(doc)
                print(f"    Saved: {did}.json ({doc['word_count']} words)")
            page_url = next_url
            if not page_url and page_num < 500:
                constructed = f"{config.BASE_URL}{listing_path}/page/{page_num + 1}"
                test_html = scraper.fetch_page(constructed)
                if test_html:
                    test_items, _ = _parse_listing_page(test_html)
                    if test_items:
                        page_url = constructed

    print(f"\n{'='*60}")
    print(f"Total documents scraped for '{category_key}': {len(all_docs)}")
    print(f"{'='*60}")
    return all_docs


def main():
    parser = argparse.ArgumentParser(
        description="Browser-based scraper for Ukrainian presidential speeches")
    parser.add_argument("--category", choices=["speeches", "press_releases", "all"],
                        default="all")
    parser.add_argument("--start", default=config.DATE_START)
    parser.add_argument("--end", default=config.DATE_END)
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()

    categories = (
        list(config.CATEGORIES.keys()) if args.category == "all"
        else [args.category]
    )

    scraper = BrowserScraper()
    scraper.start()
    try:
        all_docs = []
        for cat in categories:
            docs = scrape_category(scraper, cat, args.start, args.end, args.resume)
            all_docs.extend(docs)
        output_dir = Path(config.OUTPUT_DIR)
        output_dir.mkdir(parents=True, exist_ok=True)
        index_path = output_dir / "scrape_index.json"
        index_path.write_text(
            json.dumps(all_docs, ensure_ascii=False, indent=2, default=str),
            encoding="utf-8",
        )
        print(f"\nMaster index saved to {index_path} ({len(all_docs)} documents)")
    finally:
        scraper.stop()


if __name__ == "__main__":
    main()
