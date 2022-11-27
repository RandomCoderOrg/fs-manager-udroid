# Adding shared folders

In case you want to bind directories directly from host's file system to proot container as shared folders, you can use this.

## How to apply

You can use the traditional `proot-distro` method to use `--bind` argument with paths to bind in syntax `<path in host>:<path to bind in container>` before the name of the distribution. Or custom configuration file named `udroid_proot_mounts` in container root ( at `\`) with paths to bind in format `<path in host>:<path to bind in container>`

### By using argument

In case of binding directly while launching udroid. For adding multiple bindings you can use `--bind` over and over again

```bash
udroid -l --bind /sdcard:/sdcard jammy:raw
```

> Note the way `--bind` is used before the name of the distribution `jammy:raw`
>

### By creating config file

Those binds are written in a file named `udroid_proot_mounts` in the root of the container (at `\`).

> Note that for some udroid builds there may be pre-defined custom mounts points in `udroid_proot_mounts` file. If you want to add your own mounts, you should add them to the end of the file. ( carefull while using redirections to overwrite the file, you may lose the pre-defined mounts )

If adding new binds, you can put directory names with paths like this in `udroid_proot_mounts`
```bash
/sdcard:/sdcard
/sdcard/Music:/root/ext_music
```

### Note
Due to android limitations, you cannot get external sdcard paths working like this for non-rooted devices.
