# Splitwize UI/UX — Figma design handoff

**Editable Figma file:** https://www.figma.com/design/ZaZQoAlKg4TKDvi1yXjesB

**Home screen:** https://www.figma.com/design/ZaZQoAlKg4TKDvi1yXjesB?node-id=3-2

The Figma file is a visual reference for the Flutter UI already implemented in
`lib/`. Its screens are editable illustrations containing sample names, amounts
and dates, **not production data** and **not a connected interactive prototype**.

## Screens and Flutter implementation

| Figma screen | Flutter source |
| --- | --- |
| 01 Home dashboard | `lib/screens/bills_tab.dart` |
| 02 Balances | `lib/screens/balances_tab.dart` |
| 03 Groups | `lib/screens/groups_tab.dart` |
| 04 Friends | `lib/screens/friends_tab.dart` |
| 05 Profile & settings | `lib/screens/profile_tab.dart` |
| 06 Add expense | `lib/screens/create_bill_screen.dart` |
| 07 Expense details | `lib/screens/bill_detail_screen.dart` |
| 08 Notifications | `lib/screens/notifications_screen.dart` |
| 09 Group details | `lib/screens/group_detail_screen.dart` |
| 10 Welcome / sign-in | `lib/screens/sign_in_screen.dart` |

Navigation: `lib/screens/home_shell.dart` and `lib/widgets/app_drawer.dart`.

Shared visual components: `lib/widgets/studio_ui.dart`.
Light and dark themes: `lib/theme.dart`.

## Design system

- Forest green **#153F37** — primary actions and active navigation
- Deep green **#0C302B** — primary emphasis
- Soft lime **#D8EC9B** — highlights and selected states
- Warm white **#FAF9F5** — canvas background
- Ink **#25312E** — primary content
- Muted green-gray **#66746D** — secondary content
- Fine border **#E2E7DE** — subtle dividers
- Semantic green **#247B52** — amounts owed to the user
- Semantic reddish brown **#A34B36** — amounts the user owes
- Muted coral **#E9A17F** — optional accent

Figma uses **Inter** to present the layout. Flutter uses the platform
typography supplied by Material 3; use the Flutter theme's text styles rather
than introducing hard-coded font dependencies without testing.

Use rounded white surfaces, restrained borders, logical reading order and
short labels. Keep touch targets accessible and preserve large-text layouts.

## Behavior and data boundaries

The Figma figures are examples. Actual totals must be computed from the
existing Riverpod providers. **Never add balances across different
currencies.** Always preserve sign-in, Firestore, SQLite/offline-first
synchronization, per-person splitting, settlement, groups and notifications.

The home screen offers an explicit expense filter, accessible through the
**See all / Open / Settled** popup menu. This keeps the initial home page
visually consistent with Figma without removing the functional filter options.

Review changes with `flutter analyze` and `flutter test`; verify Android
release builds through the repository's GitHub Actions workflow. Figma visual
approval does not replace functional and real-device verification.
