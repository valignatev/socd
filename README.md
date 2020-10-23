# SOCD cleaner for epic gamers

## Install
Grab the latest version from [Releases page](https://github.com/valignatev/socd/releases).

## Why do I need it?

SOCD stands for simultaneous opposite cardinal direction. Basically, what'll
happen if you press "left" and "right" at the same time or "left" while holding "right", and vise versa.
Every game handles it differently. Some set such cases to "neutral", some have "last win", and
some games just don't know what to do and do whatever.

Devices like smashbox usually have settings that you can toggle to have the behavior you
want. This program basically allows you to do the same but with your keyboard.
(WIP, for now the only option is "last wins").

Use it at your own caution, especially if you do competitive gaming because
some communities require to use something particular and ban any other alternatives.
There you go, I warned you. Enjoy!

## Compiling from source code

Some antiviruses might complain at prebuilt executable as if it has viruses.
It doesn't, but you should never run untrusted code on your machine
if you don't know what you are doing.

You should be able to compile it from source with any C compiler on Windows.
There is no external dependencies outside of builtin windows libraries.
Couple examples:

### With Clang
Download [clang](https://releases.llvm.org/download.html) and run in the project root

```sh
clang -o2 socd_cleaner.c -o socd_cleaner.exe
```

### With Visual Studio Build Tools

Install [Visual Studio Build Tools](https://docs.microsoft.com/en-us/cpp/build/walkthrough-compile-a-c-program-on-the-command-line?view=vs-2019) (tm).
Then run in the project root

```sh
cl /O2 socd_cleaner.c
```

## LICENSE
MIT or Apache 2.0, whatever you like

