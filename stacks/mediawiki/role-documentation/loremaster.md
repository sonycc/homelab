# Loremaster Handbook

## Welcome

As a Loremaster you decide what counts as canon on the wiki. Players write and suggest, and you review, approve, organise and protect.

The wiki is a private MediaWiki site for our homebrew game, the same software that runs Wikipedia. Only signed-in members can read it, apart from the Main Page, which anyone can see. If you know HTML and CSS you already know most of what matters: a wiki page is a document you write in a lighter markup called *wikitext*, and MediaWiki turns it into HTML.

The key idea is **approval**. When a player edits a lore page, readers keep seeing the last approved version until a Loremaster approves the change. A page that was never approved shows readers only the notice "This page is awaiting approval and is not considered lore." Your own edits are approved automatically.

These are the roles on the wiki:

| Role | What they can do |
| --- | --- |
| New account | Edit their own user pages and post on any talk page |
| Player | Suggest edits on any page and upload files up to 20 MB |
| **Loremaster** (you) | Everything a Player can, plus approve, move, protect, patrol, block, bulk edit and upload files up to 99 MB |
| Admin | Templates, forms and modules, deleting pages, giving out the Player and Loremaster roles, interwiki prefixes |
| Site developer | Site-wide CSS and JavaScript, such as `MediaWiki:Common.css` |

## Your role

You are the editor-in-chief of the lore. You don't have to write everything yourself. Your job is to keep what readers see accurate, consistent and tidy.

### What you are responsible for

- **Approving suggestions.** Review player edits to lore pages and approve the ones that fit the canon.
- **Promoting drafts into canon.** New players draft in their own user space (for example `User:Mira/Thornwall`). When a draft is ready, you move it to its real title.
- **Keeping the wiki organised.** Fix titles, add categories, merge duplicates and set up redirects.
- **Patrolling.** Check recent changes for mistakes, spam and vandalism.
- **Protecting settled canon.** Lock pages that should no longer change, so only Loremasters and admins can edit them.
- **Setting licences.** If a player asks for their own licence on the first line of a page, add the `{{License}}` template (see Organising lore).
- **Helping players.** Answer questions on talk pages and point people to this guide.

### What you can do

| Action | Where | Notes |
| --- | --- | --- |
| Approve a revision | Page history → **approve** link | Readers then see that version |
| Edit any page | Edit button | Except templates, forms and modules |
| Move (rename) a page | **More → Move** | Leaves a redirect behind by default |
| Protect a page | **More → Protect** | One level: "Allow only Loremasters and admins" |
| Patrol edits | `Special:RecentChanges` | Mark edits as checked |
| Block a user | `Special:Block` | For spam and vandalism only |
| Mark an edit as minor | Checkbox when saving | Typos and formatting only |
| Bulk edit | `Special:MultiPageEdit` | Spreadsheet-style editing of form-based pages |
| Upload files | `Special:Upload` | Up to 99 MB |

### What you should not do

- **Don't approve your own taste over the group's canon.** If an edit contradicts something established, discuss it on the talk page first.
- **Don't approve copied material** from books, other wikis or the web unless it is openly licensed (like SRD 5.1) and marked with `{{License}}`.
- **Don't use protection to win an argument.** Protect settled canon or pages under attack, not pages someone else is actively working on.
- **Don't block players over disagreements.** Blocks are for spam, bots and vandalism. Tell an admin whenever you block someone.
- **Don't mark real content changes as minor.** Minor edits are hidden from some watchlists, so others might miss them.
- **Don't edit other people's user pages.** Those are their personal drafts. Comment on the talk page instead.
- **Don't put spoilers or private details on the Main Page.** It's the one page anyone on the internet can read.
- **Don't try to change templates, forms or site styling.** Ask an admin (see Styling).

## Getting started

Sign in, open any page, click **Edit**, write, add a summary and save. That covers most of the work. The rest of this section covers the two Loremaster tasks you'll do most: approving changes and moving drafts.

### Your account

