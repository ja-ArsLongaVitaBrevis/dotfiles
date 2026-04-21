# INSTALLATION

https://elixir-lang.org/install.html

When installing Elixir, Erlang is generally installed automatically for you. [@see](https://elixir-lang.org/install.html#installing-erlang)

Keep in mind that each Elixir version supports specific Erlang/OTP versions. [See the supported versions](https://elixir-lang.org/docs).

# [VERSION MANAGERS](https://elixir-lang.org/install.html#version-managers)

## ELIXIR VERSION MANAGER:

[Kiex](https://github.com/taylor/kiex)

## ERLANG VERSION MANAGER:

[Kerl](https://github.com/kerl/kerl)

### HOW TO INSTALL A VERSION

FIRST: INSTALL `ERLANG`

[Using Kerl](https://elixir-lang.org/install.html)

```sh
# 1.
$ kerl list releases

# 2.
$ kerl build <version> <version_alias>
##  e.g. _$ kerl build 27.0 27.0_

# 3.
$ kerl list builds

# 4.
$ kerl install <version> /usr/local/lib/erlang/<version>
##  e.g. _$ kerl install 27.0 /usr/local/lib/erlang/27.0_

# 5. ACTIVATE VERSION IN CURRENT SHELL
$ . /usr/local/lib/erlang/<version>/activate

# 6. VERIFY VERSION
$ erl -version

## The current active installation is:
$ kerl active
/usr/local/lib/erlang/27.0
```

SECOND: INSTALL `ELIXIR` AND USE IT

```sh
# 1. list Elixir version available
kiex list

# 2. Install desired version
kiex use elixir-1.16.0-26
```

# CONCEPTS

PATTERN MATCHING

FUNCTIONS

- guard clause: https://elixirschool.com/en/lessons/basics/functions#guards-6
