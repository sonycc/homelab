# Player Guide

## Welcome

As a Player you write the world. You can create and edit pages anywhere on the wiki, and Loremasters review your changes before they become canon.

The wiki is a private MediaWiki site for our homebrew game, the same software that runs Wikipedia. Only signed-in members can read it, apart from the Main Page, which anyone can see. If you know HTML and CSS you already know most of what matters: a wiki page is a document you write in a lighter markup called *wikitext*, and MediaWiki turns it into HTML.

The key idea is **approval**. Your edits to lore pages are saved straight away, but they are suggestions. Readers keep seeing the last approved version until a Loremaster approves your change. A new page shows readers only "This page is awaiting approval and is not considered lore." until it is approved.

These are the roles on the wiki:

| Role | What they can do |
| --- | --- |
| New account | Edit their own user pages and post on any talk page |
| **Player** (you) | Suggest edits on any page and upload files up to 20 MB |
| Loremaster | Everything a Player can, plus approve, move, protect, patrol, block, bulk edit and upload files up to 99 MB |
| Admin | Templates, forms and modules, deleting pages, giving out the Player and Loremaster roles, interwiki prefixes |
| Site developer | Site-wide CSS and JavaScript, such as `MediaWiki:Common.css` |

## Your role

You bring the lore: places, people, history, your characters and what happened at the table. Loremasters keep it consistent, so write freely and let the review do its job.

### What you can do

| Action | Where | Notes |
| --- | --- | --- |
| Create or edit a page | **Edit** button, or click a red link | Saved as a suggestion until approved |
| Draft in your own space | `User:YourName/...` | Never needs approval. Every member can still read it |
| Create a character | **Create or edit character** box on `Category:Characters` | A form fills in the infobox for you |
| Create a campaign, faction or NPC | The box on `Category:Campaigns`, `Category:Factions` or `Category:NPCs`, or a red link in an infobox | Same as characters |
| Upload files | `Special:Upload` | Up to 20 MB |
| Discuss | Any talk page | Everyone can post |
| Watch pages | Star icon, or **Watch this page** when saving | Changes show in `Special:Watchlist` |
| Thank someone | **thank** link in a page's history | |

Ask a Loremaster to rename (move) a page, protect it or settle a lore question. Ask an admin to delete a page, change a template or form, or change your role.

### What you should not do

- **Don't copy material** from books, other wikis or the web unless it is openly licensed (like SRD 5.1) and marked with `{{License}}`. The same goes for images.
- **Don't rewrite settled canon on your own.** Propose big changes on the talk page first.
- **Don't edit-war.** If your change is rejected or undone, ask why on the talk page instead of making it again.
- **Don't create duplicate pages.** Search first, and add to the page that already exists.
- **Don't edit other players' user pages.** Those are their personal drafts. Comment on the talk page instead.
- **Don't put spoilers or private details on the Main Page.** It's the one page anyone on the internet can read.

## Getting started

### Your account

- Passwords must be at least 12 characters. Three wrong attempts lock you out for 15 minutes.
- Email is turned off, so there is no "forgot password" link. Ask an admin to reset it.
- Two-factor login is optional: `Special:OATHManage`.
- The default skin is Citizen, which follows your device's light or dark mode. You can switch to light, dark or auto in the skin's own settings panel. `Special:Preferences` changes the editor and your signature.

### The two editors

The **Edit** button opens the *visual editor*, which works like a word processor. Inside it, the pencil icon switches to *source editing*, where you write raw wikitext. The wiki remembers which one you used last.

Use the visual editor for prose. Use source editing for tables, templates and anything with HTML or styling, because it shows exactly what you wrote.

### Saving well

1. Click **Show preview** to see the result before saving.
2. Click **Show changes** to see a diff of what you changed.
3. Write an edit summary, for example "Added the fall of Thornwall from session 12". The wiki warns you once if it's empty. Loremasters read these summaries when deciding what to approve, so make them useful.
4. Tick **Watch this page** to get notified about later changes. You can watch for a limited time, such as one week.

### Creating a page

1. Search for the title first. If nothing exists, the search results offer to create it. You can also click any red link.
2. Start with a sentence that says what the subject is, for example "Thornwall is a ruined keep on the northern edge of the Reach."
3. Add at least one category at the bottom, such as `[[Category:Places]]`.
4. Save with a summary. The page now waits for a Loremaster.

Not ready to share it as a suggestion yet? Draft it at `User:YourName/Thornwall`. When it's done, ask a Loremaster on the draft's talk page to move it into canon.

