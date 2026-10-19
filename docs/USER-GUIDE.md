# Catecho user guide

## First launch

Copy Catecho to Applications and open it. A three-step tuning guide appears inside the radio:

1. Switch on the topics you care about. Expand **Research subjects** to combine areas such as AI and physics. Keep at least one station enabled.
2. Choose System default, English, 简体中文, or 繁體中文. The setup text previews your choice immediately.
3. Optionally enable **Start at login**, then turn the dial labelled **Start reading**. Your choices are saved and every selected station begins fetching.

**Back** revisits a step; **Use defaults** starts reading with the existing defaults. Topic and language drafts are committed only on completion. The login switch acts immediately through macOS, and skipping does not undo a deliberate login change. An interrupted first launch returns to setup next time. Existing users keep their settings and normal tucked startup after upgrading.

Use the radio's menu-bar icon → **Set up your radio…** to revisit the guide. Finish or leave any open back-panel draft first. During setup, clicking outside does not dismiss it, and Escape goes back one step. Both Classic and Flat retain the same footprint and controls.

**Start at login** also appears on the back. It uses Apple's login-item service and requires the app directly inside `/Applications` or your home `Applications` folder. If macOS needs approval, Catecho displays that state and provides **Open Login Items**. A registration failure remains visible without blocking reading. No login registration is made simply by opening or finishing setup.

## Controls

- With Codex monitoring and **Token bot while tucked** enabled, the original slim antenna keeps its 54 × 126-point footprint, with a plain vented cream base and small white grips. Tokens appear only after the base expands into the selected chat/time dashboard. Click the belly or either white glove to extend/retract the dashboard; pull a glove outward to open or inward to close. Escape retracts the open dashboard. The chrome antenna opens the full Codex radio. Drag the lower rim beneath the screen to move it. The window grows toward the screen interior, then releases the extra space when retracted. Classic and Flat share the same movement; Reduce Motion switches directly between poses.
- Drag the antenna’s cream base to reposition it. Pull the tip upward by 34 points and release to open; clicking the tip also opens it. A partial pull springs back.
- Drag the opened radio by its title area. Position and display are remembered; opening and tucking keep the radio within the display’s usable area.
- The radio floats above ordinary application windows and **Keep open while I work** defaults on. Click the down chevron or press Escape to tuck it away. If you turn keep-open off, clicking another app also tucks it.
- Each click on the large channel dial immediately cycles your enabled preset and custom stations, then wraps. Previous/next buttons move through the finite edition.
- Click the story title or **Read source** to open the original article in your browser.
- Click the refresh arrow to fetch current information. Waves pulse and the dial turns while fetching. Existing content stays readable during a refresh.
- Click the round settings cap to turn the radio over. The cap faces straight out from the front cover, with concentric bevels, a fine contact shadow and clear space above the e-paper screen. The front and back share the same ivory palette.
- Settings form one continuous scrollable compartment, with no tab bar or large Back button. Station/source switches use custom ribbed sliders. Appearance, edge, quantity, refresh period, language and GitHub period use mechanical detent rails instead of stock checkboxes, segmented controls or popup menus. Options remain labelled and expose selected/on-off states.
- Hold either ribbed side grip and drag horizontally to turn the radio with your mouse. A short drag returns to the starting side; a pull of 80 points or more finishes the turn when released. Clicking a grip also turns it. Classic turns as a slim 28-point-deep casing, with a continuous matte champagne-aluminium side finish and restrained rounded-edge lighting inspired by the iPhone 7. The central white reflection and detached lower shadow have been removed; the covers use a small contact shadow during the turn and keep their original depth when facing you. The old center seam and raised side rails are removed; the ivory front and back stay in place. Flat keeps a thinner 6-point casing. Both share a perspective camera; the radio recedes slightly while turning to stay inside its existing window. The title strip remains the window drag handle, and scrolling/text editing inside the back panel remain separate.
- Click **Flip to front / 翻回正面**, or drag a side grip from the back, to validate/save station and source edits and return to the front. Invalid drafts spring back with an explanation and keep their text. Escape returns without saving those draft edits. Appearance, language and placement controls still apply immediately.
- The rear lettering uses shallow, dark taupe relief with restrained highlights. The battery door retains its hinges and thumb grip. Click **OPEN** to swing it outward through 125°, revealing its ribbed underside and a reception panel: latest successful station response, approximate next automatic check, active/failed/waiting station count, and **Refresh all**. The small down-chevron closes the lid. Refresh all uses saved station choices, leaves your reading position intact, and coalesces in-flight requests. This is update activity, not a battery charge monitor.
- **Classic / Flat** keep the same layout and information. The expanded radio and settings both fit the same 374 × 416-point footprint.
- The menu-bar **Move to this display** command selects the display where the mouse is positioned.
- macOS **Reduce Motion** replaces reception movement with a static indicator, switches front/back without spatial rotation, skips the cap-turn animation, and changes the battery cover instantly to its open or closed position. There is no sound, automatic story advance, flashing, or minimum artificial loading delay.

