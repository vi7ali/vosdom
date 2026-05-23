# vosdom.space

Source for my personal site at [vosdom.space](https://vosdom.space).

Built with [Hugo](https://gohugo.io/) and the [PaperMod](https://github.com/adityatelange/hugo-PaperMod) theme.

## Local development

Requires Hugo Extended (≥ 0.140).

```sh
git clone --recurse-submodules https://github.com/vi7ali/vosdom-space.git
cd vosdom-space
hugo server -D
```

Then open <http://localhost:1313>.

If you cloned without `--recurse-submodules`, pull the theme separately:

```sh
git submodule update --init --recursive
```

## Build

```sh
hugo --minify
```

Output lands in `public/`.

## License

Site content (everything in `content/` and `static/`) is © Vitaly, all rights reserved. Configuration and layout files are MIT-licensed where not derived from PaperMod (which carries its own MIT license).
