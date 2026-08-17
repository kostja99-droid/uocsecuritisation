// ──────────────────────────────────────────────────────────
// fetch_articles.js — Run in browser console on president.gov.ua
//
// Fetches body text for all speech URLs. Uses concurrent requests
// for speed (~3-5 minutes for 1780 articles).
//
// HOW TO USE:
//   1. Open https://www.president.gov.ua in Chrome
//   2. Press F12 → Console tab
//   3. Paste this entire script and press Enter
//   4. Wait for it to finish (progress is shown in console)
//   5. A JSON file will auto-download when done
//
// RESUMABLE: Progress is saved in localStorage. If the browser
// crashes or you close the tab, just paste the script again —
// it picks up where it left off.
//
// To RESET and start over:
//   localStorage.removeItem('fetchedArticles');
//   localStorage.removeItem('fetchProgress');
// ──────────────────────────────────────────────────────────

(async () => {
  // ── All speech URLs (paste from CSV) ──────────────────
  // This will be populated by the R script or you can paste URLs here.
  // For now, we fetch the URL list from the CSV the user already has.

  const CSV_TEXT = `PASTE_CSV_HERE`;

  // If CSV_TEXT is still the placeholder, try to load from a variable
  let urls;
  if (CSV_TEXT === 'PASTE_CSV_HERE') {
    console.error('Please paste your CSV content into the CSV_TEXT variable, or use the loadFromCSV() approach below.');
    console.log('Alternative: run loadURLs([...]) with an array of URL strings.');
    return;
  }

  // Parse CSV
  const lines = CSV_TEXT.trim().split('\n');
  const hasHeader = lines[0].toLowerCase().includes('url');
  const dataLines = hasHeader ? lines.slice(1) : lines;

  urls = dataLines.map(line => {
    const match = line.match(/"?(https?:\/\/[^",\s]+)"?/);
    return match ? match[1] : null;
  }).filter(Boolean);

  console.log(`Parsed ${urls.length} URLs from CSV`);
  await fetchAllArticles(urls);
})();

// ── Core fetcher (also callable standalone) ─────────────
async function fetchAllArticles(urls) {
  const CONCURRENCY = 5;
  const DELAY_MS = 300;
  const SAVE_EVERY = 50;

  // Load previous progress
  let fetched = {};
  try {
    const saved = localStorage.getItem('fetchedArticles');
    if (saved) fetched = JSON.parse(saved);
  } catch(e) {}

  const alreadyDone = Object.keys(fetched).length;
  if (alreadyDone > 0) {
    console.log(`Resuming: ${alreadyDone} articles already fetched`);
  }

  // Filter out already-fetched URLs
  const remaining = urls.filter(u => !fetched[u]);
  console.log(`${remaining.length} articles to fetch (${alreadyDone} cached)`);

  let completed = alreadyDone;
  const total = urls.length;
  const startTime = Date.now();

  // Process in batches of CONCURRENCY
  for (let i = 0; i < remaining.length; i += CONCURRENCY) {
    const batch = remaining.slice(i, i + CONCURRENCY);

    const results = await Promise.allSettled(
      batch.map(async (url) => {
        await sleep(Math.random() * DELAY_MS);
        return fetchOneArticle(url);
      })
    );

    for (let j = 0; j < results.length; j++) {
      const url = batch[j];
      if (results[j].status === 'fulfilled' && results[j].value) {
        fetched[url] = results[j].value;
      } else {
        fetched[url] = { url, title: '', date: '', body_text: '', error: true };
      }
      completed++;
    }

    // Progress
    const elapsed = (Date.now() - startTime) / 1000;
    const rate = (completed - alreadyDone) / elapsed;
    const eta = rate > 0 ? Math.round((total - completed) / rate) : '?';
    console.log(`[${completed}/${total}] ${Math.round(completed/total*100)}% — ETA: ${eta}s`);

    // Save checkpoint
    if (completed % SAVE_EVERY < CONCURRENCY || i + CONCURRENCY >= remaining.length) {
      try {
        localStorage.setItem('fetchedArticles', JSON.stringify(fetched));
        localStorage.setItem('fetchProgress', JSON.stringify({
          completed, total, timestamp: new Date().toISOString()
        }));
      } catch(e) {
        console.warn('localStorage full, continuing without save');
      }
    }

    // Small delay between batches
    if (i + CONCURRENCY < remaining.length) {
      await sleep(DELAY_MS);
    }
  }

  // Build final output
  const articles = urls.map(url => fetched[url]).filter(Boolean);
  const successful = articles.filter(a => !a.error && a.body_text.length > 50);

  console.log(`\nDone! ${successful.length}/${total} articles fetched successfully`);
  console.log(`${articles.filter(a => a.error).length} failed`);
  console.log(`${articles.filter(a => !a.error && a.body_text.length <= 50).length} too short (likely redirects)`);

  // Download as JSON
  downloadJSON(articles, 'speech_articles.json');

  // Also download just the successful ones cleaned up
  const clean = successful.map(a => ({
    url: a.url,
    title: a.title,
    date: a.date,
    body_text: a.body_text,
    word_count: a.body_text.split(/\s+/).length
  }));
  downloadJSON(clean, 'speech_articles_clean.json');

  console.log('\nTwo files downloaded:');
  console.log('  speech_articles.json — all results (including failures)');
  console.log('  speech_articles_clean.json — only successful, cleaned');

  return articles;
}

// ── Fetch and parse a single article ────────────────────
async function fetchOneArticle(url) {
  const resp = await fetch(url, { credentials: 'include' });
  if (!resp.ok) {
    return { url, title: '', date: '', body_text: '', error: true, status: resp.status };
  }
  const html = await resp.text();
  const doc = new DOMParser().parseFromString(html, 'text/html');

  // Extract title
  let title = '';
  for (const sel of ['h1', 'h2.entry-title', '.article_header h2', '.headline']) {
    const el = doc.querySelector(sel);
    if (el) { title = el.textContent.trim(); break; }
  }

  // Extract date
  let date = '';
  for (const sel of ['time', '.date', '.article_date', '.news_date', '.created']) {
    const el = doc.querySelector(sel);
    if (el) {
      date = el.getAttribute('datetime') || el.textContent.trim();
      break;
    }
  }

  // Extract body text
  let body_text = '';
  for (const sel of [
    '.article_content', '.field-name-body', '.text',
    '.news_content', '.entry-content', 'article .content',
    '#content .field-item'
  ]) {
    const el = doc.querySelector(sel);
    if (el) { body_text = el.textContent.trim(); break; }
  }
  if (!body_text) {
    const main = doc.querySelector('main') || doc.querySelector('article') || doc.querySelector('#content');
    if (main) body_text = main.textContent.trim();
  }

  // Clean up body text: collapse whitespace, remove excess newlines
  body_text = body_text
    .replace(/\t/g, ' ')
    .replace(/ {2,}/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

  return { url, title, date, body_text, error: false };
}

// ── Helpers ─────────────────────────────────────────────
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function downloadJSON(data, filename) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(a.href);
}
