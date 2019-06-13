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
  proc setConsoleOutputCP(page: int): WINBOOL
    {.stdcall, dynlib: "kernel32", importc: "SetConsoleOutputCP".}

  # enable virtual terminal processing
  if getConsoleMode(handle, addr(mode)) != 0:
    discard setConsoleMode(handle, mode or 4)
  
  # enable code page UTF-8
  discard setConsoleOutputCP(65001)

# handle all other platforms
enableTrueColors()

# reset the console colors and attributes on exit
addQuitProc(resetAttributes)
