
**pkutils** is a package manager for Slackware Linux distribution.

![standards](https://imgs.xkcd.com/comics/standards.png)

Installation
============

```
git clone https://github.com/xoffy/pkutils
cd pkutils/slackware
./tarball.sh
sudo ./pkutils.sh
sudo upgradepkg --install-new /tmp/pkutils-*.t?z
```

First run
=========

1. Check out `/etc/pkutils/pkutils.conf`.
2. Set repositories in `/etc/pkutils/repos.list`.
3. `sudo pkupd`

The questions you might ask (TQYMA)
===================================

## I already use the time-tested package managers such as `slackpkg+` or `slapt-get`, why I should even look at your stuff?

Just give it a chance. It's Slackware.

## Why AWK?

Initially `pkutils` were a  set of the POSIX shell scripts with some helper scripts in AWK for processing the PACKAGES files. But eventually the AWK code became greater than the Shell one.

Also I quite liked the AWK since its syntax resembles C and it is very simple and primitive (as opposed to monsters like Python or Ruby). If `pkutils` will survive, I think it will be rewritten in something like Go or Rust.

I understand that AWK is not supposed to be used in the way I use it, but who cares.

## `man` pages, where they are?

1. I'm too lazy for it.
2. Writing in English consumes about 101% of my brain's CPU. Speaking it consumes even more.

## Should I be careful?

Definitely. Always use `-x` key with `pkadd`.

`pkutils` v. others
=================================================

|                                     | `pkutils`              | `slackpkg` | `slackpkg+`| `slapt-get`         | `sbopkg`            |
|-------------------------------------|------------------------|------------|------------|---------------------|---------------------|
| Can install a binary package        | `true`                 | `true`     | `true`     | `true`              | `false`             |
| Can build a package from SlackBuild | `true`<sup>1</sup>     | `false`    | `false`    | `false`<sup>2</sup> | `true`              |
| Supports 3rd-party repos            | `true`                 | `false`    | `true`     | `true`              | `false`             |
| Supports GPG signatures             | `false`                | `true`     | `true`     | ???                 | ???                 |
| Handles dependencies<sup>3</sup>    | `true`                 | `false`    | `false`    | `true`              | `false`<sup>4</sup> |
| Birth date                          | 2018/11 or 2019/02/08  | unknown    | 2011/07/12 | 2003/08/15          | 2013/12/09          |
| Can help you if you're depressed    | `true`<sup>5</sup>     | `false`    | `false`    | `false`             | `false`             |

1. Support is preliminary and thus quite limited. For example, you can't pass any flags to a SlackBuild script.
2. `slapt-src`, a little brother of `slapt-get`, can.
3. If a repository provides information.
4. Separate tool called `sqg` can print out list of dependencies.
5. If you are a developer.

Bréf
====

`pkutils` consists of three commands:
+ `pkupd` will synchronize with remote repositories and update an internal database.
+ With `pkque` you can search available packages and view some of their properties.
+ To install, reinstall, upgrade or downgrade packages you can use `pkadd`.

Use `-?` argument to see all available options.

pkexpr
======

`pkadd` and `pkque` work with the _package expressions_ (or _pkexprs_). Format of package expression is:

```
app~i586=1.3.0!_slack14.2@slackware64:xap
```

Example pkexpr above matches a package named `app` of version `1.3.0` for `i586` and tagged `_slack14.2` from repository named `slackware64` and belonging to `XAP` series.

All segments of pkexpr is optional, but empty pkexpr is not valid. Further examples:

+ `:kde` — all packages from `KDE` series.
+ `@msb` — all packages from `MATE SlackBuild` repository (but don't forget that only YOU are responsible for names of repositories, see `repos.lst`).
+ `kernel-.*` — packages whose name starts with `kernel-`.
+ `(ba|tc|z)sh` — matches `bash`, `tcsh` and `zsh`.
+ `mozilla-firefox=45.9.0esr` — exact version matching.
+ `!alien` — all packages from Eric.

So you got the idea.

Note that `pkutils` can't compare versions just like official `upgradepkg` (KISS, you know).

My dependency solver is quite slow, but I like it
=================================================

## Show dependencies of the `spamassassin` SlackBuild

+ `p`: show dependencies;
+ `s`: strict match of package name;
+ `n`: do not show repeating dependencies.

```
$ pkque -psn spamassassin
Reading packages index... Done.

sbo:network/spamassassin 3.4.1
  `- spamassassin (sbo, 3.4.1)
    `- re2c (sbo, 0.16)
    `- pyzor (sbo, 1.0.0)
    `- perl-Net-Server (sbo, 2.008)
    `- perl-Net-Ident (sbo, 1.23)
    `- perl-Mail-SPF (sbo, 2.9.0)
      `- perl-NetAddr-IP (sbo, 4.079)
      `- perl-Net-DNS-Resolver-Programmable (sbo, 0.003)
    `- perl-Mail-DKIM (sbo, 0.52)
      `- perl-net-dns (sbo, 1.06)
        `- perl-net-ip (sbo, 1.26)
        `- perl-digest-hmac (sbo, 1.03)
          `- perl-digest-sha1 (sbo, 2.13)
      `- perl-MailTools (sbo, 2.20)
        `- perl-TimeDate (sbo, 2.30)
      `- perl-Crypt-OpenSSL-RSA (sbo, 0.28)
        `- perl-Crypt-OpenSSL-Random (sbo, 0.11)
    `- perl-Image-Info (sbo, 1.41)
    `- perl-IP-Country (sbo, 2.28)
      `- perl-Geography-Countries (sbo, 20090413)
    `- perl-IO-Socket-SSL (sbo, 2.060)
      `- perl-Net-LibIDN (sbo, 0.12)
      `- Net-SSLeay (sbo, 1.81)
    `- perl-IO-Socket-INET6 (sbo, 2.71)
      `- perl-Socket6 (sbo, 0.28)
    `- perl-Encode-Detect (sbo, 1.01)
      `- perl-Module-Build (sbo, 0.4224)
        `- perl-PAR-Dist (sbo, 0.49)
    `- perl-Crypt-OpenSSL-Bignum (sbo, 0.08)
    `- libwww-perl (sbo, 6.13)
      `- perl-www-robotrules (sbo, 6.02)
      `- perl-net-http (sbo, 6.09)
      `- perl-http-negotiate (sbo, 6.01)
      `- perl-http-daemon (sbo, 6.01)
      `- perl-http-cookies (sbo, 6.01)
        `- perl-http-message (sbo, 6.11)
          `- perl-IO-HTML (sbo, 1.001)
          `- perl-lwp-mediatypes (sbo, 6.02)
          `- perl-html-parser (sbo, 3.71)
            `- perl-html-tagset (sbo, 3.20)
          `- perl-encode-locale (sbo, 1.05)
      `- perl-file-listing (sbo, 6.04)
        `- perl-http-date (sbo, 6.02)
  Total dependencies: 42.
```

## Same for `pandoc`

`pandoc` is the SlackBuild with most complicated dependencies as far as I know. They're complicated as hell, I swear.

```
$ pkque -psn pandoc
Reading packages index... Done.

sbo:office/pandoc 2.3.1
  `- pandoc (sbo, 2.3.1)
    `- haskell-zip-archive (sbo, 0.3.3)
      `- haskell-digest (sbo, 0.0.1.2)
    `- haskell-yaml (sbo, 0.11.0.0)
      `- haskell-libyaml (sbo, 0.1.0.0)
      `- haskell-enclosed-exceptions (sbo, 1.0.3)
    `- haskell-texmath (sbo, 0.11.1.1)
      `- haskell-xml (sbo, 1.3.14)
    `- haskell-temporary (sbo, 1.3)
    `- haskell-tagsoup (sbo, 0.14.7)
    `- haskell-SHA (sbo, 1.6.4.4)
    `- haskell-pandoc-types (sbo, 1.17.5.3)
      `- haskell-QuickCheck (sbo, 2.12.6.1)
        `- haskell-tf-random (sbo, 0.5)
        `- haskell-erf (sbo, 2.0.0.0)
    `- haskell-JuicyPixels (sbo, 3.3.2)
      `- haskell-mmap (sbo, 0.5.9)
    `- haskell-http-client-tls (sbo, 0.3.5.3)
      `- haskell-connection (sbo, 0.2.8)
        `- haskell-x509-system (sbo, 1.6.6)
        `- haskell-tls (sbo, 1.4.1)
          `- haskell-x509-validation (sbo, 1.6.10)
          `- haskell-x509-store (sbo, 1.6.6)
          `- haskell-x509 (sbo, 1.7.4)
            `- haskell-pem (sbo, 0.2.4)
            `- haskell-asn1-parse (sbo, 0.9.4)
          `- haskell-crypto-pubkey (sbo, 0.2.8)
            `- haskell-cryptohash (sbo, 0.11.9)
              `- haskell-cryptonite (sbo, 0.25)
            `- haskell-crypto-pubkey-types (sbo, 0.4.3)
          `- haskell-crypto-numbers (sbo, 0.2.7)
          `- haskell-cipher-rc4 (sbo, 0.1.4)
          `- haskell-cipher-des (sbo, 0.0.6)
          `- haskell-cipher-aes (sbo, 0.2.11)
            `- haskell-crypto-cipher-types (sbo, 0.0.9)
          `- haskell-asn1-encoding (sbo, 0.9.5)
            `- haskell-asn1-types (sbo, 0.3.2)
              `- haskell-hourglass (sbo, 0.2.12)
        `- haskell-socks (sbo, 0.5.6)
        `- haskell-crypto-random (sbo, 0.0.9)
          `- haskell-securemem (sbo, 0.1.10)
        `- haskell-byteable (sbo, 0.1.1)
    `- haskell-http-client (sbo, 0.5.13.1)
      `- haskell-streaming-commons (sbo, 0.2.1.0)
        `- haskell-zlib (sbo, 0.6.2)
        `- haskell-async (sbo, 2.2.1)
      `- haskell-publicsuffixlist (sbo, 0.1)
        `- haskell-idna (sbo, 0.3.0)
          `- haskell-stringprep (sbo, 1.0.0)
            `- haskell-text-icu (sbo, 0.7.0.1)
          `- haskell-punycode (sbo, 2.0)
        `- haskell-conduit (sbo, 1.3.1)
          `- haskell-void (sbo, 0.7.2)
          `- haskell-resourcet (sbo, 1.2.2)
            `- haskell-unliftio-core (sbo, 0.1.2.0)
          `- haskell-mono-traversable (sbo, 1.0.9.0)
            `- haskell-vector-algorithms (sbo, 0.8.0.1)
            `- haskell-split (sbo, 0.2.3.3)
          `- haskell-mmorph (sbo, 1.1.2)
          `- haskell-lifted-base (sbo, 0.2.3.12)
            `- haskell-monad-control (sbo, 1.0.2.3)
              `- haskell-transformers-base (sbo, 0.4.5.2)
        `- haskell-cereal (sbo, 0.5.7.0)
      `- haskell-mime-types (sbo, 0.1.0.8)
      `- haskell-memory (sbo, 0.14.18)
        `- haskell-foundation (sbo, 0.0.21)
          `- haskell-basement (sbo, 0.0.8)
      `- haskell-http-types (sbo, 0.12.2)
      `- haskell-cookie (sbo, 0.4.4)
    `- haskell-HTTP (sbo, 4000.3.11)
      `- haskell-network (sbo, 2.6.3.5)
    `- haskell-highlighting-kate (sbo, 0.6.4)
    `- haskell-filemanip (sbo, 0.3.6.3)
      `- haskell-unix-compat (sbo, 0.5.1)
    `- haskell-extensible-exceptions (sbo, 0.1.1.4)
    `- haskell-deepseq-generics (sbo, 0.2.0.0)
    `- haskell-data-default (sbo, 0.7.1.1)
      `- haskell-data-default-instances-old-locale (sbo, 0.0.1)
      `- haskell-data-default-instances-dlist (sbo, 0.0.1)
      `- haskell-data-default-instances-containers (sbo, 0.0.1)
      `- haskell-data-default-instances-base (sbo, 0.1.0.1)
      `- haskell-data-default-class (sbo, 0.1.2.0)
    `- haskell-cmark (sbo, 0.5.6)
    `- haskell-skylighting (sbo, 0.7.4)
      `- haskell-skylighting-core (sbo, 0.7.4)
        `- haskell-utf8-string (sbo, 1.0.1.1)
      `- haskell-regex-pcre-builtin (sbo, 0.94.4.8.8.35)
      `- haskell-regex-pcre (sbo, 0.94.4)
        `- haskell-regex-base (sbo, 0.93.2)
      `- haskell-pretty-show (sbo, 1.9.1)
        `- haskell-lexer (sbo, 1.0.2)
        `- happy (sbo, 1.19.9)
      `- haskell-hxt (sbo, 9.3.1.16)
        `- haskell-network-uri (sbo, 2.6.1.0)
        `- haskell-hxt-regex-xmlschema (sbo, 9.2.0.3)
        `- haskell-hxt-unicode (sbo, 9.0.2.4)
        `- haskell-hxt-charproperties (sbo, 9.2.0.1)
        `- haskell-HUnit (sbo, 1.6.0.0)
          `- haskell-call-stack (sbo, 0.1.0)
      `- haskell-case-insensitive (sbo, 1.2.0.11)
      `- haskell-base64-bytestring (sbo, 1.0.0.1)
      `- haskell-ansi-terminal (sbo, 0.8.1)
        `- haskell-colour (sbo, 2.3.4)
    `- haskell-safe (sbo, 0.3.17)
    `- haskell-hslua-module-text (sbo, 0.2.0)
      `- haskell-hslua (sbo, 1.0.1)
        `- haskell-exceptions (sbo, 0.10.0)
    `- haskell-haddock-library (sbo, 1.7.0)
    `- haskell-doctemplates (sbo, 0.2.2.1)
      `- haskell-blaze-html (sbo, 0.9.1.1)
        `- haskell-blaze-markup (sbo, 0.8.2.2)
    `- haskell-cmark-gfm (sbo, 0.1.6)
    `- haskell-aeson-pretty (sbo, 0.8.7)
      `- haskell-cmdargs (sbo, 0.10.20)
      `- haskell-aeson (sbo, 1.4.1.0)
        `- haskell-uuid-types (sbo, 1.0.3)
          `- haskell-random (sbo, 1.1)
        `- haskell-time-locale-compat (sbo, 0.1.1.5)
          `- haskell-old-locale (sbo, 1.0.0.7)
        `- haskell-th-abstraction (sbo, 0.2.8.0)
        `- haskell-syb (sbo, 0.7)
        `- haskell-blaze-builder (sbo, 0.4.1.0)
        `- haskell-base-compat (sbo, 0.10.4)
        `- haskell-attoparsec (sbo, 0.13.2.2)
          `- haskell-scientific (sbo, 0.3.6.2)
            `- haskell-vector (sbo, 0.12.0.1)
              `- haskell-primitive (sbo, 0.6.4.0)
            `- haskell-integer-logarithms (sbo, 1.0.2.2)
    `- haskell-HsYAML (sbo, 0.1.1.2)
      `- haskell-nats (sbo, 1.1.2)
      `- haskell-fail (sbo, 4.9.0.0)
    `- haskell-Glob (sbo, 0.9.3)
      `- haskell-semigroups (sbo, 0.18.5)
        `- haskell-unordered-containers (sbo, 0.2.9.0)
        `- haskell-tagged (sbo, 0.8.6)
          `- haskell-transformers-compat (sbo, 0.6.2)
        `- haskell-hashable (sbo, 1.2.7.0)
      `- haskell-dlist (sbo, 0.8.0.5)
        `- ghc (sbo, 8.4.3)
  Total dependencies: 138.
```

## Interesting fact: there is lots of cycled dependencies in Salix OS repositories
Because they're automatically generated.
```
$ pkque -psn vim-gvim
Reading packages index... Done.

slackware64:xap/vim-gvim 7.4.1938-x86_64-1
Warning: found dependency loop: glib2 <- gamin <- glib2
Warning: found dependency loop: cairo <- harfbuzz <- freetype <- fontconfig <- cairo
Warning: found dependency loop: gcc <- gmp <- gcc
Warning: found dependency loop: mesa <- freeglut <- mesa
Warning: found dependency loop: mesa <- glew <- mesa
Warning: found dependency loop: mesa <- glu <- mesa
Warning: found dependency loop: util-linux <- eudev <- util-linux
  `- vim-gvim (slackware64, 7.4.1938-x86_64-1)
    `- perl (slackware64, 5.22.2-x86_64-1)
    `- libXt (slackware64, 1.1.5-x86_64-1)
    `- gtk+2 (slackware64, 2.24.31-x86_64-1_slack14.2)
      `- pango (slackware64, 1.38.1-x86_64-1)
        `- libXft (slackware64, 2.3.2-x86_64-3)
      `- libXinerama (slackware64, 1.1.3-x86_64-2)
      `- libXcursor (slackware64, 1.1.15-x86_64-1_slack14.2)
      `- libXcomposite (slackware64, 0.4.4-x86_64-2)
      `- gnutls (slackware64, 3.6.5-x86_64-1_slack14.2)
        `- p11-kit (slackware64, 0.23.2-x86_64-1)
          `- libtasn1 (slackware64, 4.8-x86_64-1)
        `- libidn (slackware64, 1.34-x86_64-1_slack14.2)
        `- guile (slackware64, 2.0.11-x86_64-2)
          `- libunistring (slackware64, 0.9.3-x86_64-1)
          `- libtool (slackware64, 2.4.6-x86_64-5_slack14.2)
        `- gc (slackware64, 7.4.2-x86_64-3)
    `- gpm (slackware64, 1.20.7-x86_64-3)
    `- gdk-pixbuf2 (slackware64, 2.32.3-x86_64-1)
      `- libtiff (slackware64, 4.0.10-x86_64-1_slack14.2)
        `- libSM (slackware64, 1.2.2-x86_64-2)
          `- util-linux (slackware64, 2.27.1-x86_64-1)
            `- libtermcap (slackware64, 1.2.3-x86_64-7)
            `- eudev (slackware64, 3.1.5-x86_64-8)
              `- kmod (slackware64, 22-x86_64-1)
                `- python (slackware64, 2.7.16-x86_64-1_slack14.2)
                  `- sqlite (slackware64, 3.13.0-x86_64-1)
                  `- readline (slackware64, 6.3-x86_64-2)
                  `- openssl (slackware64, 1.0.2r-x86_64-1_slack14.2)
                  `- icu4c (slackware64, 56.1-x86_64-2)
                  `- gdbm (slackware64, 1.12-x86_64-1)
                  `- db48 (slackware64, 4.8.30-x86_64-2)
        `- libICE (slackware64, 1.0.9-x86_64-2)
      `- libjpeg-turbo (slackware64, 1.5.0-x86_64-1)
    `- cairo (slackware64, 1.14.6-x86_64-2)
      `- pixman (slackware64, 0.34.0-x86_64-1)
      `- mesa (slackware64, 11.2.2-x86_64-1)
        `- nettle (slackware64, 3.4.1-x86_64-1_slack14.2)
        `- llvm (slackware64, 3.8.0-x86_64-2)
          `- ncurses (slackware64, 5.9-x86_64-4)
        `- libXvMC (slackware64, 1.0.10-x86_64-1_slack14.2)
        `- libXv (slackware64, 1.0.11-x86_64-1_slack14.2)
        `- glu (slackware64, 9.0.0-x86_64-1)
        `- glew (slackware64, 1.13.0-x86_64-1)
        `- freeglut (slackware64, 2.8.1-x86_64-1)
          `- libXrandr (slackware64, 1.5.1-x86_64-1_slack14.2)
          `- libXi (slackware64, 1.7.8-x86_64-1_slack14.2)
        `- elfutils (slackware64, 0.163-x86_64-1)
          `- xz (slackware64, 5.2.2-x86_64-1)
          `- gcc-g++ (slackware64, 5.5.0-x86_64-1_slack14.2)
          `- gcc (slackware64, 5.5.0-x86_64-1_slack14.2)
            `- libmpc (slackware64, 1.0.3-x86_64-1)
              `- mpfr (slackware64, 3.1.4-x86_64-1)
            `- gmp (slackware64, 6.1.1-x86_64-1)
      `- lzo (slackware64, 2.09-x86_64-1)
      `- libxshmfence (slackware64, 1.2-x86_64-2)
      `- libdrm (slackware64, 2.4.68-x86_64-1)
        `- libpciaccess (slackware64, 0.13.4-x86_64-1)
      `- libXxf86vm (slackware64, 1.1.4-x86_64-2)
      `- libXrender (slackware64, 0.9.10-x86_64-1_slack14.2)
      `- libXext (slackware64, 1.3.3-x86_64-2)
      `- libXdamage (slackware64, 1.1.4-x86_64-2)
        `- libXfixes (slackware64, 5.0.3-x86_64-1_slack14.2)
      `- libX11 (slackware64, 1.6.6-x86_64-1_slack14.2)
        `- libxcb (slackware64, 1.11.1-x86_64-1)
        `- libXdmcp (slackware64, 1.1.2-x86_64-2)
        `- libXau (slackware64, 1.0.8-x86_64-2)
      `- fontconfig (slackware64, 2.11.1-x86_64-2)
        `- freetype (slackware64, 2.6.3-x86_64-2_slack14.2)
          `- libpng (slackware64, 1.6.27-x86_64-1_slack14.2)
          `- harfbuzz (slackware64, 1.2.7-x86_64-1)
      `- expat (slackware64, 2.2.2-x86_64-1_slack14.2)
    `- bzip2 (slackware64, 1.0.6-x86_64-1)
    `- atk (slackware64, 2.18.0-x86_64-1)
      `- glib2 (slackware64, 2.46.2-x86_64-3_slack14.2)
        `- zlib (slackware64, 1.2.11-x86_64-1_slack14.2)
        `- libffi (slackware64, 3.2.1-x86_64-1)
        `- gamin (slackware64, 0.1.10-x86_64-5)
    `- acl (slackware64, 2.2.52-x86_64-1)
      `- attr (slackware64, 2.4.47-x86_64-1)
  Total dependencies: 79.
```