## Languages and article translation

Settings → Language offers **System default**, **English**, **简体中文** and **繁體中文**. It updates interface labels, settings, menus, accessibility labels and dates immediately. Your choice is remembered.

On macOS 15 or later, **Translate articles on this Mac** uses Apple’s Translation framework for the currently displayed headline and excerpt. Translations are labelled as machine translation; **Original / 原文** switches back to the exact feed text. Repository names, star counts and links remain unchanged. Sports text and scores stay in their source form to avoid changing numeric data; score-status labels follow the interface language. This translates feed snippets, not entire linked pages or a newly written summary.

If a supported language model is not installed, **Download languages / 下载语言 / 下載語言** starts Apple’s system setup. Downloads need internet and additional disk space managed by macOS. Once installed, translation runs on the Mac; Catecho uses no external translation service or paid API. If a language pair is unsupported, a download is cancelled or translation fails, the original remains readable. macOS 14 still supports all three interface languages and shows original article text.

Completed translations are cached separately in `~/Library/Application Support/Little Radio/Translations`, keyed by source content and target script. Changing the original text or choosing the other Chinese script cannot reuse the wrong translation. Source editions are never overwritten.

## Information and updates

The initial dial includes AI News, GitHub and Research. Other presets are ready to enable in the service compartment:

| Station | Sources / behavior |
|---|---|
| AI News | OpenAI, Anthropic / Claude, DeepMind, Hugging Face, MIT AI and BAIR selected initially. Microsoft Research, NVIDIA and Ars Technica are additional choices. Broad feeds are filtered for AI terms. Anthropic uses its official newsroom HTML; other AI sources use RSS/Atom. Source labels distinguish company announcements, academic institutions, professional communities and reporting. |
| GitHub | GitHub Trending page order, with recent stars **today / this week / this month**. This is not a universal ranking of all repositories or a lifetime-star ranking. Missing recent counts are not invented; a warning is shown. |
| Research | Combined arXiv subject feeds; AI + physics initially selected. Eleven topics include quantum physics, astronomy, relativity, particle physics, condensed matter, mathematics, neuroscience, machine learning and robotics. Selected categories are interleaved when present. Items are clearly labelled **Preprint**. |
| Games | Game Developer + Eurogamer |
| NBA | ESPN public scoreboard for yesterday, today and tomorrow in US Eastern. Live games first, then today/upcoming/recent results. Scheduled tip-offs use the Mac’s local time. Shows available scores, clock and team statistics; the original source has the full box score. |
| Education | MIT Education + EdSurge |
| Psychology | Association for Psychological Science |
| Philosophy | Daily Nous, covering the professional philosophy community |
| Science | ScienceDaily |
| Technology | Ars Technica |

Add up to 12 named custom stations, each combining up to eight sources. Paste a normal website link (even a bare domain). Catecho first looks for a verified RSS/Atom feed, then falls back to reading public article cards and structured article metadata from the page. The radio-wave indicator stays active during discovery. The first usable result is selected automatically; additional feeds use the custom ribbed switches. A suggested station name remains editable. A fallback is explicitly labelled **Read from website** with an explanation that dates and summaries depend on the publisher. Direct feed links still work. Keywords are optional: blank includes all entries; comma-separated keywords match any term in a headline or excerpt. A topic name alone cannot discover reliable sources automatically: supply website links for that area. The old single-feed preference is retained if configured.

