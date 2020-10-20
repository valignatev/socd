# SOCD cleaner for epic gamers

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

Windows might yell at prebuilt executable as if it has viruses. It doesn't, but you should never
run untrasted executables on your machine if you don't know what you are doing.

You should be able to compile it from source with any C compiler on Windows.
There is no external dependencies outside of builtin windows libraries.

For example, install [Visual Studio Build Tools](https://docs.microsoft.com/en-us/cpp/build/walkthrough-compile-a-c-program-on-the-command-line?view=vs-2019) (tm).
Then run
```
cl socd_cleaner.c
```
in the repository root.

## LICENSE
MIT

