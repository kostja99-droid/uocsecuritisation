// ──────────────────────────────────────────────────────────
// fetch_dates_only.js — Fetch ONLY the publication date for each article
//
// Run in browser console on president.gov.ua AFTER you already
// have speech_articles_clean.json. This fixes the date issue
// (the JS grabbed the page header date instead of the article date).
//
// Takes ~2-3 minutes for 1780 URLs. Downloads date_mapping.json.
// Then in R: import_articles("speech_articles_clean.json") will
// automatically use date_mapping.json if it's in the same folder.
//
// TO RESET: localStorage.removeItem('fetchedDates');
// ──────────────────────────────────────────────────────────

(async () => {
  // Load URLs from localStorage (saved by the previous script)
  let urls = [];
  try {
    const saved = localStorage.getItem('speechURLs');
    if (saved) urls = JSON.parse(saved);
  } catch(e) {}

  // If not in localStorage, rebuild from the fetched articles
  if (urls.length === 0) {
    try {
      const saved = localStorage.getItem('fetchedArticles');
      if (saved) urls = Object.keys(JSON.parse(saved));
    } catch(e) {}
  }

  if (urls.length === 0) {
    console.error('No URLs found. Run fetch_articles_quick.js first, or paste URLs.');
    return;
  }

  console.log(`Fetching dates for ${urls.length} articles...`);

  const CONCURRENCY = 10;  // faster since we only need a tiny piece
  const BATCH_DELAY = 200;

  let dates = {};
  try {
    const saved = localStorage.getItem('fetchedDates');
    if (saved) dates = JSON.parse(saved);
  } catch(e) {}

  const alreadyDone = Object.keys(dates).length;
  const remaining = urls.filter(u => !dates[u]);
  console.log(`${remaining.length} remaining, ${alreadyDone} cached`);

  let completed = alreadyDone;
  const total = urls.length;
  const t0 = Date.now();

  for (let i = 0; i < remaining.length; i += CONCURRENCY) {
    const batch = remaining.slice(i, i + CONCURRENCY);
    const results = await Promise.allSettled(batch.map(async url => {
      await new Promise(r => setTimeout(r, Math.random() * BATCH_DELAY));
      const resp = await fetch(url, { credentials: 'include' });
      if (!resp.ok) return { url, date: '', error: true };
      const html = await resp.text();
      const doc = new DOMParser().parseFromString(html, 'text/html');

      // The LAST p.date element is the article date
      // (earlier ones are sidebar/header showing today's date)
      const dateEls = doc.querySelectorAll('p.date');
      let date = '';
      if (dateEls.length > 0) {
        const lastDateEl = dateEls[dateEls.length - 1];
        date = lastDateEl.textContent.trim();
      }

      // Fallback: try og:updated_time meta tag
      if (!date) {
        const ogTime = doc.querySelector('meta[property="og:updated_time"]');
        if (ogTime && ogTime.content) {
          // Unix timestamp in seconds
          const ts = parseInt(ogTime.content);
          if (!isNaN(ts) && ts > 1000000000) {
            const d = new Date(ts * 1000);
            date = d.toISOString().substring(0, 10);
          }
        }
      }

      return { url, date };
    }));

    for (let j = 0; j < results.length; j++) {
      const url = batch[j];
      if (results[j].status === 'fulfilled' && results[j].value) {
        dates[url] = results[j].value.date;
      } else {
        dates[url] = '';
      }
      completed++;
    }

    if (completed % 50 < CONCURRENCY) {
      const elapsed = (Date.now() - t0) / 1000;
      const rate = (completed - alreadyDone) / elapsed;
      const eta = rate > 0 ? Math.round((total - completed) / rate) : '?';
      console.log(`[${completed}/${total}] ${Math.round(completed/total*100)}% — ETA: ${eta}s`);
    }

    if (completed % 100 < CONCURRENCY) {
      try { localStorage.setItem('fetchedDates', JSON.stringify(dates)); } catch(e) {}
    }

    if (i + CONCURRENCY < remaining.length) {
      await new Promise(r => setTimeout(r, BATCH_DELAY));
    }
  }

  // Save final
  try { localStorage.setItem('fetchedDates', JSON.stringify(dates)); } catch(e) {}

  // Show sample
  const entries = Object.entries(dates);
  const withDate = entries.filter(([u, d]) => d && d.length > 5);
  console.log(`\nDone! ${withDate.length}/${entries.length} articles have dates`);
  console.log('Sample dates:');
  withDate.slice(0, 5).forEach(([u, d]) => console.log(`  ${d}  ${u.substring(0, 70)}`));

  // Download
  const blob = new Blob([JSON.stringify(dates, null, 2)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'date_mapping.json';
  document.body.appendChild(a); a.click(); document.body.removeChild(a);
  URL.revokeObjectURL(a.href);

  console.log('\nDownloaded: date_mapping.json');
  console.log('Place it next to speech_articles_clean.json, then re-run import_articles() in R');
})();
