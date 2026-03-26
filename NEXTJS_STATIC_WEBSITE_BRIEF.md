# ngpocket -> Static Next.js Website Brief

This document is a full handoff for building a static website that represents the real ngpocket app experience.

Use this as a product + UX source of truth for a UI/UX + Next.js developer.

## 1. Goal

Create a static, high-quality Next.js marketing/product website that communicates the same value and interaction feel of the app:

- swipe-first reading workflow
- RSS + shared-link ingestion
- clean reader mode with highlights and tags
- saved library management
- offline-first reliability and background RSS sync alerts

The website should feel intentional, editorial, and modern, while preserving ngpocket's warm vintage personality.

## 2. Source-of-Truth Product Features (Do Not Miss)

### 2.1 Core Product Positioning

- Premium minimalist read-later + RSS inbox.
- Swipe-first article triage.
- Local-first persistence and fast daily reading.

### 2.2 Navigation Model

Primary tabs/features to represent in website IA:

- `Library`
- `Swipe Reader`
- `Read` (inbox)
- `Settings`

Important UX detail:

- app has unread badge count in navigation
- navigation has tactile animated selector and icon state transitions

### 2.3 Swipe Reader Experience

Must showcase:

- Tinder-style card stack with large article card visuals.
- Article card includes image, title, compact description, source, reading time.
- Gesture semantics (actual code behavior):
  - swipe left: mark as read
  - swipe right: save article and attempt full scrape/parse
  - swipe up: next article
  - swipe down: disabled in current implementation
- Tap card opens Reader view.
- Action bar buttons mirror gestures: `Read`, `Save`, `Next`.
- Overlay feedback while dragging and visual affordances for action direction.
- Image precaching behavior for upcoming cards to keep interaction smooth.
- Empty state CTA when queue is empty: prompt to add RSS feed.

### 2.4 Read Inbox

Must showcase:

- Chronological list of all queued/readable articles.
- Row metadata: source, estimated reading time, date, unread indicator.
- One-tap bookmark toggle from list.
- Feeds icon entrypoint to RSS source management.

### 2.5 Library (Saved Articles)

Must showcase:

- Saved-only collection view.
- Filter control: `All`, `Unread`, `Read`.
- Open saved article in Reader.
- Removal flows:
  - mark unread via swipe action
  - remove from library but keep highlights
  - delete article with highlights
- Clear empty state guidance (save via right-swipe in Swipe Reader).

### 2.6 RSS Management

Must showcase:

- Add RSS source by URL.
- Feed list with source metadata and last updated timestamp.
- Pull-to-refresh all feeds.
- Per-feed actions: refresh, remove.
- Feed detail page with article previews.
- Download/import feed article into reading queue.

### 2.7 Reader Mode

Must showcase:

- Immersive long-form reading layout with constrained line length.
- Header with reading progress indicator.
- Hero media + title + author/source/reading-time metadata.
- Parsed content rendered as semantic blocks:
  - heading
  - quote
  - list item
  - body paragraph
- Link handling:
  - markdown links and raw URLs become tappable links
  - open original in browser action
- Re-parse action for current article.

### 2.8 Highlights + Tags

Must showcase:

- Select text and save highlight snippets.
- Highlights count surfaced in settings.
- Dedicated Highlights screen listing saved snippets by article + date.
- Delete highlight capability.
- Per-article tags:
  - add custom tags
  - remove tags
  - suggestions from previously used tags

### 2.9 Reader Personalization

Must showcase:

- Reader font scale control.
- Reader font family options:
  - Source Serif
  - DM Sans
  - Playfair
- Text alignment options:
  - left
  - justified

### 2.10 Notifications + Background Sync

Must showcase:

- Morning RSS sync notifications setting.
- Unread threshold slider (3 to 10) that controls notification trigger.
- Background periodic feed sync concept (daily morning cadence).
- Test notification behavior.
- Notification can deep-link into Reader.

### 2.11 Shared Link Ingestion

Must showcase:

- User can share a URL from other apps/browser into ngpocket.
- URL is parsed and added to reading flow.
- Supports initial app launch with a shared URL.

### 2.12 Data and Reliability Characteristics

Must showcase:

- Offline-first local storage.
- Local article/feed/highlight/tag persistence.
- Graceful fallback behavior when remote parser unavailable.
- Fast interactions despite network variability.

### 2.13 Visual Language

Must showcase:

- Warm vintage palette direction:
  - clay `#D97D55`
  - beige `#F4E9D7`
  - sage `#B8C4A9`
  - mist blue `#6FA4AF`
  - background `#F8F0E3`
  - surface `#FFF8EE`
