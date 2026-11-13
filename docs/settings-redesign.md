# Settings and app branding

Rebuilt the Settings page with separate Personalize, Stay connected, Ad-Free, and Account sections. Appearance and currency now have clearer rows, notification permission is presented as a status, and sync has its own status and action. Logout continues to use the existing unsynced-change confirmation and busy guard.

The shared `SplitwizeMark` now renders `assets/icon/app_icon.png` directly. This supplies the real app artwork to the drawer header and home app bar, as well as the existing sign-in and onboarding uses of that same widget.

## Previews

- [Original settings](settings-before.png)
- [Updated settings](settings-after.png)
- [Ad-Free and logout](settings-after-bottom.png)
- [Appearance picker](settings-after-appearance.png)
- [Dark theme](settings-after-dark.png)
- [Small phone with enlarged text](settings-after-large-text.png)
- [Home app bar](home-branding.png)
- [Drawer header](drawer-branding.png)

## Verification

43 tests passed: six new focused settings/branding tests, 12 existing profile/design-system/paywall tests, and 25 responsive settings/home/drawer checks. Covered currency saving, permission loading and retry, subscription entry, sync actions and duplicate-tap protection, appearance selection, and the actual asset in both requested headers. Static analysis found no issues.

Visual captures use the real Flutter widgets, app themes, fonts, and local sample data. Production purchases, Firebase writes, and OS screen readers were not exercised.