### Creating your character

1. Open `Category:Characters` and type your character's name into the **Create or edit character** box.
2. Fill in the form: player, campaign, ancestry, class, level, faction, status, a portrait and a one-line summary. You can upload the portrait straight from the form.
3. Write the backstory in the large box below the form, using normal wikitext.
4. Save. The page appears in the table on `Category:Characters`, and gets an **Edit with form** tab for later changes.

Campaign and faction are picked from existing pages. If yours isn't listed, type the name anyway. It shows as a red link in the infobox, and clicking it opens the campaign or faction form.

### After you save

- The page history marks which revision is approved, so you can see whether your change is live for readers.
- If a Loremaster doesn't approve it, they explain why on the page's talk page. You get a notification when they mention you.
- To see your own latest version while it waits, open **History** and click the top revision.

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

## Organising your pages

### Categories

Add `[[Category:Places]]` anywhere on a page, usually at the bottom. The page then appears on the `Category:Places` page automatically. A page can have several categories.

Check `Special:Categories` for an existing category before inventing a new one. Sorting is alphabetical as plain text, so "Level 10" comes before "Level 2". Pad numbers, as in `{{DEFAULTSORT:Level 02}}`.

### Redirects

A redirect sends readers from one title to another. Its whole page is one line:

```
#REDIRECT [[Thornwall]]
```

Create them for nicknames and alternative spellings. To rename a page, ask a Loremaster to move it.

### Templates

A template is a reusable snippet, like a component or a server-side include. You call it in double curly braces and pass parameters:

```
{{License|CC BY 4.0|url=https://creativecommons.org/licenses/by/4.0/|holder=Mira}}
```

In the visual editor, **Insert → Template** fills one in with a form instead. Only admins can create or change templates. If you have an idea for one, build a mock-up on a user page such as `User:YourName/Faction box` and show it to an admin.

### Licences

The whole wiki is CC BY-NC-ND 4.0 unless a page says otherwise. By saving, you also let other members edit and adapt your contribution on this wiki.

- **Want a different licence for your own work?** Write it on the first line of the page, for example "Licence: CC BY 4.0". A Loremaster will set it properly and remove the line.
- **Using material from a published game?** It must be openly licensed, and you must name the source with `{{License}}` at the bottom of the page. A licence label grants no rights by itself.

### Files

Allowed types are png, jpg, jpeg, gif, webp, svg, pdf, mp3 and ogg, up to 20 MB. If you need to upload something bigger, ask a Loremaster or admin. PNG, WebP and GIF images over 12.5 megapixels get no thumbnail, so **export large maps as JPEG.**

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

### Talk pages

The **Discussion** tab on any page opens its talk page. Use **Add topic** to start a thread and the **Reply** link under a comment to answer. Replies are signed automatically. If you edit the talk page source by hand, end your comment with `~~~~`.

Mention someone with `[[User:Name]]` to send them a notification.

### Staying informed

- **Notifications** (the bell) show mentions, replies, thanks and changes to your user talk page.
- **Watchlist** (`Special:Watchlist`) shows recent changes to pages you watch.
- **Thanks:** the **thank** link next to an edit in a page's history sends a quiet appreciation to the editor.

### History and undoing

**History** lists every revision with its author and summary. Select two revisions and click **Compare selected revisions** to see a side-by-side diff. **Undo** next to a revision reverses just that edit, which is handy for fixing your own mistakes. Nothing is ever lost, so experiment without worry.

## Quick reference

| Page | What it's for |
| --- | --- |
| `Special:RecentChanges` | Every recent edit on the wiki |
| `Special:Watchlist` | Changes to pages you watch |
| `Special:MyPage` | Your user page |
| `Special:Categories` | Every category |
| `Special:WantedPages` | Red links waiting for someone to write them |
| `Special:Upload` | Upload a file |
| `Special:SpecialPages` | Every tool on the wiki |

### Getting help

- **Loremasters** answer lore questions, approve changes and move drafts into canon. Ask on the page's talk page.
- **Admins** handle roles, templates, forms, deleting pages and password resets. Reach them in Discord.
- **Syntax reference:** [Help:Formatting](https://www.mediawiki.org/wiki/Help:Formatting), [Help:Tables](https://www.mediawiki.org/wiki/Help:Tables), [Help:Images](https://www.mediawiki.org/wiki/Help:Images) and [Help:Templates](https://www.mediawiki.org/wiki/Help:Templates) on mediawiki.org.
