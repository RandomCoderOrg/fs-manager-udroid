# fs-manager-udroid

A tool manage common things with ubuntu-on-android
& some scripts and linux apps

## Manual installation

```bash
git clone https://github.com/RandomCoderOrg/fs-manager-udroid.git
cd fs-manager-udroid
bash install.sh
```

## Usage

```cmd
udroid <option> [<options>] [<suite>]:[<varient>]

options:
  install, -i [<options>] <suite>:<varient>  install a distro
  remove, --remove <suite>:<varient>    remove a distro
  reset, --reset <suite>:<varient>      reinstalls a distro
  list, --list [options]                list distros
  build, --build [options]              build a raw distro using fs-cook
  login, --login <suite>:<varient>      login to a distro
  upgrade, --upgrade                    upgrade udroid scripts
  help, --help                          show this help message and exit
  --update-cache                        update cache from remote  
  --clear-cache                         clear downloaded cache      
```

three main arguments `install`, `login`, `remove`

### install ( `-i` )

```bash
udroid -i jammy:raw
```

install argument takes a strings of two words seperated by `:` left side is suite name and right is varient name

More Avalible examples

```bash
udroid -i jammy:xfce
udroid -i jammy:mate
```

```bash
udroid -i focal:xfce4
```

###### help

```cmd
udroid [ install| -i ] [<options>] [<suite>]:[<varient>]
installs udroid distros
options:
  -h, --help    show this help message and exit
  --no-verify-integrity  do not verify integrity of filesystem

example:
  udroid install jammy:raw
  udroid install --install jammy:raw
```

> `--install` with no extra options install best picked distro ( deprecated )

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
  --ashmem-memfd | --memfd     enable support for memfd emulation through ashmem ( experimental )
  --fix-low-ports:      Fixes low ports for the filesystem.
  --no-shared-tmp:      Disables shared tmp for the filesystem.
  --no-link2symlink:    Disables link2symlink for the filesystem.
  --no-sysvipc:         Disables sysvipc for the filesystem.
  --no-fake-root-id:    Disables fake root id for the filesystem.
  --no-cap-last-cap:    Disables cap last cap fix mount for the filesystem.(only per session)
  --no-kill-on-exit:    Disables kill on exit for the filesystem.

<cmd>:
  command to run in the filesystem and exit
```

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

### build (`build`)

# Experimental feature !!

```cmd
udroid [ build| --build ] [<options>] <suite>
builds a raw distro using fs-cook

options:
  -h, --help             show this help message and exit
  -l, --list             list avaliable distros for building
  --not-upgrade          do not upgrade packages after building distro
  --set-best-to-build    build the default raw distro (jammy)
  --setup-user <username>    setup a user when building distro, use with --password
  --password <password>      set the password of the user
example:
  udroid build jammy
  udroid build --build jammy
```

> Still in development!

## Contributing

for now there is no guide for contributing. try to look at code and make a pull request if you have any corrections or improvements ( 💟 )
