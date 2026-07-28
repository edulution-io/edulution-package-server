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

---

## Repository layout

```
.
├── packages/                     # Inbox: built .deb packages (+ .changes/.buildinfo)
│   └── <package-name>/<codename>/ # e.g. edulution-fileproxy/noble/...
├── package_server/               # Source of the published repository
│   ├── conf/
│   │   ├── distributions         # reprepro: distributions (noble, resolute)
│   │   └── incoming              # reprepro: incoming configuration
│   ├── pub.gpg                   # public signing key
│   ├── index.html                # landing page (instructions + package list)
│   ├── sync-distributions.sh     # copies packages into all distributions
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

## Publishing a new package

Packages are added by placing the built artifacts under `packages/`. The build
copies everything from `packages/*/*/*` into the reprepro `incoming/` directory
and imports it.

1. Place the built files under `packages/<package-name>/<codename>/`. At least
   the `.deb` file, ideally together with the signed `.changes` file (and
   `.buildinfo`), e.g.:

   ```
   packages/edulution-fileproxy/noble/edulution-fileproxy_1.1.5_amd64.deb
   packages/edulution-fileproxy/noble/edulution-fileproxy_1.1.5_amd64.changes
   ```

2. Make sure the target codename is listed in
   [`package_server/conf/distributions`](package_server/conf/distributions)
   and in [`package_server/conf/incoming`](package_server/conf/incoming)
   (the `Allow:` line).

3. Commit the change. A push to `main` builds and deploys the repository
   automatically (see below).

> A package only has to be uploaded for **one** codename. During the build,
> `sync-distributions.sh` copies it into every other distribution, so a package
> uploaded under `noble` is also available for Ubuntu 26.04 (`resolute`).
> If a distribution needs its own build, place it under
> `packages/<package-name>/<codename>/` – an existing package is never
> overwritten by a copy from another distribution.

> In practice, the individual package repositories (e.g.
> `edulution-fileproxy`) push their releases via automation into an
> `update/...` branch of this repo. The
> [`automatic-pull-request.yml`](.github/workflows/automatic-pull-request.yml)
> workflow then automatically opens a pull request to `main`.

### Supporting a new Ubuntu version (distribution)

1. Add a new block in [`package_server/conf/distributions`](package_server/conf/distributions)
   with the correct `Codename`.
2. Add the codename to the `Allow:` line in
   [`package_server/conf/incoming`](package_server/conf/incoming).
3. Add the codename to the `FALLBACK_DISTS` list in
   [`package_server/index.html`](package_server/index.html) (only relevant for
   the display when `packages.json` is unreachable).
4. Optional: place distribution-specific packages under
   `packages/<package-name>/<codename>/`. All other packages are copied into
   the new distribution automatically during the build.

The client instructions do **not** need to be changed – they detect the
codename automatically.

---

## Build & deploy

The [`build-and-deploy.yml`](.github/workflows/build-and-deploy.yml) workflow
runs on every push and performs the following steps in the `package_server/`
directory:

1. Install `reprepro` and import the GPG signing key (private key from the
   `GPG_PRIVATE_KEY` secret).
2. Copy existing `.deb` packages from `../packages/*/*/*` into `incoming/` and
   import them with `reprepro processincoming default`.
3. `sync-distributions.sh` copies every package into all distributions
   configured in `conf/distributions`, unless the distribution already
   contains a package of that name.
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
bash sync-distributions.sh         # copy packages into all distributions
reprepro -V export                 # generate indices (uses conf/ + pool/)
bash generate-package-json.sh      # build packages.json
bash generate-indices.sh           # build directory indices
```

Afterwards the folder can be served locally, e.g. with
`python3 -m http.server`, and inspected in the browser.

---

More information at [edulution.io](https://edulution.io).
