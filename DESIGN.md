# Design

## Visual Theme

Dark-only, optimized for dim living rooms and home theater environments. Near-black backgrounds with cool undertone (0xFF08090A, not pure black). Content carries the visual weight; UI chrome recedes. Single accent color per platform context (white for focus, cyan for TV navigation, yellow/green/red for semantic states).

## Color Palette

### Backgrounds

| Token | Hex | Usage |
|---|---|---|
| backgroundDark | `#08090A` | Scaffold, app bar, screen base |
| backgroundCard | `#0D0D0D` | Cards, dialogs, elevated surfaces |
| backgroundElevated | `#1A1A1A` | Input fills, hover states, secondary surfaces |
| backgroundOverlay | `#08090A` @ 90% | Modal scrims |
| backgroundGlass | `#08090A` @ 60% | Blur-through overlays |

### Text

| Token | Hex | Opacity | Usage |
|---|---|---|---|
| textPrimary | `#EDEDED` | 100% | Headings, primary labels, active text |
| textSecondary | `#EDEDED` | 70% | Body text, descriptions, subtitles |
| textTertiary | `#EDEDED` | 50% | Hints, timestamps, metadata |
| textDisabled | `#EDEDED` | 30% | Disabled states, placeholders |

### Borders

| Token | Opacity | Usage |
|---|---|---|
| borderLight | 12% | Dividers, subtle separators, card borders (default) |
| borderMedium | 30% | Input borders (unfocused), outlined buttons |
| borderGradient | 50% | Gradient fade edges |

### Focus

| Token | Hex | Usage |
|---|---|---|
| focusRing | `#EDEDED` | Focus border (2dp width), active input border |
| focusGlow | `#000000` @ 20% | Focus shadow inner |
| focusShadow | `#000000` @ 25% | Focus shadow outer |

### Accents

| Token | Hex | Usage |
|---|---|---|
| accentYellow | `#FFCD3C` | IMDb ratings, kids badge, warnings |
| accentGreen | `#00D588` | Success states, add actions, connected status |
| accentRed | `#E53935` | Delete, disconnect, error, Trakt accent |
| accentCyan | `#00D4FF` | TV navigation highlight, TV primary actions |

### Semantic

| Token | Hex | Usage |
|---|---|---|
| successColor | `#00D588` | Same as accentGreen |
| errorColor | `#E74C3C` | Error states, form validation |
| warningColor | `#F39C12` | Warning states |

## Typography

System font stack (no custom fonts). Weight and size create hierarchy; color creates emphasis level.

| Scale | Size | Weight | Color | Usage |
|---|---|---|---|---|
| headlineLarge | 32 | bold (w700) | textPrimary | Screen titles (TV hero) |
| headlineMedium | 28 | semi-bold (w600) | textPrimary | Screen headers (settings, search) |
| titleLarge | 22 | semi-bold (w600) | textPrimary | Section headers, rail titles |
| titleMedium | 16 | medium (w500) | textPrimary | Card titles, setting labels |
| bodyLarge | 16 | regular | textPrimary | Primary body text |
| bodyMedium | 14 | regular | textSecondary | Descriptions, secondary text |
| bodySmall | 12 | regular | textTertiary | Metadata, timestamps, hints |

Letter spacing: -0.5 on display titles (28+), -0.2 on section headers (18), 0 elsewhere.

Monospace: `fontFamily: 'monospace'` for regex patterns, code-like content.

## Corner Radius

| Radius | Usage |
|---|---|
| 4dp | Skeleton loaders, small badges, inline tags |
| 8dp | Input fields, buttons, toast, skip-intro, PIN fields, filter chips, count badges |
| 12dp | Cards (theme default), watchlist cards, avatar items, code containers, settings navigation rows |
| 16dp | Dialogs, settings groups, person modal, addon dialogs |
| 28dp | Search input (pill shape) |

## Spacing

### Base unit: 4dp

Common gaps derived from the 4dp grid:

