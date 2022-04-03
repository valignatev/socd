@echo off

set compiler_flags= -nologo -FC -Zi

if "%1" == "release" (
   set compiler_flags=%compiler_flags% /O2
) else (
  set compiler_flags=%compiler_flags% /Od
)

cl %compiler_flags% socd_cleaner.c
