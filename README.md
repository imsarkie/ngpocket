# ngpocket

ngpocket is a premium, minimalist read-later + RSS inbox with a swipe-first reading experience.

The app combines:

- RSS subscriptions
- browser URL sharing into the app
- article parsing and cleanup
- offline local storage
- immersive swipe reading cards

## Features

- Swipe reader with Tinder-style card stack
	- Swipe up: next article
	- Swipe down: previous article
	- Swipe right: save article
	- Swipe left: mark read
	- Tap: open full reader mode
- Reader mode optimized for long sessions
	- serif typography
	- reading progress indicator
	- adjustable font size
	- clean clutter-free content
- RSS source management
	- add/remove feed URL
	- pull-to-refresh feeds
	- browse feed articles
	- download feed items into reading queue
- Library for saved articles
	- filter by all/unread/read
	- open/delete/toggle saved status
- Share from browser/apps (Android intent filters included)
	- shared URL is parsed and added to reading queue
- Offline-first local data via Drift (SQLite)

## Architecture

State management: `flutter_riverpod`

Persistence: `drift` + `sqlite3_flutter_libs`

Networking: `dio`

RSS parsing: `webfeed`

Share intake: `receive_sharing_intent`

UI and UX polish:

- `flutter_card_swiper`
- `google_fonts`
- `cached_network_image`
- `shimmer`

### Project layout

```
lib/
	core/
		database/
		models/
		network/
		services/
		theme/
		utils/
	features/
		feed/
		library/
		reader/
		rss/
		settings/
	widgets/
	main.dart
```

## Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Generate Drift code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

3. Run the app:

```bash
flutter run
```

## Parse backend (optional)

For cleaner extraction, configure a parser backend in Settings.

- Endpoint expected: `POST /parse`
- Input payload: `{"url": "https://..."}`
- Expected response fields:
	- `title`
	- `author`
	- `content_html`
	- `image`
	- `reading_time`

When no backend is configured or unavailable, ngpocket uses local fallback parsing.

## Notes

- Android share intent filters are configured in `android/app/src/main/AndroidManifest.xml`.
- iOS share extension flow can be added as a follow-up if required.
