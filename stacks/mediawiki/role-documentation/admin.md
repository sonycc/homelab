# Admin Guide

## Welcome

Admins run the wiki: you manage who can do what, build the templates and forms everyone else uses, and clean up what Loremasters can't. You have every Loremaster power too, so read the [Loremaster Handbook](loremaster.md) for approving, moving, protecting and patrolling. The [Player Guide](player.md) covers wikitext and styling.

These are the roles on the wiki:

| Role | What they can do |
| --- | --- |
| New account | Edit their own user pages and post on any talk page |
| Player | Suggest edits on any page and upload files up to 20 MB |
| Loremaster | Everything a Player can, plus approve, move, protect, patrol, block, bulk edit and upload files up to 99 MB |
| **Admin** (you) | Everything a Loremaster can, plus templates, forms and modules, deleting pages, giving out the Player and Loremaster roles, interwiki prefixes |
| Site developer | Site-wide CSS and JavaScript, such as `MediaWiki:Common.css` |

Some tasks need a command on the server rather than a page on the wiki. They're marked **server** below. If you don't have server access, ask the wiki's owner.

## Your role

### What you are responsible for

- **Letting people in.** Give new accounts the right role, and keep spam accounts out.
- **Building structure.** Templates, forms, Cargo tables and Lua modules are yours to create and maintain.
- **Cleaning up.** Delete spam, duplicates and abandoned pages, and undo damage that needs admin rights.
- **Backing up Loremasters.** Handle blocks they report, and settle disputes they can't.

### What you can do

| Action | Where | Notes |
| --- | --- | --- |
| Give or remove Player and Loremaster | `Special:UserRights/<name>` | The only roles offered there |
| Make someone an admin | **server** | See Managing people |
| Create an account for someone | `Special:CreateAccount` while logged in | Skips the one-account-per-network limit |
| Reset a password | **server** | Email is off, so there's no self-service reset |
| Rename a user | `Special:RenameUser` | |
| Block and unblock | `Special:Block`, `Special:BlockList` | |
| Delete and restore pages | **More → Delete**, `Special:Undelete` | |
| Mass-delete a spammer's pages | `Special:Nuke` | |
| Find and replace across pages | `Special:ReplaceText` | Edits are approved automatically, so use with care |
| Edit templates, forms and modules | `Template:`, `Form:`, `Module:` pages | Admins only |
| Generate a template, form and category in one go | `Special:CreateClass` | |
| Manage interwiki prefixes | `Special:Interwiki` | For example `[[srd:Fireball]]` |
| Edit interface messages | `MediaWiki:` pages | Except those set in config, see below |

### What you should not do

- **Don't hand out Loremaster lightly.** Their approvals define canon. Agree on new Loremasters as a group.
- **Don't give a role to an account you can't match to a person** in Discord.
- **Don't delete to settle a lore dispute.** Unapprove the revision and discuss it on the talk page. Deletion is for spam, duplicates and pages nobody needs.
- **Don't use bulk tools to change lore.** `Special:ReplaceText` and `Special:MultiPageEdit` edits are approved automatically, so they skip review. Use them for renames and formatting.
- **Don't edit the pages kept in git on the wiki.** Your change is overwritten on the next deploy. See Pages kept in git.
- **Don't put the signup question's answer anywhere on the wiki.** The Main Page is public, and the answer is the only thing keeping bots out.
- **Don't run an admin account without two-factor login.**

## Managing people

### New signups

Every signup posts a message in Discord with a link to that user's rights page. Check who it is, then tick **Player** (or **Loremaster**) at `Special:UserRights/<name>` and give a short reason.

Signup asks a question only our players can answer, which keeps generic bots out. Each network can create one account per year. That limit lives in memory, so restarting the wiki resets it. If two people share a network, create the second account yourself at `Special:CreateAccount` while logged in.

### Making an admin

`Special:UserRights` can't make admins. Have the person sign up, then run this on the server, from the wiki's stack directory:

```bash
docker compose exec mediawiki php maintenance/run.php createAndPromote --force <name> --sysop
```

Ask every new admin to enable two-factor login at `Special:OATHManage` straight away.

### Password resets

Email is off. Reset a password on the server, then send the new one privately and ask the person to change it:

```bash
docker compose exec mediawiki php maintenance/run.php changePassword --user <name> --password <new>
```

### Spam and vandalism

1. Block the account at `Special:Block` with autoblock on. Use an indefinite block for obvious bots.
2. Delete everything it created at `Special:Nuke`.
3. Check `Special:Log` for anything else it touched.

## Building structure

Templates, forms and modules are protected so only admins can edit them. They are **not** subject to approval, so every save goes live on every page that uses them immediately. Preview carefully. **Preview page with this template**, under the edit box, shows the effect on a real page before you save.

### Templates

A template is a page in `Template:` that other pages include with `{{Name|param=value}}`. Inside it, `{{{param|default}}}` reads a parameter. Use `<noinclude>` for documentation and `<includeonly>` for what only the including page should get.

- **ParserFunctions** gives you `{{#if:}}`, `{{#switch:}}`, `{{#expr:}}` and friends.
- Add a `<templatedata>` block so the visual editor shows a form for the template. `Template:License` is an example.
- Number-like sort keys need padding, because categories sort as plain text: `{{DEFAULTSORT:Level 02}}`.
- There's no per-template stylesheet. For shared CSS classes, ask the site developer to add them to `MediaWiki:Common.css`.

### Cargo: templates as data

Cargo turns template parameters into database rows, so index pages are generated from content and can't drift.

