# Financial news, US stocks and Tibo resets

Add three selectable stations using Catecho’s existing case, e-paper screen, source links, refresh settings, offline cache and Chinese translations. Keep existing station selections on upgrade; enable the requested stations and watchlist in this Mac’s preferences separately.

Financial News combines CNBC Finance and Federal Reserve monetary-policy releases. US Stocks shows an editable list of up to 20 US ticker symbols, followed by CNBC earnings/market headlines. Every selected symbol remains reachable regardless of the story-count preference. Quote cards show USD prices, provider-supplied regular-session percentage change when present, quote timestamp and provider attribution. Unknown symbols show unavailable; failed refreshes retain explicitly labelled cached quotes. Yahoo’s public chart interface is unofficial and can change or rate-limit; no guaranteed real-time or extended-hours claim is made.

Tibo Resets reads the documented, keyless Codex Resets API. Only regular/banked reset entries attributed to @thsottiaux with matching original X links are accepted. The station identifies the community intermediary and links to it. It reports announcements, never claims the user’s own account has refilled and never acts on that account.

An optional rear-panel switch enables native macOS banners for new reset posts. The first successful response sets a quiet baseline; later unseen posts newer than that baseline and within 24 hours may alert once. Save the ledger locally across restart. Ignore future/invalid records and historical backfills. Manual refresh mode pauses automatic polling. While automatic updates run, alerts and a visible stock station refresh about every five minutes; other background stations retain the chosen interval. Notification denial must be visible in settings without preventing reading the station.

No Cloudflare, paid service, API key or new third-party dependency. User watchlist and local alert state remain in preferences, not in repository examples. Use the current branch and existing build/install workflow.
