# ArcOS Repository

This repository contains packages and PKGBUILDs for **ArcOS**, my Arch Linux-based distribution.

ArcOS uses this repository as its primary package repository for custom ArcOS packages.

Repository:

[https://github.com/zcharka/arcos-repo](https://github.com/zcharka/arcos-repo?utm)

## Repository Configuration

Add the following to `/etc/pacman.conf`:

```ini
[arcos-repo]
SigLevel = Never
Server = https://zcharka.github.io/arcos-repo/$arch
```

Then synchronize the package databases:

```bash
sudo pacman -Sy
```

You can install packages from the repository with:

```bash
sudo pacman -S <package-name>
```