- Typography blend:
  - UI text: DM Sans
  - reading text: Source Serif / Playfair accents

### 2.14 Motion and Feedback

Must showcase:

- Card-stack movement and directional intent cues.
- Subtle button press/scale affordances.
- Enter transitions for action controls.
- Skeleton loading placeholders.
- Haptics exist in app (web should mimic with visual/audio-like cues where relevant).

## 3. Website Strategy (Static Next.js)

This is a static product site, not the full app runtime. Replicate *experience narrative*, not native runtime behavior.

### 3.1 Recommended Sitemap

- `/` Home: hero, value proposition, quick feature overview, CTA
- `/experience` Swipe-first narrative with interaction demos
- `/features` Full feature matrix
- `/reader` Reader mode, highlights, tags, typography controls
- `/rss` RSS ingestion and source management flows
- `/library` Saved workflow and filtering/removal logic
- `/settings` Notification + parser settings narrative
- `/architecture` Offline-first and reliability explanation

All pages static-rendered (`next export` compatible if needed).

### 3.2 UX Parity Rules for Web

- Keep gesture semantics visible even on desktop:
  - drag/swipe demo cards on desktop and mobile
  - fallback action buttons always visible
- Keep same terminology as app: `Read`, `Save`, `Next`, `Highlights`, `Feeds`.
- Provide interaction demos as controlled components (no backend).
- Represent state transitions (empty, loading, populated, error) in visuals.

### 3.3 What to Simulate vs What to State

Simulate in website:

- card swiping demo
- reader layout + progress bar
- typography controls preview
- tag chips and highlight selection mock interaction
- notification threshold UI

State textually (cannot truly run in static web):

- native share intent interception
- mobile haptics
- OS background schedulers and local notifications behavior

## 4. Design and Build Requirements for Next.js Dev

### 4.1 Technical

- Next.js App Router.
- TypeScript.
- Static content-first architecture.
- Components split by domain (`SwipeDemo`, `ReaderDemo`, `RssFlow`, etc.).
- SEO-ready metadata on all pages.
- Accessible semantics and keyboard support for all controls.
- Fully responsive: mobile first, then desktop enhancements.

### 4.2 UI Direction

- Non-generic editorial product site.
- Use the warm vintage palette and purposeful typography.
- Use layered backgrounds/gradients and subtle texture.
- Motion should be meaningful and not noisy.

### 4.3 Content Structure

Each major feature section should include:

- Problem statement
- ngpocket behavior
- visual demo panel
- short technical trust note (offline-first, parsing fallback, etc.)

### 4.4 Acceptance Criteria

- Every feature from section 2 appears at least once in page content and visuals.
- Swipe flow and Reader flow are both deeply explained, not surface-level.
- Website clearly communicates what is interactive demo vs native app capability.
- Mobile and desktop both feel intentional.
- Lighthouse-ready baseline (performance/accessibility/SEO best practices).

## 5. Essential Prompts for UI/UX + Next.js Developer

Use these prompts as direct work tickets or AI prompts.

### Prompt 1: Master Build Prompt

```text
You are a senior UI/UX + Next.js engineer. Build a static product website for ngpocket, a premium swipe-first read-later + RSS app.

Tech constraints:
- Next.js (App Router) + TypeScript
- Static-site friendly architecture
- No backend requirement
- Mobile-first responsive design

Design direction:
- Warm vintage aesthetic (clay/beige/sage/mist blue)
- Editorial typography (DM Sans for UI, Source Serif/Playfair for reading moments)
- Purposeful, non-generic layout and motion

Mandatory features to showcase:
1) Swipe Reader: left=mark read, right=save+scrape, up=next, down disabled in current build
2) Action buttons mirroring swipe actions: Read/Save/Next
3) Read Inbox list with unread marker, reading time, source/date, bookmark toggle
4) Library with filters (all/unread/read), mark unread, remove-only, remove+highlights
5) RSS source management: add feed URL, feed list, refresh all, per-feed refresh/remove
6) Feed article list and “download article” into queue
7) Reader mode: progress bar, hero image, semantic paragraph rendering, links, open original
8) Re-parse article action
9) Highlights: text selection concept, save/delete highlights, highlights list screen
10) Tags: add/remove tags, suggestion chips
11) Reader typography controls: font family, font scale, alignment
12) Notifications settings: morning sync toggle + unread threshold (3-10) + test notification concept
13) Shared URL ingestion concept from browser/apps
14) Offline-first local storage and parser fallback reliability messaging

Deliverables:
- complete page structure
- reusable components per feature domain
- polished motion for hero, cards, and transitions
- accessibility and keyboard support
- SEO metadata and share cards
- clean code with clear folder organization

Important:
- Clearly label what is “interactive website demo” vs “native app capability”
- Do not omit any feature from the mandatory list
```

