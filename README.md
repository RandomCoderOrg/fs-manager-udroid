# fs-manager-udroid

A tool manage common things with ubuntu-on-android
& some scripts and linux apps

[![CodeFactor](https://www.codefactor.io/repository/github/randomcoderorg/fs-manager-udroid/badge)](https://www.codefactor.io/repository/github/randomcoderorg/fs-manager-udroid)

## Manual installation

```bash
git clone -b revamp-v2.5 https://github.com/RandomCoderOrg/fs-manager-udroid.git
cd fs-manager-udroid
bash install.sh
```

## Usage

three main arguments `install`, `login`, `remove`

### install ( `-i` )

```bash
udroid -i jammy:raw
```

install argument takes a strings of two words seperated by `:` left side is suite name and right is varient name

More Avalible examples

```bash
udroid -i impish:raw
udroid -i impish:xfce
udroid -i impish:mate
```

```bash
udroid -i focal:xfce4
```

###### help

```cmd
udroid [ install| --install ] [<options>] [<suite>]:[<varient>]
installs udroid distros
options:
  -h, --help    show this help message and exit
  --no-verify-integrity  do not verify integrity of filesystem

example:
  udroid install jammy:raw
  udroid install --install jammy:raw
```

### login (`login`)

```bash
udroid --login jammy:raw
# or
udroid login jammy:raw # same as above
```

###### help
```cmd
udroid [ login| --login ] [<options>] <suite>:<varient> <cmd>
login to a suite

options:
  -h, --help:         show this help message and exit
  --user:               Allows the user to specify the login user for the filesystem.
  --name: Allows        the user to specify a custom name for the filesystem to install
  --bind or -b:         Allows the user to specify extra mount points for the filesystem.
  --isolated:           Creates an isolated environment for the filesystem.
  --fix-low-ports:      Fixes low ports for the filesystem.
  --no-shared-tmp:      Disables shared tmp for the filesystem.
  --no-link2symlink:    Disables link2symlink for the filesystem.
  --no-sysvipc:         Disables sysvipc for the filesystem.
  --no-fake-root-id:    Disables fake root id for the filesystem.
  --no-kill-on-exit:    Disables kill on exit for the filesystem.

<cmd>:
  command to run in the filesystem and exit
```

> WIP

### remove (`remove`)

```bash
udroid remove jammy:raw
```

###### help

```cmd
udroid [ remove| --remove ] <distro>
removes udroid distros
example:
  udroid remove jammy:raw
  udroid remove --remove jammy:raw
```

> Download cache is ignored

## Contributing

for now there is no guide for contributing. try to look at code and make a pull request if you have any corrections or improvements ( 💟 )