1. In the template's `<noinclude>`, declare the table with `{{#cargo_declare:_table=Spells |level=Integer |school=String ...}}`.
2. In its `<includeonly>`, store each use with `{{#cargo_store:_table=Spells |level={{{level|}}} ...}}`.
3. Save, then open the template and use **Create data table**. Nothing is stored until you do.
4. Query it from any page with `{{#cargo_query:}}`. `Special:CargoTables` shows the tables and their rows.

When you change a declaration, use **Recreate data** on the template to rebuild the table. `Template:Character` is the working example.

### Page Forms

A form in `Form:` gives players fields instead of wikitext, and writes a template call for them.

- `{{{for template|Character}}}` and `{{{field|...}}}` define the form. `Form:Character` is the working example.
- `{{#forminput:form=Character}}` puts a "create or edit" box on any page.
- `{{#default_form:Character}}` on a category page adds the **Edit with form** tab to its pages.
- `{{#formredlink:target=...|form=Faction}}` in a template makes a red link open that form instead of the blank editor. `{{#arraymap:}}` applies it to each value of a list field. `Template:Character` does both.
- `Special:CreateClass` builds a template, its Cargo table, a form and a category in one step. It's the quickest way to start a new page type.

### Modules

`Module:` pages hold Lua code, run with Scribunto and called from wikitext with `{{#invoke:Name|function}}`. Use them when template logic gets too tangled for ParserFunctions. `Module:Place` is the working example: it reads Cargo with `mw.ext.cargo.query`.

### Places

Places nest. Each one names its parent in **Located in**, and `Module:Place` builds the path, the places directly below and every NPC and faction anywhere below.

The root is `Cosmos`, the only place without a parent. The form requires a parent, so the root is a page created by hand holding just `{{Place}}`, and edited in source. `Category:Places` lists every place without a parent under **Top level**; anything there besides the root is missing its parent.

To rename a place, root included, move it and keep the redirect. Pages naming the old title follow the redirect. `Special:ReplaceText` can tidy the old name out of **Located in** afterwards.

### Interface messages

Some interface wording is set in the wiki's config files, and the config always wins over a `MediaWiki:` page. That covers role names, the protection level label, the approval notices, the licence footer and save notice, and the messages new accounts see. Ask the owner to change those. Other messages, such as `MediaWiki:Sidebar`, can be edited on the wiki.

## Pages kept in git

These pages are stored in the repository under `stacks/mediawiki/pages/` and imported on every deploy:

| Page | File |
| --- | --- |
| `Category:Campaigns` | `pages/Category/Campaigns.wikitext` |
| `Category:Characters` | `pages/Category/Characters.wikitext` |
| `Category:Factions` | `pages/Category/Factions.wikitext` |
| `Category:NPCs` | `pages/Category/NPCs.wikitext` |
| `Category:Places` | `pages/Category/Places.wikitext` |
| `Form:Campaign` | `pages/Form/Campaign.wikitext` |
| `Form:Character` | `pages/Form/Character.wikitext` |
| `Form:Faction` | `pages/Form/Faction.wikitext` |
| `Form:NPC` | `pages/Form/NPC.wikitext` |
| `Form:Place` | `pages/Form/Place.wikitext` |
| `Module:Place` | `pages/Module/Place.wikitext` |
| `Template:Campaign` | `pages/Template/Campaign.wikitext` |
| `Template:Character` | `pages/Template/Character.wikitext` |
| `Template:Faction` | `pages/Template/Faction.wikitext` |
| `Template:NPC` | `pages/Template/NPC.wikitext` |
| `Template:Place` | `pages/Template/Place.wikitext` |
| `Template:License` | `pages/Template/License.wikitext` |

The file always wins: an edit on the wiki is overwritten next time. Change the file and redeploy instead. Imports are never approved automatically, so after a change to a `Category:` page, approve it at `Special:ApprovedRevs`. Templates and forms aren't approvable, so they go live as soon as they're imported.

## Approval settings

Approval applies to normal articles, `Category:`, `File:`, `Help:` and the project namespace. User pages and templates are never approved. Edits by Loremasters and admins are approved automatically, including new pages. A page with no approved revision shows readers a blank page with the notice "This page is awaiting approval and is not considered lore."

The Main Page is approvable too, and it's the one page visitors who aren't logged in can read. Links on it still need a login.

## Security

- Enable two-factor login at `Special:OATHManage`.
- Bot passwords are off, because they bypass two-factor login. Ask the owner before any bot gets an account.
- Three wrong passwords lock an account for 15 minutes. That's the whole brute-force defence, so use a long, unique password.
- Review `Special:Log/newusers` and `Special:ListUsers` now and then for accounts nobody recognises.

## Quick reference

| Page | What it's for |
| --- | --- |
| `Special:UserRights` | Give and remove roles |
| `Special:ListUsers` | Every account and its roles |
| `Special:Log` | Blocks, deletions, rights changes, moves and uploads |
| `Special:ApprovedRevs` | Pages waiting for approval |
| `Special:Nuke` | Mass-delete a user's pages |
| `Special:ReplaceText` | Find and replace across the wiki |
| `Special:CargoTables` | Cargo tables and their data |
| `Special:CreateClass` | New page type in one step |
| `Special:Interwiki` | Interwiki prefixes |

Reference: [Cargo](https://www.mediawiki.org/wiki/Extension:Cargo), [Page Forms](https://www.mediawiki.org/wiki/Extension:Page_Forms), [Approved Revs](https://www.mediawiki.org/wiki/Extension:Approved_Revs), [ParserFunctions](https://www.mediawiki.org/wiki/Help:Extension:ParserFunctions), [Scribunto](https://www.mediawiki.org/wiki/Extension:Scribunto) and [Working with MediaWiki, chapter 16](https://workingwithmediawiki.com/book/chapter16.html).