### Prompt 2: Information Architecture + Wireframe Prompt

```text
Create an IA and low-to-mid fidelity wireframe plan for the ngpocket static website.

Output required:
1) sitemap with route purposes
2) section-by-section outline for each page
3) component inventory
4) mobile and desktop layout differences
5) content hierarchy and CTA placement

Pages required:
/, /experience, /features, /reader, /rss, /library, /settings, /architecture

Ensure every app capability is represented, including highlights/tags, notifications threshold logic, shared URL ingestion, and offline-first architecture.
```

### Prompt 3: Visual System Prompt

```text
Design a visual system for ngpocket website that captures a premium warm editorial reading vibe.

Requirements:
- Define CSS variables/tokens for color, spacing, radii, shadows, typography, and motion
- Palette must include clay #D97D55, beige #F4E9D7, sage #B8C4A9, mist blue #6FA4AF
- Typography pairing: DM Sans (UI), Source Serif or Playfair for reading accents
- Component states: default/hover/focus/active/disabled
- Accessibility contrast checks and focus-visible styles

Provide:
- token table
- component style guidelines
- examples of page background treatment and section rhythm
```

### Prompt 4: Swipe Demo Component Prompt

```text
Implement a reusable SwipeReaderDemo component in Next.js/React that simulates ngpocket's card triage behavior.

Functional requirements:
- draggable/swipeable cards (mouse + touch)
- directional action mapping:
  - left: Mark as Read
  - right: Save
  - up: Next
  - down: disabled
- visible directional overlays and action labels
- fallback action buttons: Read, Save, Next
- smooth transitions and card stack depth
- empty state card with “Add Feed” CTA

Non-functional:
- keyboard-accessible fallback controls
- responsive behavior and reduced-motion fallback
```

### Prompt 5: Reader Experience Prompt

```text
Build a ReaderExperience section that mirrors ngpocket reader behavior.

Must include:
- top progress indicator linked to scroll position
- hero image + title + metadata chips
- semantic paragraph rendering style variants: heading, quote, list item, body
- clickable inline links style (markdown and raw URL examples)
- typography controls demo (font family, alignment, size slider)
- highlight selection concept and highlight list preview
- tags UI with existing tags + suggestion chips

Include clear labels explaining this is a website simulation of app behavior.
```

### Prompt 6: RSS + Library Flows Prompt

```text
Create two sections with realistic product flows:

1) RSS flow
- add feed URL
- feed cards with refresh/remove actions
- pull-to-refresh conceptual UI
- feed article preview list with “download to queue” action

2) Library flow
- saved items list with filter chips: All/Unread/Read
- row actions for mark unread and remove options
- explanatory copy for retaining or deleting highlights on removal

Use believable sample data and include success/error/loading/empty states.
```

### Prompt 7: Settings + Notifications Prompt

```text
Build a Settings showcase section for ngpocket website.

Include:
- highlights counter and entry card
- reader font scale control
- parser endpoint configuration panel
- morning RSS sync notifications toggle
- unread threshold slider from 3 to 10
- “test notification” interaction narrative

Add contextual microcopy that explains background sync cadence and deep-link-to-reader behavior in native app.
```

### Prompt 8: QA and Completion Prompt

```text
Perform final QA pass on the ngpocket static Next.js website.

Checklist:
- all 14 mandatory feature categories are represented
- no mismatch in swipe direction mapping (down is disabled)
- all pages render correctly on mobile and desktop
- keyboard navigation and focus states are usable
- reduced-motion support works
- SEO metadata and social preview tags are present
- no broken links/assets
- clear distinction between demo behavior and native app-only capabilities

Output a final gap report and exact fixes.
```

## 6. Suggested Execution Order

1. Lock IA and feature-to-page mapping.
2. Build visual system tokens and layout primitives.
3. Implement homepage + feature overview.
4. Build Swipe demo and Reader demo components.
5. Add RSS, Library, and Settings deep-dive pages.
6. Add accessibility and SEO pass.
7. Run final feature coverage audit against section 2.

## 7. Notes for Accuracy

- Keep swipe behavior aligned with current implementation:
  - left/read
  - right/save
  - up/next
  - down disabled
- If referencing "previous article on swipe down", label it as legacy/roadmap, not current behavior.
- Keep copy truthful about static-site limitations.
