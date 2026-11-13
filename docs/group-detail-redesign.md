# Group details redesign

The screen opened from **Groups → a group** has been rebuilt around a spending overview, personal balances, and three focused tabs.

## Review

The original screen combined settlement suggestions, expense history, members, pending invitations, and currency settings in one long list. There was no spending or personal balance summary. Settlement suggestions pushed expenses down the page, and membership actions became hard to reach as expense history grew. The Add expense button scrolled away.

Reviewed the screen code and its navigation, providers, legacy shares, payment ledger, invitation checks, currency updates, and settlement permissions. Captured the original screen with local sample data: [overview](group-detail-before.png) and [members/settings](group-detail-before-members.png).

## Updated experience

| Step | Result |
| --- | --- |
| Open a group | Group name, membership, spending, and personal net balance appear first. Different currencies remain separate. |
| Review expenses | A dated history offers All, Unsettled, and Settled filters. The selected filter survives tab changes. |
| Review balances | Payments clearly show the amount, sender, and receiver. Eligible users confirm a settlement before it is recorded. |
| Review members | Members and pending invitations have their own tab, with an Invite friends action. |
| Change currency | Available beside the group overview and in settings; existing expenses keep their currency. |
| Add an expense | A persistent bottom action opens the form with the group selected. |

Preserved the invitation acceptance gate, payer/receiver settlement permissions across all affected bills, and live provider updates. New balance calculations use the actual creditor and debtor for payment-ledger expenses, including partially settled amounts. Submission locks prevent repeated settlement and invitation taps.

## Previews

- [Expenses and overview](group-detail-after.png)
- [Balances](group-detail-after-balances.png)
- [Members and invitations](group-detail-after-members.png)
- [Settings](group-detail-after-settings.png)
- [Dark theme](group-detail-after-dark.png)
- [Small screen with enlarged text](group-detail-after-small-balances.png)

## Verification limits

All 41 relevant tests passed: 11 focused group-screen tests, 22 invitation-flow tests, and 8 existing GroupDetail responsive checks. The responsive checks include phones, landscape, tablet, and text scaling up to 2×. Static analysis of the changed screen, its sections, tests, and capture harness reported no issues. Captured and inspected six updated screen states; pinned tabs no longer cover section headings after scrolling or switching tabs.

Screenshots render the actual Flutter widgets with in-memory sample data, the app's themes, and real fonts. They are not captures from a signed-in production account. Widget tests cover navigation, filtering, financial summaries, access restrictions, settlement confirmation, and responsive layouts. Production Firebase writes and platform screen readers were not exercised.
