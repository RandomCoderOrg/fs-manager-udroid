# Extra mounts

Extra mounts are a way to add extra accesible paths to proot containers. This is useful for example if you want to access files from your sdcard or other storage locations.

## How to add extra mounts

There are two ways to add extra mounts:

1. traditional `proot-distro` way to use `--bind` argument with paths to bind in format `<path in host>:<path to bind in container>` before the name of the distribution.
2. custom configaration file named `udroid_proot_mounts` in comtainer root ( at `\`) with paths to bind in format `<path in host>:<path to bind in container>`

## Example

### for 1. way

- single custom bind

```bash
udroid -l --bind /sdcard:/sdcard jammy:raw
```

- multiple custom binds

```bash
udroid -l --bind /sdcard:/sdcard --bind /sdcard/Music:/root/ext_music jammy:raw
```

> Note the way `--bind` is used before the name of the distribution `jammy:raw`
>

## for 2. way

these binds are written in a file named `udroid_proot_mounts` in the root of the container (at `\`).

> Note that for some udroid builds there may be pre-defined custom mounts points in `udroid_proot_mounts` file. If you want to add your own mounts, you should add them to the end of the file. ( carefull while using redirections to overwrite the file, you may lose the pre-defined mounts )

### Example 2.1

lets say we want to bind `/sdcard` and `/sdcard/Music` to `/sdcard` and `/root/ext_music` in the container.

contents of file `udroid_proot_mounts`:

```bash
/sdcard:/sdcard
/sdcard/Music:/root/ext_music
```
