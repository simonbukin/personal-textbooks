# Personal Textbooks

A monorepo containing mdbook-based textbooks.

## Books

- **[Backend for Frontends](./books/backend-for-frontends/)** - A practical guide to backend architecture, infrastructure, and AI-native engineering
- **[Building Taste](./books/design-taste/)** - A practical guide to developing design judgment

## Development

Each book uses [mdbook](https://rust-lang.github.io/mdBook/). To build and serve a book locally:

```bash
cd books/backend-for-frontends
mdbook serve
```

## Vercel Deployment

Each book deploys as its own Vercel project from the same repo.

### Quick Setup (per book)

1. Go to [vercel.com/new](https://vercel.com/new)
2. Import this repo (`simonbukin/personal-textbooks`)
3. Configure:
   - **Root Directory**: `books/backend-for-frontends` (or `books/design-taste`)
   - **Framework Preset**: Other
   - **Build Command**: `curl -sSL https://github.com/rust-lang/mdBook/releases/download/v0.4.40/mdbook-v0.4.40-x86_64-unknown-linux-gnu.tar.gz | tar -xz && ./mdbook build`
   - **Output Directory**: `build/html`
   - **Install Command**: (leave empty)
4. Deploy

### For the second book

Create another Vercel project from the same repo, just change the Root Directory.

### Custom domains (optional)

After deploy, go to Settings → Domains to add custom domains like `backend.simonbukin.com` or `taste.simonbukin.com`.
