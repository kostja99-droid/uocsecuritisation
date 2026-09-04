// ═══════════════════════════════════════════════════════════
// Rada Stenogram Fetcher — paste into Chrome DevTools Console
//
// 1. Open https://rada.gov.ua in Chrome
// 2. Press F12 → Console tab
// 3. Paste this entire script and press Enter
// 4. Wait for it to finish (2s delay per URL)
// 5. A file "rada_articles.json" will auto-download when done
//
// To get the URL list: in RStudio, run:
//   source("R/01_config.R")
//   source("R/02_diagnose_rada.R")
//   generate_rada_urls()
// Then replace the urls array below with the output.
// ═══════════════════════════════════════════════════════════

(async function() {
  // ── PASTE YOUR URL LIST HERE ──────────────────────────
  // Run generate_rada_urls() in R to get this list, or
  // use generate_rada_urls(only_broken = FALSE) for all files.
  const urls = [
    // Example: "https://rada.gov.ua/meeting/stenogr/show/7001.html",
    // Paste URLs from R output here
  ];

  if (urls.length === 0) {
    console.error("No URLs! Run generate_rada_urls() in R first, then paste the URL array here.");
    return;
  }

  const results = [];
  const failed = [];

  const ukMonths = {
    "січня":"01","лютого":"02","березня":"03","квітня":"04",
    "травня":"05","червня":"06","липня":"07","серпня":"08",
    "вересня":"09","жовтня":"10","листопада":"11","грудня":"12"
  };

  console.log(`Starting Rada stenogram fetch: ${urls.length} URLs`);
  console.log("This may take a while. Do not close this tab.");

  for (let i = 0; i < urls.length; i++) {
    // Rewrite to www.rada.gov.ua to match the browser's origin
    const url = urls[i].replace("://rada.gov.ua", "://www.rada.gov.ua");
    const idMatch = url.match(/\/(\d+)\.html$/);
    const radaId = idMatch ? idMatch[1] : url.split("/").pop();
    console.log(`[${i+1}/${urls.length}] ID ${radaId}`);

    try {
      const resp = await fetch(url);
      if (!resp.ok) {
        console.warn(`  HTTP ${resp.status} — skipping`);
        failed.push({url, rada_id: radaId, error: `HTTP ${resp.status}`});
        await new Promise(r => setTimeout(r, 1000));
        continue;
      }

      const html = await resp.text();
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, "text/html");

      // ── Extract title ──
      let title = "";
      // Stenogram pages often have the session title in h2/h3
      for (const sel of [".item_content h2", ".item_content h1",
                          ".middle-column h2", ".WordSection1 h2",
                          "h2", "h1"]) {
        const el = doc.querySelector(sel);
        if (el) {
          const t = el.textContent.trim();
          if (t.length > 3 && t.length < 300 &&
              !/(Головна|Календар|Пошук|Контакти)/i.test(t)) {
            title = t;
            break;
          }
        }
      }
      if (!title) {
        const bodyText = doc.body ? doc.body.textContent : "";
        const sessionMatch = bodyText.match(/(Засідання[^\n]{0,150})/);
        if (sessionMatch) title = sessionMatch[1].trim();
      }

      // ── Extract date ──
      let date = "";
      // Look for Ukrainian date in the first portion of text
      const fullText = doc.body ? doc.body.textContent : "";
      const dateRe = /(\d{1,2})\s+(січня|лютого|березня|квітня|травня|червня|липня|серпня|вересня|жовтня|листопада|грудня)\s+(20[0-2]\d)/g;
      let dateMatch;
      while ((dateMatch = dateRe.exec(fullText)) !== null) {
        const yr = parseInt(dateMatch[3]);
        if (yr >= 2000 && yr <= 2025) {
          const day = dateMatch[1].padStart(2, "0");
          const month = ukMonths[dateMatch[2]];
          if (month) {
            date = `${dateMatch[3]}-${month}-${day}`;
            break;
          }
        }
      }
      // Fallback: dd.mm.yyyy
      if (!date) {
        const dotDateRe = /(\d{2})\.(\d{2})\.(20[0-2]\d)/g;
        let dm;
        while ((dm = dotDateRe.exec(fullText)) !== null) {
          const yr = parseInt(dm[3]);
          if (yr >= 2000 && yr <= 2025) {
            date = `${dm[3]}-${dm[2]}-${dm[1]}`;
            break;
          }
        }
      }

      // ── Extract body text ──
      let body = "";
      // Rada stenograms use .WordSection1 (Word HTML export) or .item_content
      for (const sel of [".WordSection1", ".item_content", ".middle-column",
                          ".stenograma", ".steno-text", ".session_text",
                          "#stenograma", ".article_content", "article",
                          "#content", "main"]) {
        const el = doc.querySelector(sel);
        if (el && el.textContent.trim().length > 500) {
          body = el.textContent.trim();
          break;
        }
      }
      // Fallback: join all substantial paragraphs
      if (!body || body.length < 500) {
        const paragraphs = doc.querySelectorAll("p");
        const texts = [];
        paragraphs.forEach(p => {
          const t = p.textContent.trim();
          if (t.length > 20) texts.push(t);
        });
        const pBody = texts.join("\n\n");
        if (pBody.length > body.length) body = pBody;
      }
      // Last fallback: full body text
      if (!body || body.length < 200) {
        body = fullText;
      }

      const wordCount = body.split(/\s+/).filter(w => w.length > 0).length;

      if (body.length < 200) {
        console.warn(`  Very short body (${body.length} chars) — may be empty`);
      } else {
        console.log(`  OK: ${wordCount} words, date=${date || "none"}`);
      }

      results.push({
        url: url,
        rada_id: parseInt(radaId) || radaId,
        title: title,
        date: date,
        body: body,
        word_count: wordCount
      });

    } catch (e) {
      console.error(`  Error: ${e.message}`);
      failed.push({url, rada_id: radaId, error: e.message});
    }

    // 2-second delay between requests
    await new Promise(r => setTimeout(r, 2000));
  }

  console.log(`\nDone! Fetched: ${results.length}, Failed: ${failed.length}`);
  if (failed.length > 0) {
    console.log("Failed URLs:", failed);
  }

  // Show word count stats
  const wordCounts = results.map(r => r.word_count).sort((a,b) => a - b);
  if (wordCounts.length > 0) {
    console.log(`Word counts: min=${wordCounts[0]}, median=${wordCounts[Math.floor(wordCounts.length/2)]}, max=${wordCounts[wordCounts.length-1]}`);
    const shortOnes = results.filter(r => r.word_count < 100);
    if (shortOnes.length > 0) {
      console.log(`${shortOnes.length} articles with <100 words (may still be empty):`);
      shortOnes.forEach(r => console.log(`  ID ${r.rada_id}: ${r.word_count} words`));
    }
  }

  // Download as JSON
  const blob = new Blob(
    [JSON.stringify({articles: results, failed: failed}, null, 2)],
    {type: "application/json"}
  );
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "rada_articles.json";
  document.body.appendChild(a);
  a.click();
  a.remove();
  console.log("File rada_articles.json downloaded!");
})();
