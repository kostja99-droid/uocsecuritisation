// ═══════════════════════════════════════════════════════════
// DESS Article Fetcher — paste into Chrome DevTools Console
//
// TWO STEPS:
//   Step 1: Collect all article URLs from listing pages
//   Step 2: Fetch each article's content
//
// 1. Open https://dess.gov.ua/category/news/ in Chrome
// 2. Press F12 → Console tab
// 3. Paste this entire script and press Enter
// 4. Wait ~15-20 minutes (~860 articles, 1.5s delay each)
// 5. A file "dess_articles.json" will auto-download when done
// ═══════════════════════════════════════════════════════════

(async function() {
  const BASE = "https://dess.gov.ua";
  const LISTING_URL = BASE + "/category/news/page/";
  const TOTAL_PAGES = 27;
  const DELAY = 1500; // ms between requests

  const wait = ms => new Promise(r => setTimeout(r, ms));

  // ── STEP 1: Collect article URLs from all listing pages ──

  console.log("=== STEP 1: Collecting article URLs ===");
  const allUrls = new Set();

  for (let page = 1; page <= TOTAL_PAGES; page++) {
    const url = page === 1
      ? BASE + "/category/news/"
      : LISTING_URL + page + "/";

    console.log(`[Page ${page}/${TOTAL_PAGES}] ${url}`);

    try {
      const resp = await fetch(url);
      if (!resp.ok) {
        console.warn(`  HTTP ${resp.status} — skipping page`);
        continue;
      }
      const html = await resp.text();
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, "text/html");

      // Elementor posts: look for article links in common patterns
      const links = doc.querySelectorAll("a[href]");
      let found = 0;
      links.forEach(a => {
        const href = a.getAttribute("href");
        if (!href) return;
        // Match article URLs: they're on dess.gov.ua, not /category/, /page/, /tag/
        if (href.startsWith(BASE + "/") &&
            !href.includes("/category/") &&
            !href.includes("/page/") &&
            !href.includes("/tag/") &&
            !href.includes("/wp-content/") &&
            !href.includes("/wp-admin/") &&
            !href.includes("/feed/") &&
            !href.includes("#") &&
            href !== BASE + "/" &&
            href !== BASE + "/news/" &&
            href.match(/\/[a-z0-9][\w-]+\/?$/)) {
          allUrls.add(href.replace(/\/$/, ""));
          found++;
        }
      });
      console.log(`  Found ${found} links (${allUrls.size} unique total)`);
    } catch (e) {
      console.error(`  Error on page ${page}: ${e.message}`);
    }
    await wait(DELAY);
  }

  const urls = [...allUrls];
  console.log(`\n=== STEP 1 COMPLETE: ${urls.length} unique article URLs ===\n`);

  // ── STEP 2: Fetch each article ───────────────────────────

  console.log("=== STEP 2: Fetching articles ===");
  const results = [];
  const failed = [];

  const ukMonths = {
    "січня":"01","лютого":"02","березня":"03","квітня":"04",
    "травня":"05","червня":"06","липня":"07","серпня":"08",
    "вересня":"09","жовтня":"10","листопада":"11","грудня":"12"
  };

  function parseUkDate(text) {
    if (!text) return "";
    text = text.trim();
    // ISO format
    if (/^\d{4}-\d{2}-\d{2}/.test(text)) return text.substring(0, 10);
    // DD.MM.YYYY
    const dotMatch = text.match(/(\d{2})\.(\d{2})\.(\d{4})/);
    if (dotMatch) return `${dotMatch[3]}-${dotMatch[2]}-${dotMatch[1]}`;
    // Ukrainian: "24 серпня 2026"
    const ukRe = /(\d{1,2})\s+(січня|лютого|березня|квітня|травня|червня|липня|серпня|вересня|жовтня|листопада|грудня)\s+(20[1-2]\d)/;
    const m = text.match(ukRe);
    if (m) return `${m[3]}-${ukMonths[m[2]]}-${m[1].padStart(2, "0")}`;
    return "";
  }

  for (let i = 0; i < urls.length; i++) {
    const url = urls[i];
    const slug = url.split("/").filter(Boolean).pop();
    console.log(`[${i+1}/${urls.length}] ${slug}`);

    try {
      const resp = await fetch(url);
      if (!resp.ok) {
        console.warn(`  HTTP ${resp.status} — skipping`);
        failed.push({url, error: `HTTP ${resp.status}`});
        await wait(1000);
        continue;
      }

      const html = await resp.text();
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, "text/html");

      // ── Title ──
      let title = "";
      const h1 = doc.querySelector("h1");
      if (h1) title = h1.textContent.trim();
      if (!title) {
        const ogTitle = doc.querySelector('meta[property="og:title"]');
        if (ogTitle) title = ogTitle.getAttribute("content") || "";
      }

      // ── Date ──
      let date = "";
      // 1. Try meta article:published_time
      const metaDate = doc.querySelector('meta[property="article:published_time"]');
      if (metaDate) date = (metaDate.getAttribute("content") || "").substring(0, 10);
      // 2. Try itemprop="datePublished"
      if (!date) {
        const dateEl = doc.querySelector('[itemprop="datePublished"]');
        if (dateEl) {
          date = dateEl.getAttribute("content") ||
                 dateEl.getAttribute("datetime") ||
                 dateEl.textContent.trim();
          date = parseUkDate(date);
        }
      }
      // 3. Try time element
      if (!date) {
        const timeEl = doc.querySelector("time[datetime]");
        if (timeEl) date = (timeEl.getAttribute("datetime") || "").substring(0, 10);
      }
      // 4. Try Elementor post-info date
      if (!date) {
        const postInfo = doc.querySelector(".elementor-post-info");
        if (postInfo) date = parseUkDate(postInfo.textContent);
      }
      // 5. Fallback: search body for Ukrainian date pattern
      if (!date) {
        const bodyText = doc.body ? doc.body.textContent : "";
        date = parseUkDate(bodyText);
      }

      // ── Body text ──
      let body = "";
      // Elementor content selectors (most specific first)
      const contentSelectors = [
        ".elementor-widget-theme-post-content .elementor-widget-container",
        ".elementor-widget-theme-post-content",
        ".entry-content",
        ".elementor-widget-text-editor .elementor-widget-container",
        "article .elementor-section",
        ".post-content",
        "article",
        "main"
      ];
      for (const sel of contentSelectors) {
        const el = doc.querySelector(sel);
        if (el && el.textContent.trim().length > 100) {
          // Extract text from paragraphs to get clean content
          const paras = el.querySelectorAll("p");
          if (paras.length > 0) {
            const texts = [];
            paras.forEach(p => {
              const t = p.textContent.trim();
              if (t.length > 10) texts.push(t);
            });
            if (texts.join("\n\n").length > 80) {
              body = texts.join("\n\n");
              break;
            }
          }
          // If no good paragraphs, use the container text
          body = el.textContent.trim();
          break;
        }
      }
      // Fallback: all <p> in body
      if (!body || body.length < 80) {
        const paragraphs = doc.querySelectorAll("p");
        const texts = [];
        paragraphs.forEach(p => {
          const t = p.textContent.trim();
          if (t.length > 15) texts.push(t);
        });
        body = texts.join("\n\n");
      }

      if (body.length < 50) {
        console.warn(`  Very short body (${body.length} chars)`);
      }

      results.push({ url, title, date, body });

      if ((i + 1) % 50 === 0) {
        console.log(`  Progress: ${results.length} fetched, ${failed.length} failed`);
      }
    } catch (e) {
      console.error(`  Error: ${e.message}`);
      failed.push({url, error: e.message});
    }

    await wait(DELAY);
  }

  console.log(`\n${"=".repeat(50)}`);
  console.log(`Done! Fetched: ${results.length}, Failed: ${failed.length}`);
  if (failed.length > 0) {
    console.log("Failed URLs:", failed);
  }

  // ── Download as JSON ──
  const blob = new Blob(
    [JSON.stringify({articles: results, failed: failed, total_listing_urls: urls.length}, null, 2)],
    {type: "application/json"}
  );
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "dess_articles.json";
  document.body.appendChild(a);
  a.click();
  a.remove();
  console.log("File dess_articles.json downloaded!");
})();
