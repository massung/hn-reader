# Hacker News | reader
#
# Copyright (c) Jeffrey Massung
# All rights reserved.
#

import terminal

# fix for enableTrueColors on Windows 10
when defined(windows):
  import winlean

  var 
    handle = getStdHandle(STD_OUTPUT_HANDLE)
    mode = 0.DWORD

  # declare console functions
  proc getConsoleMode(hConsoleHandle: Handle, dwMode: ptr DWORD): WINBOOL
    {.stdcall, dynlib: "kernel32", importc: "GetConsoleMode".}
  proc setConsoleMode(hConsoleHandle: Handle, dwMode: DWORD): WINBOOL
    {.stdcall, dynlib: "kernel32", importc: "SetConsoleMode".}

  # enable virtual terminal processing
  if getConsoleMode(handle, addr(mode)) != 0:
    discard setConsoleMode(handle, mode or 4)

# handle all other platforms
enableTrueColors()

# reset the console colors and attributes on exit
system.addQuitProc(resetAttributes)
