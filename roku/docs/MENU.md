# Guest menu

The left rail, the Things to Do list, and the Quick Fixes list all come from one file. The channel packages a copy and replaces it when a newer copy fetches cleanly.

- Packaged file: `channel/data/menu.json`
- Same example: `docs/menu.json`
- Live file: `https://sunrivertownhome.com/data/menu.json`

## Shape

```json
{
  "version": 1,
  "items": [
    { "id": "home", "label": "Home", "type": "home" },
    { "id": "wifi", "label": "Wi-Fi", "type": "wifi" },
    {
      "id": "todo",
      "label": "Things to Do",
      "type": "things",
      "children": [
        {
          "id": "dining",
          "label": "Dining",
          "empty": "Nothing to show yet.",
          "sectionIds": ["dining"],
          "keywords": [],
          "seasons": []
        }
      ]
    },
    { "id": "rules", "label": "House Rules", "type": "rules" },
    {
      "id": "fixes",
      "label": "Quick Fixes",
      "type": "quickfixes",
      "source": "guide.troubleshooting"
    },
    { "id": "book", "label": "Book Direct", "type": "book" },
    { "id": "checkout", "label": "Checkout Instructions", "type": "checkout" }
  ]
}
```

`type` is one of `home`, `wifi`, `things`, `rules`, `quickfixes`, `book`, `checkout`. `things` is the only type with `children`. A child `id` is the screen the activity grid opens. `sectionIds`, `keywords`, and `seasons` decide which activities appear. `empty` is the sentence shown when that list has nothing.

`source` on Quick Fixes is `guide.troubleshooting`. The list titles and the scrolling steps are read from `guide.json` troubleshooting. The Wi-Fi how-to stays off that list. Do not paste the steps into `menu.json`.

The format did not change in build 32. Quick Fixes and Things to Do now open the same sliding submenu, built by the same MenuPanel component. Each fix is a submenu row with a chevron. Focusing a row previews its steps. Right or OK opens the scrolling steps, and Back or Left returns to the row. Back from the submenu slides it out to the rail.

Build 33: wrapped submenu titles have no leading space, and a small gold down chevron shows under the last visible row when more rows are below it. Titles still come from `guide.json`; nothing in the format changed.

## Edits

1. Rename a row: change its `label`.
2. Reorder the rail: move objects inside `items`. The first seven top items are the rail.
3. Add a Things to Do row: add a child under `things` with an `id`, `label`, and the mapping fields.
4. Point a child at different activities: edit `sectionIds`, `keywords`, or `seasons`. Leave the activity text in `activities.json`.
5. Keep Quick Fixes on the guide: leave `source` as `guide.troubleshooting`.

A bad `type`, a missing label, or a Things to Do block with no children is ignored. The channel keeps the previous good menu.

## When a change shows up

The channel fetches the live file on launch and again every six hours. A new ETag replaces the saved copy. A failed fetch keeps the saved copy, then the packaged file. Sideload a new package to change the packaged fallback.
