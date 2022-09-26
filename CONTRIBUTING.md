# The contribution guidelines

Hey!, Thanks for contributing to this project. if you are in this step that means you're probably want to contribute to this project or just exploring :).

This page will guide you through the project structure and basic rules ( that keep project structure clean and understandable )

> this repo main script is referenced as **udroid** in this page.

## Directories

```cmd
.
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── dist.json
├── etc
├── install.sh
├── LICENSE
├── README.md
├── targ.map
├── udroid
└── version
```

All mainline code related to udroid will be stored in **udroid** directory. and the rest of em are either archiving or documentation. on expanding the **udroid** directory you'll two direcotries **src** and **test**.

> By name src for the source code & test for the test code.

## How udroid works

udroid in this repo is a script to manage things like installing, login of a tarball.

the main script is in `udroid/src/udroid.sh`. which will be executed when user executes `udroid` in terminal.

Basic things udroid supposed to handle are:

1. **install**: to dowload & install the linux tarball
2. **login**: to login to the linux filesystem by chaning root with the help of `proot`
3. **remove**: to remove the linux tarball installation

> if you ever tried `proot-distro` you'll get the idea of how udroid works.
> Additional functionality will like **backup** and **restore** need more work (If you have any ideas feel free to suggest us!).

## Dev FAQ?

### How this sript differ from `proot-distro`?

> the main for this project is to provide a simple script to install and use linux distros on android. and the main difference is that udroid is a single script which is easy to understand and modify. from the developer point of view now we can ship new feature faster without patching things to work specially with `proot-distro`. with this users can be able to install custom linux distro with ease.

### What languages are used in this project?

> the main script is written in `bash` and the test script (some of em) is written in `python` & `bash` (because it's easy to write test in python).

### What to contribute?

> you can contribute by writing documentation, writing diffrent test cases, new features, creating issues about bugs. even a typo fix is a contribution. You can ping us on discord if you have any questions.

### is the project accept Hacktoberfest PRs?

> Yes, we accept Hacktoberfest PRs. but we'll only accept PRs that are related to the project. if you have any questions ping us on discord.

### How can I contribute?

for starters, you can follow the basic GitHub guide [here](https://docs.github.com/en/get-started/quickstart/hello-world).

When submitting a pull request make sure to add a good title and description to it. using images is encouraged too

Always write a clear log message for your commits. One-line messages are fine for small changes, but bigger changes should look like this:

```cmd
$ git commit -m "A summary of the commit
> 
> A paragraph describing what changed and its impact."
```

## Coding conventions

Start reading our code and you'll get the hang of it. We optimize for readability:

- use 4-6 spaces for intending to bash
- strictly use `lf` for line ending
- check the code with `shellcheck` or `pylint` before commiting.
- follow directory rules in all cases ( images should go in directories named similar to `assets` or `img` )
- use code beautification tools for better look and readability
- This is open-source software. Consider the people who will read your code, and make it look nice for them. It's sort of like driving a car: Perhaps you love doing donuts when you're alone, but with passengers, the goal is to make the ride as smooth as possible.