- Passwords must be at least 12 characters. Three wrong attempts lock you out for 15 minutes.
- Email is turned off, so there is no "forgot password" link. Ask an admin to reset it.
- Two-factor login is optional, but we recommend it for Loremasters: `Special:OATHManage`.
- `Special:Preferences` lets you change the skin (the default is Citizen, which follows your device's light or dark mode) and the editor, and set your signature.

### The two editors

The **Edit** button opens the *visual editor*, which works like a word processor. Inside it, the pencil icon switches to *source editing*, where you write raw wikitext. The wiki remembers which one you used last.

Use the visual editor for prose. Use source editing for tables, templates and anything with HTML or styling, because it shows exactly what you wrote.

### Saving well

1. Click **Show preview** to see the result before saving.
2. Click **Show changes** to see a diff of what you changed.
3. Write an edit summary, for example "Added the fall of Thornwall from session 12". The wiki warns you once if it's empty. Approvers read these summaries in the page history, so make them useful.
4. Tick **Watch this page** to get notified about later changes. You can watch for a limited time, such as one week.

### Approving a change

1. Find pages that need review at `Special:ApprovedRevs`. It lists pages with unapproved changes and pages that were never approved.
2. Open the page and click **History**. The approved revision is marked.
3. Click **diff** or **prev** on the newest revision to compare it with the approved one.
4. If it fits the canon, click **approve** on that revision. Readers see it immediately.
5. If it doesn't fit, leave it unapproved and explain why on the page's talk page. Pinging the editor with `[[User:Name]]` notifies them.

You can also approve an older revision, which acts as a rollback that readers see. **Unapprove** hides the page from readers again. Use it only for pages that should not be canon.

User pages and templates are never approved, because they don't count as lore. Approval applies to normal articles, categories, files, help pages and the project pages.

### Moving a draft into canon

1. Open the draft, for example `User:Mira/Thornwall`.
2. Choose **More → Move**, set the namespace to *(Main)* and the new title to `Thornwall`.
3. Leave **Leave a redirect behind** ticked so old links keep working, and give a reason.
4. Open the moved page and check its categories and links. Because you moved it, approve it if it isn't approved already.
5. Thank the author with the **thank** link in the history.

## Wikitext for HTML people

Wikitext is shorthand that MediaWiki turns into HTML. Every construct below maps to a tag you already know, and you can use a lot of plain HTML too.

| You write | You get (HTML) |
| --- | --- |
| `== Section ==` | `<h2>` (use `===` for `<h3>`, and so on; never use `=` alone, it is the page title) |
| `''italic''` | `<i>` (two apostrophes) |
| `'''bold'''` | `<b>` (three apostrophes) |
| `* item` | `<ul><li>` (`**` nests a level deeper) |
| `# item` | `<ol><li>` |
| `; Term` then `: Definition` | `<dl><dt><dd>` |
| `: text` at line start | indented text, common on talk pages |
| A blank line | a new `<p>` |
| `<br>` | a line break; a single newline does nothing |
| `----` | `<hr>` |
| `~~~~` | your signature and a timestamp, for talk pages |
| `<nowiki>''text''</nowiki>` | shows the markup literally |
| `<!-- note -->` | an HTML comment, visible only in the editor |

### Links

There is no `<a href>` for wiki pages. Use double brackets and the wiki tracks links for you. A link to a page that doesn't exist yet shows in red, which is a handy to-do list.

```
[[Thornwall]]                       link to a page
[[Thornwall|the old keep]]          custom link text (like <a>text</a>)
[[Thornwall#History]]               link to a section (like href="#id")
[[Category:Places]]                 puts THIS page in a category (no link shown)
[[:Category:Places]]                links TO the category (note the leading colon)
[[User:Mira]]                       links to a user and notifies them
[https://example.com Example site]  external link: URL, a space, then text
```

Titles are case-sensitive except for the first letter, and spaces and underscores are the same thing.

### Images and files

Upload first at `Special:Upload`. Allowed types are png, jpg, jpeg, gif, webp, svg, pdf, mp3 and ogg. Then embed the file:

```
[[File:Thornwall map.jpg]]                                full size
[[File:Thornwall map.jpg|thumb|300px|The keep in 1203]]   framed thumbnail with a caption
[[File:Crest.png|left|80px|link=Thornwall]]               floated left, clicks through to a page
[[Media:Session 12.mp3]]                                  plain link to the file itself
```

PNG, WebP and GIF images over 12.5 megapixels upload fine but get no thumbnail. **Export large maps as JPEG.**

### Tables

You can write `<table>` HTML, but wiki table syntax is shorter. `class="wikitable"` gives the standard bordered style, and adding `sortable` lets readers sort by column.

```
{| class="wikitable sortable"
|+ Factions of the Reach
! Faction !! Seat !! Leader
|-
| Iron Choir || Thornwall || Abbess Vey
|-
| style="background:#eef" | Salt Court || Mirehaven || The Tidelord
|}
```

How each line maps to HTML:

```
{|  ...  |}        <table> ... </table>   (attributes go after {| )
|+                 <caption>
!                  <th>   (!! starts the next header cell on the same line)
|-                 <tr>
|                  <td>   (|| starts the next cell on the same line)
| style="..." |    attributes for that one cell, then a pipe, then the content
```

### Magic words

These special words change the page itself:

- `__TOC__` places the table of contents at that spot. `__NOTOC__` hides it.
- `{{DISPLAYTITLE:''Italic title''}}` changes how the title is shown.
- `{{DEFAULTSORT:Vey, Abbess}}` sets how the page sorts in categories.
- `<ref>Session 12 notes</ref>` adds a footnote. `<references />` lists them at the bottom.
- `<syntaxhighlight lang="css">...</syntaxhighlight>` shows highlighted code.

## Organising lore

The wiki stays navigable through four tools: namespaces, categories, redirects and templates. You manage the first three directly. Admins build templates and forms, and you use them.

### Namespaces

A title prefix decides what kind of page it is, a bit like a top-level folder.

| Prefix | Holds | Approval | Who edits |
| --- | --- | --- | --- |
| *(none)* | Lore articles: places, people, history | Yes | Players suggest, you approve |
| `User:` | Personal pages and drafts | No | That user, plus Loremasters and admins |
| `Talk:`, `User talk:` etc. | Discussion about the matching page | No | Everyone |
| `Category:` | Automatic lists of pages | Yes | Players suggest, you approve |
| `File:` | Uploaded images and documents | Yes | Uploaders, you approve |
| `Help:` and the project namespace | Guides and policies about the wiki itself | Yes | Players suggest, you approve |
| `Template:`, `Form:`, `Module:` | Reusable building blocks | No | Admins only |
| `Special:` | Built-in tools, such as RecentChanges | n/a | Nobody |

### Categories

Add `[[Category:Places]]` anywhere on a page, usually at the bottom. The page then appears on the `Category:Places` page automatically. A page can have several categories, and a category can belong to another category to form a tree.

- Give each category page a sentence explaining what belongs in it. That also lets you approve the category page.
- Sorting is alphabetical as plain text, so "Level 10" comes before "Level 2". Pad numbers with `{{DEFAULTSORT:Level 02}}`.
- Use `[[Category:Places|Thornwall, Keep of]]` to sort one page by a different key.
- `Special:Categories` lists all categories. `Special:UncategorizedPages` shows pages nobody has filed yet.

### Redirects

A redirect sends readers from one title to another. Its whole page is one line:

```
#REDIRECT [[Thornwall]]
```

Create them for alternative names, common misspellings and old titles. Moving a page creates one for you. `Special:WhatLinksHere` shows everything that links to a page before you rename or merge it.

### Templates

A template is a reusable snippet, like a component or a server-side include. You call it in double curly braces and pass parameters:

```
{{Character
 | player   = Mira
 | campaign = The Reach
 | class    = Wizard
 | level    = 5
 | status   = Alive
}}
```

That draws the character infobox and records the data for search. Click **Edit** in the visual editor and choose **Insert → Template** to fill one in with a form instead of typing it.

Only admins can create or change templates. To propose one, build it on a user page such as `User:YourName/Faction box`, try it with `{{User:YourName/Faction box}}`, and ask an admin to move it into `Template:`. **Never leave a canon page using a user-page template.** Changes to user pages skip approval, so they would change canon without anyone reviewing them.

### Forms and structured data

Some page types have a form instead of free wikitext: player characters, NPCs, places, campaigns and factions, made with `Form:Character`, `Form:NPC`, `Form:Place`, `Form:Campaign` and `Form:Faction`. The **Create or edit** box on each type's category page, such as `Category:Places`, opens the form, and those pages get an **Edit with form** tab. A red link in an infobox opens the right form too.

Places nest: every place names the place it's in, up to the root, `Cosmos`. A place's infobox shows its full path, the places directly inside it and every NPC and faction anywhere inside it. Under **Top level**, `Category:Places` lists places with no parent. Anything there besides `Cosmos` needs its **Located in** fixed.

The data in those forms is stored in tables you can query, so you can build index pages that never go out of date:

```
{{#cargo_query:tables=Characters
 |fields=_pageName=Character,class=Class,level=Level,status=Status
 |where=campaign='The Reach'
 |order by=level DESC
 |format=table
}}
```

`Special:CargoTables` shows which tables and fields exist. `Special:MultiPageEdit` lets you edit many form-based pages at once, in a grid.

### Licences

The whole wiki is CC BY-NC-ND 4.0 unless a page says otherwise. Mark exceptions with the `{{License}}` template at the bottom of the page:

```
A player's own work, at their request (they write the licence on the page's first line):
{{License|CC BY 4.0|url=https://creativecommons.org/licenses/by/4.0/|holder=Mira}}

Material from a published game:
{{License|CC BY 4.0
 |url=https://creativecommons.org/licenses/by/4.0/
 |source=System Reference Document 5.1
 |holder=Wizards of the Coast LLC
}}
```

When you set a player's licence, remove the line they wrote. A licence label grants no rights, so only openly licensed material may be copied in at all.

### Pages managed outside the wiki

A few pages are maintained by the admin in files and re-imported on every update: the `Category:`, `Form:` and `Template:` pages for characters, NPCs, places, campaigns and factions, `Module:Place` and `Template:License`. **Edits you make to them on the wiki are overwritten.** Ask the admin to change them instead. After an update, those category pages may show as awaiting approval again, so just approve them.

## Styling with HTML and CSS

You can use most formatting HTML and inline `style` attributes directly in wikitext. There are no `<style>` blocks, scripts or site-wide stylesheets, though. MediaWiki cleans every page for safety, so anything not on its allowed list is shown as plain text or removed.

### Allowed

- **Layout and text tags:** `div`, `span`, `p`, `br`, `hr`, `h1`–`h6`, `blockquote`, `pre`, `code`, `small`, `sub`, `sup`, `abbr`, `mark`, `s`, `u`, `del`, `ins`, `q`, `cite`, `ruby`.
- **Lists and tables:** `ul`, `ol`, `li`, `dl`, `dt`, `dd`, `table`, `caption`, `tr`, `th`, `td`, with `colspan` and `rowspan`.
- **Attributes:** `style`, `class`, `id`, `title`, `lang` and `dir`.
- **Inline CSS:** colours, borders, padding, margins, floats, widths, fonts, flex and grid.

### Not allowed

- **No `<a>` or `<img>`.** Use `[[links]]` and `[[File:...]]` instead.
- **No `<script>`, `<style>`, `<iframe>`, `<form>`, `<input>`, `<button>` or `<link>`.**
- **No `url()` in CSS.** Background images from the web are stripped.
- **No editing the site stylesheet** (`MediaWiki:Common.css`). Only the site developer can do that.

### Built-in classes worth knowing

| Class | Effect |
| --- | --- |
| `wikitable` | Standard bordered table |
| `sortable` | Clickable column sorting, combined with `wikitable` |
| `mw-collapsible` | Adds a show/hide toggle to a table or div |
| `mw-collapsed` | Starts a collapsible element closed |
| `floatleft` / `floatright` | Floats a block with sensible margins |

### Example: a callout box

```
<div style="border-left:4px solid #a2783c; background:#f7f1e6; color:#2b2118; padding:0.6em 1em; margin:1em 0;">
'''Rumour.''' Nobody has seen the Tidelord's face in forty years.
</div>
```

Wikitext such as `'''bold'''` and `[[links]]` still works inside HTML tags.

### Good practice

- **Prefer built-in classes and plain wikitext.** Use inline styles only where they add meaning.
- **Don't copy the same style block onto many pages.** If you need a box more than twice, ask an admin to turn it into a template so it can be changed in one place.
- **Keep text readable.** Readers may use light or dark mode, so whenever you set a background colour, set the text colour too. Don't use colour alone to carry meaning, and check the page in both modes.
- **Try out CSS for yourself** in your personal stylesheet at `Special:MyPage/common.css`. Only you will see it.

## Working with others

Every page has a history and a talk page. Between them, nothing is ever lost and every disagreement has a place to happen.

### Talk pages

The **Discussion** tab on any page opens its talk page. Use **Add topic** to start a thread and the **Reply** link under a comment to answer. Replies are signed automatically. If you edit the talk page source by hand, end your comment with `~~~~`.

- Discuss a rejected or contested edit on the talk page of that article, not in edit summaries.
- Mention someone with `[[User:Name]]` to send them a notification.
- Everyone, including brand-new accounts, can post on talk pages. That makes them the right place for new players to ask questions.

### Staying informed

- **Notifications** (the bell) show mentions, replies, thanks and changes to your user talk page.
- **Watchlist** (`Special:Watchlist`) shows recent changes to pages you watch. Watch the areas of lore you look after.
- **Thanks:** the **thank** link next to an edit in a page's history sends a quiet appreciation to the editor.

### History, diffs and undoing

**History** lists every revision with its author and summary. Select two revisions and click **Compare selected revisions** to see a side-by-side diff.

- **Undo** next to a revision reverses just that edit and opens it for you to save.
- To restore a whole older version, open it from the history, click **Edit**, and save it with a summary such as "Restore version from 3 May".
- On approved pages you can often just approve the older good revision. Readers see it immediately, and the bad edit stays in history for the record.

### Patrolling

`Special:RecentChanges` lists every edit. Edits nobody has checked yet are marked with a red **!**. Open the diff, check it, and click **Mark as patrolled** so other Loremasters don't redo your work. `Special:NewPages` lists newly created pages. Your own edits are patrolled automatically.

### Protecting a page

Use **More → Protect** and choose "Allow only Loremasters and admins" for editing, moving or both. Set an expiry and a reason. Protect pages whose canon is settled, or pages under repeated vandalism. Don't protect a page someone is still actively building. `Special:ProtectedPages` lists everything that's locked.

### Blocking

Every new account is announced in Discord so an admin can give it a role. If a spam account or vandal gets in, block it at `Special:Block`. Choose an expiry, and choose *indefinite* only for obvious bots. Leave **Autoblock** on. Then tell an admin in Discord. Never block a player over a disagreement about lore.

## Quick reference

### Before you approve, check that

- [ ] It agrees with established canon, or the conflict was settled on the talk page
- [ ] It is the player's own writing, or openly licensed material marked with `{{License}}`
- [ ] The title is right, and duplicates are merged or redirected
- [ ] It has at least one category
- [ ] Links point to the right pages, and red links are intentional
- [ ] It doesn't rely on a template from someone's user page
- [ ] Images display, with no missing thumbnails

### Pages you'll use most

| Page | What it's for |
| --- | --- |
| `Special:ApprovedRevs` | Pages waiting for approval |
| `Special:RecentChanges` | Every edit, for patrolling |
| `Special:Watchlist` | Changes to pages you watch |
| `Special:NewPages` | Newly created pages |
| `Special:UncategorizedPages` | Pages that need a category |
| `Special:WantedPages` | Red links that people keep making |
| `Special:CargoTables` | Structured data you can query |
| `Special:SpecialPages` | Every tool on the wiki |

### Getting help

- **Admins** handle roles, templates, forms, deleting pages, password resets and site styling. Reach them in Discord.
- **Other Loremasters:** use the talk page of the article in question for lore decisions, so the discussion stays with the page.
- **Syntax reference:** [Help:Formatting](https://www.mediawiki.org/wiki/Help:Formatting), [Help:Tables](https://www.mediawiki.org/wiki/Help:Tables), [Help:Images](https://www.mediawiki.org/wiki/Help:Images) and [Help:Templates](https://www.mediawiki.org/wiki/Help:Templates) on mediawiki.org.
