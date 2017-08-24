# gitbook-plugin-buddybuild

This repo contains a GitBook plugin that provides CSS, images,
Javascript, and other common assets required to build buddybuild books.

## Usage

In your `book.json` file:

```json
  "plugins": [
     "buddybuild@https://github.com/buddybuild-public/gitbook-plugin-buddybuild.git",
  ],
```

The files `bb/bb.css` and `bb/bb.js` should be automatically included
in the generated book.

## Assets

The `dictionaries` folder contains the `hunspell` dictionaries used
for buddybuild books. The `en_US` dictionary is the large version. The
`buddybuild` dictionary contains build/mobile development and
buddybuild-specific terminology; it should be specified first in any
`hunspell` invocation.

The `img` folder contains images used by the included CSS.

The `scripts` folder contains Perl scripts used by a book's `Makefile`:

* `linelength.pl`: checks every `*.adoc` source file for lines that are
                   too long (default limit is 80 characters).

* `spellcheck.pl`: checks the spelling of every `*.adoc` file using
                   `hunspell`, and the dictionaries provided in the
                   `dictionaries` folder.

## Copyright

This repo and its contents are copyright &copy; 2017 by buddybuild,
under the Creative Common Attribution-NonCommerical-NoDerivatives 4.0
International license ([CC BY-NC-ND
4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/)).

## Authors

The buddybuild team.

