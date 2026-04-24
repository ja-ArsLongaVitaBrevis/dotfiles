# Python

> Back to → [dotfiles root](../README.md)

Useful references and workflow notes for Python on macOS.

---

## Virtual environment

- https://docs.python.org/3/library/venv.html
- https://packaging.python.org/en/latest/tutorials/installing-packages/

## Installing deps in `.venv` — workflow

Follow steps in order:

1. CREATING .VENV

```sh
python3 -m venv /path/to/new/virtual/environment/.venv
python3 -m venv ./.venv
#  notice that `.venv` is a directory, and the name can be different (name is given by you)
```

2. ACTIVATION / DEACTIVATION

```sh
source .venv/bin/activate
```

```sh
deactivate
```

3. INSTALLING DEPENDENCIES

```sh
python3 -m pip install -r /path/to/requirements.txt
python3 -m pip install -r ./requirements.txt
```

## Version managers

Consider [pyenv](https://github.com/pyenv/pyenv) for managing multiple Python versions. It can be lazy-loaded with the same stub pattern used for `nvm` in this repo — see [the lazy-loading section in the root README](../README.md#lazy-loading-pattern).