For a website source, each refresh reads that saved page again. The reader accepts article JSON-LD, semantic article cards and linked headings on article paths, resolves same-site HTTPS article links, removes tracking parameters, and skips navigation, hidden content and unsafe links. It also reuses the existing Anthropic newsroom adapter for compact list rows. It does not crawl the linked articles. If all articles have publication dates, they are sorted newest first; otherwise it retains the page order and labels it **Website · Page order**. Missing dates and excerpts stay missing. Source excerpts are not AI-generated summaries. Some sites need JavaScript, a login, or a site-specific adapter; these show an actionable message and keep the previous successful cached edition. There is no universal website scraper or guaranteed detection of every new post.

Stories are publisher excerpts with links, not AI-written synthesis. Source groups are interleaved to avoid one high-volume publisher dominating the edition. Cached editions remain readable offline. A failed refresh preserves the last successful edition, with a visible status and timestamp.

Enabled stations fetch at launch and on the selected automatic interval (hourly by default). Opening a stale station also refreshes it with a one-minute retry cooldown; waking refreshes the selected stale station. When automatic updates are on, a visible NBA station refreshes approximately once per minute; tucked or hidden NBA uses the ordinary interval. Manual disables periodic updates, including the minute NBA refresh. The Mac must be awake and the app running; this does not schedule a wake from sleep.

Anthropic newsroom HTML, GitHub Trending HTML and ESPN’s public website JSON are undocumented interfaces and may change or rate-limit. ESPN is not a guaranteed real-time sports data service. The app shows when it fetched the scoreboard, keeps a cached fallback, and reports partial/malformed responses. It does not bypass blocked NBA CDN access. All current feeds work without an account, key or paid backend.

The reception panel reports the most recent successful **station response**, not that every source is current. Failed or partially failed stations are counted separately. Next check is derived from the same per-station deadline used by the one-minute scheduler (with up to five seconds of timer tolerance), excludes requests already running, and shows Manual when automatic checks are disabled. It does not schedule an exact wake-up time.

Feed discovery follows the [RSS autodiscovery convention](https://www.rssboard.org/rss-autodiscovery) and accepts Atom links as well. It runs when custom-source links change, with a 0.6-second debounce, cancellation and stale-result guards. It verifies at most six advertised candidates per webpage concurrently, then up to five common paths if needed. Each discovery/page request has an 8-second request / 12-second resource timeout; parsing rejects pages over 4 MB. If no feed validates, the downloaded original HTML is checked for readable articles before offering it as a webpage source. Feed URLs and webpage URLs are stored separately with backward-compatible decoding, so routine refreshes use the selected method directly. Saved sources remain editable offline. Neither method executes website JavaScript.

Fetch pipeline: native `URLSession` → RSS/Atom, newsroom/Trending HTML or scoreboard JSON parser → optional topic/keyword filters → date ordering (or labelled webpage order), source interleaving and URL deduplication → up to 30 cached stories per station → selected 3/5/8 stories on the radio. Feed/API downloads use an ephemeral URLSession, 18-second request / 25-second resource timeouts, a 12 MB response limit, and HTTPS redirect checks. Different stations can fetch concurrently; selected sources within a station are fetched in sequence. Individual source failures are reported while successful sources remain usable; total failure retains the previous cached edition. JSON caches are written atomically and keyed by station configuration. Anthropic headlines without a publisher excerpt remain headline-only; no summary is fabricated.

Local cache: `~/Library/Application Support/Little Radio/Cache`.
Preferences use the `local.littleradio.desktop` UserDefaults domain, including the saved antenna position and display. Login startup is opt-in through **Start at login** in setup or back settings. After setup, launch begins tucked and fetches the enabled stations. Quit from the menu bar when finished.
