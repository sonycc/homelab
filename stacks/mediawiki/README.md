# MediaWiki

Private wiki for the homebrew game, on the [official MediaWiki image](https://hub.docker.com/_/mediawiki) (1.43 LTS) with Cargo, Page Forms, Approved Revs, TabberNeue and the Citizen skin built in.
Database is the shared postgres stack. First-time setup is in [DEPLOYMENT.md](DEPLOYMENT.md).

## How editing works

Open registration behind a captcha question. Anonymous visitors can read the Main Page and nothing else. Admins grant the Player and Loremaster roles at `Special:UserRights`; new admins are made with `createAndPromote --sysop`.
With `DISCORD_WEBHOOK_URL_NOTIFICATIONS` set, Discord gets a message for each signup, with a link to that page, and for each page that starts waiting for approval.

| Group (shown as) | Can |
|---|---|
| new account | edit own `User:Name` pages, post on any talk page |
| `player` (Player) | suggest edits anywhere else, upload up to 20 MB |
| `loremaster` (Loremaster) | approve, move, protect, patrol, block, mark minor edits, bulk edit with `Special:MultiPageEdit`, upload up to 99 MB |
| `sysop` (Admin) | edit templates, modules and forms, `Special:CreateClass`, interwiki prefixes, delete |
| `interface-admin` (Site developer) | edit `MediaWiki:Common.css` and `Common.js`; the installer's account only |

`bureaucrat`, `suppress` and `push-subscription-manager` are removed, and bot passwords are off until a bot needs one: they bypass TOTP.

Edits outside user pages and talk pages are suggestions: [Approved Revs](https://www.mediawiki.org/wiki/Extension:Approved_Revs) shows readers the last approved revision.
Edits by a loremaster or sysop are approved automatically, new pages included.
A page with no approved revision shows readers a blank page under "awaiting approval and is not considered lore"; its text is in the history and the editor.
Pages awaiting approval are listed at `Special:ApprovedRevs`.
A new player drafts in `User:Name/...`, and a loremaster moves the page into canon.

## Licensing

| Content | Licence |
|---|---|
| Default, set in the footer and the save notice | CC BY-NC-ND 4.0, holder `MW_LICENSE_HOLDER` |
| A player's own work, on request | whatever they ask for on the first line, set by a loremaster with `{{License}}` |
| Material from a published game | the publisher's terms, with `{{License}}` at the bottom of the page |

The save notice lets other contributors edit and adapt a contribution on this wiki, which ND alone would not.
`{{License}}` adds each page to `Category:Licensed <licence>`. Only openly licensed material such as SRD 5.1 may be copied in.

## Pages kept in git

`pages/<Namespace>/<Title>.wikitext` is imported on every start, and the file overwrites any on-wiki edit.
With `DISCORD_WEBHOOK_URL_NOTIFICATIONS` set, each such edit is posted to Discord with its diff, so it can be copied into git before a restart.
Each start also approves the imported `Category:` pages and rebuilds their links.

## Structured content

Each start builds the Cargo table of every `#cargo_declare` in `pages/Template/` that is new or changed since the last build, so a deploy needs no Cargo steps.
A template made on the wiki is not covered: after saving it, open it and use **Create data table**, or nothing is stored.
Reference: [Working with MediaWiki, chapter 16](https://workingwithmediawiki.com/book/chapter16.html).

## Backups

| | |
|---|---|
| Database | the postgres stack's instance-wide `pg_dumpall` |
| `images/` | `mediawiki-tasks`, into `BACKUP_HOST_DIR` |

`images/` is archived only when it changed, so `IMAGES_KEEP` holds the last N distinct states.
An images archive and a database dump will not share a timestamp: restore the newest images archive at or before the dump.

To restore uploads:

```bash
docker compose stop mediawiki mediawiki-tasks

docker run --rm \
  -v mediawiki_mediawiki_images:/images \
  -v /opt/homelab/mediawiki/backup:/backups:ro \
  alpine sh -c '
    rm -rf /images/* &&
    tar xzf /backups/images_<stamp>.tar.gz -C /tmp &&
    cp -a /tmp/images/. /images/'

docker compose up -d
```

The database is restored from the postgres stack's dumps.

## Operational notes

**The schema is `mediawiki`, not `public`.**
Manual `psql` queries need the schema qualified.

**`update.php` runs on every start**, from `entrypoint.sh`. Do not replace the entrypoint with `apache2-foreground`.

**Version bumps are manual.** Watch [mediawiki-announce](https://lists.wikimedia.org/postorius/lists/mediawiki-announce.lists.wikimedia.org/) and bump `ARG MEDIAWIKI_VERSION` in the Dockerfile.

**Extensions are pinned to release tags**, one `ARG` each in the Dockerfile, bumped by hand.

**Brute-force protection is `$wgPasswordAttemptThrottle` alone.**
TOTP is optional, so enrol the admin accounts at `Special:OATHManage`.

**Email is off.** Reset a forgotten password from the host:

```bash
docker compose exec mediawiki php maintenance/run.php changePassword --user <name> --password <new>
```

**PNG, WebP and GIF above 12.5 MP** upload but get no thumbnail. Export large maps as JPEG.

**Categories sort as plain text**, so Level 10 comes before Level 2.
Pad the key in the template: `{{DEFAULTSORT:Level 02}}`.

**Config** is `config/settings/*.php`, one file per section of [Manual:Configuration_settings](https://www.mediawiki.org/wiki/Manual:Configuration_settings).