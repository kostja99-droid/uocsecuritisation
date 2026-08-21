// ──────────────────────────────────────────────────────────
// fetch_articles_quick.js — Paste into browser console on president.gov.ua
//
// Fetches body text for ALL speech URLs using 5 concurrent requests.
// Takes ~3-5 minutes for 1780 articles. Resumable via localStorage.
//
// STEPS:
//   1. Open https://www.president.gov.ua in Chrome
//   2. F12 → Console
//   3. Paste this ENTIRE script, press Enter
//   4. Wait (~3-5 min). Progress shown in console.
//   5. Downloads speech_articles_clean.json automatically
//
// TO RESET: localStorage.removeItem('fetchedArticles');
// ──────────────────────────────────────────────────────────

(async () => {
  // Step 1: Load URLs from the CSV you already scraped
  // We'll fetch the CSV listing pages to rebuild the URL list
  console.log('Loading URL list...');

  // First, try to get URLs from localStorage (if previously saved)
  let urls = [];
  try {
    const saved = localStorage.getItem('speechURLs');
    if (saved) urls = JSON.parse(saved);
  } catch(e) {}

  if (urls.length === 0) {
    // Collect URLs from all listing pages (same approach as before)
    const token = document.querySelector('meta[name="csrf-token"]')?.content
                || document.querySelector('input[name="_token"]')?.value
                || '';

    console.log('Collecting speech URLs from listing pages...');
    const base = 'https://www.president.gov.ua/news/speeches?date-from=05-11-2017&date-to=01-01-2026'
               + (token ? '&_token=' + token : '');

    for (let page = 1; page <= 250; page++) {
      const url = page === 1 ? base : base + '&page=' + page;
      try {
        const resp = await fetch(url, { credentials: 'include' });
        if (!resp.ok) { console.log(`Page ${page}: HTTP ${resp.status}, stopping`); break; }
        const html = await resp.text();
        const doc = new DOMParser().parseFromString(html, 'text/html');
        const links = doc.querySelectorAll('a[href*="/news/"]');
        let count = 0;
        links.forEach(a => {
          const href = a.href || a.getAttribute('href');
          if (href && href.includes('/news/') && !href.includes('/speeches')
              && !href.includes('/all') && !href.includes('page=')
              && href.length > 50) {
            const full = href.startsWith('http') ? href : 'https://www.president.gov.ua' + href;
            if (!urls.includes(full)) { urls.push(full); count++; }
          }
        });
        if (count === 0 && page > 1) { console.log(`Page ${page}: no new links, stopping`); break; }
        console.log(`Page ${page}: +${count} URLs (total: ${urls.length})`);
        await new Promise(r => setTimeout(r, 300));
      } catch(e) {
        console.log(`Page ${page} error: ${e.message}`);
        break;
      }
    }
    localStorage.setItem('speechURLs', JSON.stringify(urls));
    console.log(`Collected ${urls.length} total URLs`);
  } else {
    console.log(`Loaded ${urls.length} URLs from cache`);
  }

  // Step 2: Fetch each article page
  const CONCURRENCY = 5;
  const BATCH_DELAY = 300;

  let fetched = {};
  try {
    const saved = localStorage.getItem('fetchedArticles');
    if (saved) fetched = JSON.parse(saved);
  } catch(e) {}

  const alreadyDone = Object.keys(fetched).length;
  const remaining = urls.filter(u => !fetched[u]);
  console.log(`\nFetching articles: ${remaining.length} remaining, ${alreadyDone} cached`);

  let completed = alreadyDone;
  const total = urls.length;
  const t0 = Date.now();

  for (let i = 0; i < remaining.length; i += CONCURRENCY) {
    const batch = remaining.slice(i, i + CONCURRENCY);
    const results = await Promise.allSettled(batch.map(async url => {
      await new Promise(r => setTimeout(r, Math.random() * BATCH_DELAY));
      const resp = await fetch(url, { credentials: 'include' });
      if (!resp.ok) return { url, error: true, status: resp.status };
      const html = await resp.text();
      const doc = new DOMParser().parseFromString(html, 'text/html');

      let title = '';
      for (const s of ['h1', '.article_header h2', '.headline']) {
        const el = doc.querySelector(s);
        if (el) { title = el.textContent.trim(); break; }
      }

      let date = '';
      // Look for date inside article content area first, then fall back
      const articleArea = doc.querySelector('.article_content, .news_content, article, main, #content') || doc;
      for (const s of ['.article_date time', '.news_date time', '.date time',
                        '.article_date', '.news_date', '.created',
                        'time[datetime]']) {
        const el = articleArea.querySelector(s) || doc.querySelector(s);
        if (el) {
          const dt = el.getAttribute('datetime');
          if (dt && !dt.includes('2026')) { date = dt; break; }
          const txt = el.textContent.trim();
          if (txt && !txt.includes('2026')) { date = txt; break; }
        }
      }
      // Fallback: extract date from body text (first Ukrainian date found)
      if (!date || date.includes('2026')) {
        const bodyText = (body || '').substring(0, 500);
        const dateMatch = bodyText.match(/(\d{1,2})\s+(січня|лютого|березня|квітня|травня|червня|липня|серпня|вересня|жовтня|листопада|грудня)\s+(\d{4})/);
        if (dateMatch) date = dateMatch[0];
      }

      let body = '';
      for (const s of ['.article_content', '.field-name-body', '.text',
                        '.news_content', '.entry-content', 'article .content']) {
        const el = doc.querySelector(s);
        if (el) { body = el.textContent.trim(); break; }
      }
      if (!body) {
        const m = doc.querySelector('main') || doc.querySelector('article') || doc.querySelector('#content');
        if (m) body = m.textContent.trim();
      }
      body = body.replace(/\t/g, ' ').replace(/ {2,}/g, ' ').replace(/\n{3,}/g, '\n\n').trim();

      return { url, title, date, body_text: body, error: false };
    }));

    for (let j = 0; j < results.length; j++) {
      const url = batch[j];
      fetched[url] = results[j].status === 'fulfilled' ? results[j].value
                   : { url, error: true };
      completed++;
    }

    const elapsed = (Date.now() - t0) / 1000;
    const rate = (completed - alreadyDone) / elapsed;
    const eta = rate > 0 ? Math.round((total - completed) / rate) : '?';
    if (completed % 25 < CONCURRENCY) {
      console.log(`[${completed}/${total}] ${Math.round(completed/total*100)}% — ETA: ${eta}s`);
    }

    // Save checkpoint every 50
    if (completed % 50 < CONCURRENCY || i + CONCURRENCY >= remaining.length) {
      try { localStorage.setItem('fetchedArticles', JSON.stringify(fetched)); } catch(e) {}
    }

    if (i + CONCURRENCY < remaining.length) await new Promise(r => setTimeout(r, BATCH_DELAY));
  }

  // Step 3: Export
  const articles = urls.map(u => fetched[u]).filter(Boolean);
  const good = articles.filter(a => !a.error && a.body_text && a.body_text.length > 50);
  console.log(`\nDone! ${good.length}/${total} articles with content`);

  const clean = good.map(a => ({
    url: a.url, title: a.title, date: a.date,
    body_text: a.body_text, word_count: a.body_text.split(/\s+/).length
  }));

  const blob = new Blob([JSON.stringify(clean, null, 2)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'speech_articles_clean.json';
  document.body.appendChild(a); a.click(); document.body.removeChild(a);
  URL.revokeObjectURL(a.href);

  console.log('Downloaded: speech_articles_clean.json');
  console.log('Place this file in your project data/ folder, then run 02_import_and_analyse.R');
})();
