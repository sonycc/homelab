# MediaWiki

Private wiki for the homebrew game, on the [official MediaWiki image](https://hub.docker.com/_/mediawiki) (1.43 LTS) with Cargo, Page Forms, Approved Revs and the Citizen skin built in.
Database is the shared postgres stack. First-time setup is in [DEPLOYMENT.md](DEPLOYMENT.md).

## How editing works

Open registration behind a captcha question. Anonymous visitors can read the Main Page and nothing else. Admins grant the Player and Loremaster roles at `Special:UserRights`; new admins are made with `createAndPromote --sysop`.
With `MW_SIGNUP_WEBHOOK_URL` set, each signup is posted to Discord with a link to that page.

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

`$egApprovedRevsEnabledNamespaces` uses an `array_plus` merge strategy: a shorter array does **not** disable the defaults, so unwanted namespaces must be switched off by name.

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
Imports are never approved automatically, so a page imported into an approvable namespace needs approving by hand after each change.

## Structured content

After saving a template with `#cargo_declare`, open it and use **Create data table**, or nothing is stored.
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
`MW_DB_SCHEMA` feeds both `install.php --dbschema` and `$wgDBmwschema`. If they disagree, `update.php` reports the wiki as older than 1.35. Manual `psql` queries need the schema qualified.

**`update.php` runs on every start**, from `entrypoint.sh`. Do not replace the entrypoint with `apache2-foreground`.

**Version bumps are manual.** Watch [mediawiki-announce](https://lists.wikimedia.org/postorius/lists/mediawiki-announce.lists.wikimedia.org/) and bump `ARG MEDIAWIKI_VERSION` in the Dockerfile.

**Extension refs are branch names**, so a new extension commit is not picked up until the `ARG` refs change. Citizen has no `REL1_43` branch; `CITIZEN_TAG` pins a release, bumped by hand.

**Brute-force protection is `$wgPasswordAttemptThrottle` alone.**
It keys on the client only while `$wgCdnServersNoPurge` names the proxy; otherwise three bad logins lock out everyone. TOTP is optional, so enrol the admin accounts at `Special:OATHManage`.

**Email is off.** Reset a forgotten password from the host:

```bash
docker compose exec mediawiki php maintenance/run.php changePassword --user <name> --password <new>
```

**PNG, WebP and GIF above 12.5 MP** upload but get no thumbnail. Export large maps as JPEG.

**Categories sort as plain text**, so Level 10 comes before Level 2.
The `numeric` and `uca-*` collations break on postgres. Pad the key in the template instead: `{{DEFAULTSORT:Level 02}}`.

**Uploads cap at 99 MB.** `upload_max_filesize` in the Dockerfile and `$wgMaxUploadSize` move together.

**Config** is `config/settings/*.php`, one file per section of [Manual:Configuration_settings](https://www.mediawiki.org/wiki/Manual:Configuration_settings).