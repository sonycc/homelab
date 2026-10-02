# Site Developer Guide

## Welcome

The site developer owns the wiki's look and behaviour: the CSS and JavaScript that load on every page for every reader. It's the most powerful role on the wiki, and only the account created at install has it.

You're also an admin, so the [Admin Guide](admin.md) applies to you too.

These are the roles on the wiki:

| Role | What they can do |
| --- | --- |
| New account | Edit their own user pages and post on any talk page |
| Player | Suggest edits on any page and upload files up to 20 MB |
| Loremaster | Everything a Player can, plus approve, move, protect, patrol, block, bulk edit and upload files up to 99 MB |
| Admin | Templates, forms and modules, deleting pages, giving out the Player and Loremaster roles, interwiki prefixes |
| **Site developer** (you) | Everything an admin can, plus site-wide CSS and JavaScript, such as `MediaWiki:Common.css` |

## What you can edit

| Page | Loads |
| --- | --- |
| `MediaWiki:Common.css` | On every page, in every skin |
| `MediaWiki:Citizen.css` | Only in Citizen, the default skin |
| `MediaWiki:Vector-2022.css` | Only in Vector 2022, which members can pick in preferences |
| `MediaWiki:Common.js` | On every page, in every skin |
| `MediaWiki:Citizen.js` | Only in Citizen |
| Other users' `common.css` and `common.js` | Only for that user. Leave these alone unless they ask for help |

Edits to these pages are **not** subject to approval. They go live for everyone as soon as you save, though browsers may cache the old version for a few minutes.

## Your role

### What you are responsible for

- **Shared styling.** The wiki has no per-template stylesheets, so every class that templates use lives in `MediaWiki:Common.css`. When an admin builds a template that needs styling, they come to you.
- **Light and dark mode.** Citizen follows each reader's device setting, and readers can switch manually. Everything you style must work in both.
- **Keeping it safe.** JavaScript you add runs for every member, with their login. Treat it as code with admin access, because it has it.

### What you should not do

- **Don't add JavaScript you don't fully understand,** and never load scripts from other websites.
- **Don't put anything secret in CSS or JavaScript.** Site styles and scripts are served to logged-out visitors of the Main Page, so treat them as public.
- **Don't hide or restyle the approval notices** or the licence footer. Readers rely on them to know what is canon.
- **Don't use this account for everyday editing.** Keep a separate admin account for normal work, and keep two-factor login on this one.

## Working with CSS

### Workflow

1. Try the rule in your own `Special:MyPage/common.css` first. Only you see it.
2. When it works in both light and dark mode, move it to `MediaWiki:Common.css` under a comment naming the template or feature it belongs to.
3. Prefix your classes, for example `.lore-callout`, so they never clash with MediaWiki's or Citizen's own classes.
4. Tell the admin who asked for it which class to use in the template.

### Light and dark mode

MediaWiki marks the reader's choice with a class on `<html>`. Give every coloured element a rule for each mode:

```css
.lore-callout {
  border-left: 4px solid #a2783c;
  background: #f7f1e6;
  color: #2b2118;
  padding: 0.6em 1em;
}

html.skin-theme-clientpref-night .lore-callout {
  background: #2b2118;
  color: #f7f1e6;
}

@media (prefers-color-scheme: dark) {
  html.skin-theme-clientpref-os .lore-callout {
    background: #2b2118;
    color: #f7f1e6;
  }
}
```

The first dark rule covers readers who picked dark mode. The media query covers readers on "auto" whose device is dark. If a rule doesn't apply, check the classes on `<html>` in your browser's developer tools.

## Working with JavaScript

- Wrap page code in `mw.hook( 'wikipage.content' ).add( function ( $content ) { ... } );` so it also runs after the visual editor and live previews redraw content.
- Load MediaWiki modules with `mw.loader.using( [ 'mediawiki.api' ] ).then( ... )` instead of assuming they're present.
- Keep scripts small and comment what each block is for. The next site developer has to maintain it.

## When something breaks

Add `?safemode=1` to any wiki URL to load the page without site and user CSS and JavaScript. That lets you open the broken page and revert it from its history even if a script has made the wiki unusable.

## Interface wording

Some interface text, such as role names, approval notices and the licence footer, is set in the wiki's config files in git. The config always wins over a `MediaWiki:` page, so change those in the repository instead. Other messages can be edited on the wiki.

## Adding another site developer

`Special:UserRights` can't grant this role. Run this on the server, from the wiki's stack directory:

```bash
docker compose exec mediawiki php maintenance/run.php createAndPromote --force <name> --interface-admin
```

## Reference

[Manual:Interface/Stylesheets](https://www.mediawiki.org/wiki/Manual:Interface/Stylesheets), [Manual:Interface/JavaScript](https://www.mediawiki.org/wiki/Manual:Interface/JavaScript), [ResourceLoader/Core modules](https://www.mediawiki.org/wiki/ResourceLoader/Core_modules) and [Skin:Citizen](https://www.mediawiki.org/wiki/Skin:Citizen).