| Gap | Usage |
|---|---|
| 4dp | Tight text gaps (skeleton lines), avatar grid |
| 6dp | Header-to-input, small section breaks |
| 8dp | Icon-to-text, chip spacing, small vertical gaps |
| 12dp | Mobile grid spacing, section dividers, avatar grid, between input fields |
| 14dp | Input-to-content gap, search header bottom |
| 16dp | Horizontal screen padding, dialog padding, grid cross-axis spacing, vertical section padding |
| 20dp | Grid main-axis spacing (search results) |
| 24dp | TV grid spacing, section header top padding, dialog content padding |
| 100dp | Bottom scroll padding (nav bar clearance) |

### Platform-specific dimensions

| Token | Mobile | TV |
|---|---|---|
| Grid spacing | 12dp | 24dp |
| Card width | 140dp | 210dp |
| Card height | 210dp | 315dp |
| Rail height | - | 180dp |
| Screen padding | 16dp horizontal | 24dp horizontal |

## Elevation

No Material elevation (shadows). Layering through background color alone:

| Layer | Color | Context |
|---|---|---|
| Base | backgroundDark | Scaffold |
| Resting | backgroundCard | Cards, dialogs |
| Raised | backgroundElevated | Input fills, hover states |

## Components

### Cards
- Background: `backgroundCard`, no shadow
- Border: `borderLight` @ 0.24 alpha, 0.5dp width (default); `textPrimary` 2dp on focus
- Radius: 12dp
- Focus transition: `AnimatedContainer` 200ms

### Dialogs
- Background: `backgroundCard`
- Radius: 16dp
- Actions: `TextButton` (textSecondary) + `ElevatedButton` (focusRing bg / backgroundDark fg)

### Settings Groups
- Background: `backgroundCard`
- Radius: 16dp
- Border: `borderLight` @ 0.24 alpha, 0.5dp width
- Internal divider: `borderLight` @ 0.12 alpha, 0.5dp, 66dp left inset

### Search Input
- Background: `backgroundElevated`
- Radius: 28dp (pill shape)
- Border: `borderLight` @ 0.3 alpha (default), `textPrimary` @ 0.5 alpha (focused), 1dp
- Prefix icon: 22dp, 16dp left padding

### Toast / SnackBar
- Background: `backgroundCard`
- Radius: 8dp
- Floating behavior
- Icon + message row, 12dp gap

### Skeleton Loader
- Shimmer gradient: `backgroundCard` → `backgroundElevated` → `backgroundCard`
- Animation: 1500ms linear repeat
- Radius: 4dp (default), 8dp (card image area)

### TV Sidebar
- Width: 60dp
- Background: `Colors.black87`
- Selected: cyan accent (`#00D4FF`) left border 3dp + icon tint
- Unselected: `Colors.white70` icon

### TV Hero
- Height: 400dp
- Gradient overlay: transparent → black @ 70% → black
- Title: 48dp bold white
- Subtitle: 18dp white70
- Play button: cyan bg, black fg
- More Info: outlined, white70 border

### TV Dialog
- Background: `backgroundElevated` (`#1A1A1A`)
- Radius: 12dp
- Border: cyan accent 2dp
- Primary action: cyan bg, black text
- Secondary action: transparent, white70 border

## Motion

| Transition | Duration | Curve |
|---|---|---|
| Focus state change | 200ms | default |
| Opacity fade (skip intro) | 300ms | default |
| Shimmer animation | 1500ms | linear (repeat) |

No bounce, no elastic. Ease-out for enter transitions.

## Iconography

Material Icons (default Flutter set). Sizes:

| Context | Size |
|---|---|
| Navigation / sidebar | 24dp |
| Setting row icon | 22dp |
| Input prefix | 22dp |
| Inline (toast, badge) | 20dp |
| Small (delete, lock) | 14-18dp |

## Layout Patterns

### Screen structure
- `CustomScrollView` with `SliverToBoxAdapter` (sticky header) + content slivers
- Sticky header: SafeArea, backgroundDark, 16dp horizontal padding
- Bottom clearance: 100dp for navigation bar

### Grid
- Responsive column count: `(screenWidth / 160).floor().clamp(3, 8)`
- Card aspect ratio: 0.58 (watchlist), 0.65 (search)
- Cross-axis spacing: 12-16dp
- Main-axis spacing: 12-20dp

### Horizontal rails
- Title + `ListView.separated` (horizontal)
- Item spacing: 12dp (mobile), 12dp (TV default)
- Rail padding: 24dp horizontal, 16dp vertical (TV)
