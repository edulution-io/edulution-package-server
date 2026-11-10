# edulution Package Server

APT repository for edulution packages, hosted at **https://package.edulution.io**.

The server is a static [`reprepro`](https://wiki.debian.org/DebianRepository/SetupWithReprepro)
repository that is built by GitHub Actions and served via GitHub Pages
(branch `package_server`). The landing page shows the available packages and
the setup instructions.

---

## Adding the repository on a client

The following steps work on **all supported Ubuntu versions** – the codename is
detected automatically from `/etc/os-release`.

**1. Add the GPG key**

```bash
curl -fsSL https://package.edulution.io/pub.gpg | sudo gpg --dearmor -o /usr/share/keyrings/edulution.gpg
```

**2. Add the repository to your APT sources**

```bash
echo "deb [signed-by=/usr/share/keyrings/edulution.gpg] https://package.edulution.io/ $(. /etc/os-release && echo "$VERSION_CODENAME") main" | sudo tee /etc/apt/sources.list.d/edulution.list
```

**3. Update the package list and install a package**

```bash
sudo apt-get update
sudo apt-get install edulution-fileproxy
```

### Supported Ubuntu versions

| Ubuntu version   | Codename   | Status in repository |
|------------------|------------|----------------------|
| 24.04 LTS        | `noble`    | active               |
| 26.04 LTS        | `resolute` | active               |

> Note: The `noble` distribution used to be named `nobel` (a typo). It is now
> called `noble` everywhere; the old name only survives as a compatibility
> layer – `AlsoAcceptFor: nobel` accepts old uploads and the symlink
> `dists/nobel -> noble` keeps the old URL working for existing clients. Both
> can be dropped once no client uses `nobel` any more.

### One-time migration after the rename

Clients that used the repository **before** the rename have `Codename: nobel`
in their APT cache. Because APT refuses updates after release-information
changes, the first `apt update` after the rename fails:

```
E: Repository 'https://package.edulution.io noble Release' changed its
   'Codename' value from 'nobel' to 'noble'
```

`apt-get update` exits with code 100 and the package list of this repository
is not refreshed, which also breaks unattended upgrades and any automation.
The change has to be accepted once per machine:

```bash
sudo apt update --allow-releaseinfo-change
```

Afterwards `apt update` works as before. Newly set up machines are unaffected.

---

## Repository layout

```
.
├── packages/                     # Inbox: built .deb packages (+ .changes/.buildinfo)
│   └── <package-name>/<codename>/ # e.g. edulution-fileproxy/noble/...
├── package_server/               # Source of the published repository
│   ├── conf/
│   │   └── distributions         # reprepro: distributions (noble, resolute)
│   ├── pub.gpg                   # public signing key
│   ├── index.html                # landing page (instructions + package list)
│   ├── generate-package-json.sh  # generates packages.json for the landing page
│   ├── generate-indices.sh       # generates index.html for directory browsing
│   └── media/                    # logo/background for the landing page
└── .github/workflows/
    ├── build-and-deploy.yml      # builds & deploys the repository
    └── automatic-pull-request.yml# opens PRs for update/ branches
```

During the build, `reprepro` additionally generates the `dists/` directory
(indices, `Release`/`InRelease`) and the `pool/` directory (the actual `.deb`
files). These are **not** committed – they are regenerated on every run and
deployed to GitHub Pages.

---

## Version scheme of the forked linuxmuster packages

The linuxmuster.net server packages are forked under their **upstream names**
(`linuxmuster-base7`, `sophomorix-samba`, …), so nothing on a server has to be
renamed to move from one build to the other. What tells them apart is the
version:

```
1:7.4.24~edu
│ │      └─── suffix: this is the edulution build
│ └────────── the upstream version it was forked from
└──────────── Debian epoch 1
```

* The **epoch `1:`** decides precedence. A version without an epoch counts as
  `0` ([Policy 5.6.12][policy]), so `1:7.4.24~edu` wins against every `7.x`
  from `deb.linuxmuster.net`. No apt pin is needed, and the precedence travels
  inside the package instead of sitting in a `/etc/apt/preferences.d` file
  that gets cleaned away while someone debugs an unrelated problem.
* The **`~edu` suffix** makes the fork visible – in `apt policy`, in
  `dpkg -l`, on the landing page of this repository and in the server's motd,
  which highlights it. `~` sorts before the empty string, so `1:7.4.24~edu`
  ranks below a hypothetical `1:7.4.24` while still outranking every upstream
  version.
* Versioned dependencies between the forked packages therefore clamp with a
  trailing tilde: `linuxmuster-common (>= 1:7.4.5~)`. Without it `1:7.4.5~edu`
  would not satisfy the clamp, precisely because `~` sorts below the plain
  version.
* Packages edulution owns outright carry **no epoch**: there is no upstream
  namesake to outrank. They do carry the `~edu` suffix, because the suffix
  says who built a package and that is just as true for them —
  `edulution-linbo-gui7` is at `1.1.4~edu`. `edulution-fileproxy` and
  `edulution-linbo-vdi` are built outside this set of changes and still have
  a plain version; they get the suffix on their next release.

Both characters are refused by git in a refname, so the release workflows spell
them out: the tag of `1:7.4.24~edu` is `7.4.24-edu` and the branch it opens
here is `update/<package>-<codename>-1-7.4.24-edu`.

[policy]: https://www.debian.org/doc/debian-policy/ch-controlfields.html#s-f-version

---

## Publishing a new package

Packages are added by placing the built artifacts under `packages/`. **The
directory a package sits in names the distribution it is published to** – the
build does not look at the `Distribution:` field of the `.changes`.

1. Place the built files under `packages/<package-name>/<codename>/`. At least
   the `.deb` file, ideally together with the `.changes` file (and
   `.buildinfo`), e.g.:

   ```
   packages/edulution-fileproxy/noble/edulution-fileproxy_1.1.5_amd64.deb
   packages/edulution-fileproxy/noble/edulution-fileproxy_1.1.5_amd64.changes
   ```

   The `.changes` is not imported, but its checksums are verified before the
   `.deb` is – see `validate-incoming.sh`.

2. Make sure the target codename is listed in
   [`package_server/conf/distributions`](package_server/conf/distributions).
   A directory named after a codename that is not listed there fails the
   build rather than being skipped.

3. Commit the change. A push to `main` builds and deploys the repository
   automatically (see below).

> **Every package repository publishes into every codename it supports.**
> There is no automatic copy into all distributions any more. A package that
> is genuinely release-independent can say so itself with an `also-in` file
> next to the `.deb`:
>
> ```
> packages/edulution-fileproxy/noble/also-in
> ```
>
> containing one codename per line (`#` comments and blank lines are ignored).
> After importing the build copies the package into each of them with
> `reprepro copy`, which saves committing the same binary twice.
>
> The former `sync-distributions.sh` copied every package into every
> distribution unless one of that **name** was already there. That is wrong
> for packages that are bound to the release they were built on:
> `linuxmuster-linbo7` builds kernel and initrd from it, so a `resolute` build
> must never end up in `noble`. Which releases a build is valid for is a
> decision only the uploading repository can make, so it is written down next
> to the package.

> In practice, the individual package repositories (e.g.
> `edulution-fileproxy`) push their releases via automation into an
> `update/...` branch of this repo. The
> [`automatic-pull-request.yml`](.github/workflows/automatic-pull-request.yml)
> workflow then automatically opens a pull request to `main`.

### Supporting a new Ubuntu version (distribution)

1. Add a new block in [`package_server/conf/distributions`](package_server/conf/distributions)
   with the correct `Codename`.
2. Add the codename to the `FALLBACK_DISTS` list in
   [`package_server/index.html`](package_server/index.html) (only relevant for
   the display when `packages.json` is unreachable).
3. Have each package repository publish into the new codename – either with
   its own build under `packages/<package-name>/<codename>/`, or by adding the
   codename to the `also-in` file of an existing build. Nothing arrives there
   by itself.

The client instructions do **not** need to be changed – they detect the
codename automatically.

---

## Build & deploy

The [`build-and-deploy.yml`](.github/workflows/build-and-deploy.yml) workflow
runs on every push and performs the following steps in the `package_server/`
directory:

1. Install `reprepro` and import the GPG signing key (private key from the
   `GPG_PRIVATE_KEY` secret).
2. For every `packages/<package-name>/<codename>/` directory: verify the
   checksums of its `.changes` and run `lintian` over its `.deb` files
   (`validate-incoming.sh`), then import them into `<codename>` with
   `reprepro includedeb`.
3. If that directory holds an `also-in` file, copy the package into each
   codename listed there with `reprepro copy`.
4. Generate the repository indices with `reprepro export`.
5. Create the symlink `dists/nobel -> noble` (legacy URL, see above).
6. `generate-package-json.sh` generates `packages.json` (the landing page's
   package list, across **all** distributions).
7. `generate-indices.sh` generates `index.html` files for browsing the
   `dists/` and `pool/` directories.
8. **Deploy** (only on `main`): the contents of `package_server/` are published
   to GitHub Pages (branch `package_server`).

### Required secrets

| Secret            | Purpose                                        |
|-------------------|------------------------------------------------|
| `GPG_PRIVATE_KEY` | private key used to sign the repository indices |

The corresponding public key is committed as
[`package_server/pub.gpg`](package_server/pub.gpg) and is shipped to clients
(fingerprint `DD8F 6E92 … BD35 E6DB 4655 161B`).

---

## Testing locally

The generation scripts can be run without GitHub Actions, as long as `reprepro`
is installed:

```bash
cd package_server
bash build-repository.sh           # validate, import, export, build indices
```

For an unsigned build, drop the `SignWith:` lines from `conf/distributions`
first – otherwise `reprepro` asks for the private key.

Afterwards the folder can be served locally, e.g. with
`python3 -m http.server`, and inspected in the browser.

---

More information at [edulution.io](https://edulution.io).
