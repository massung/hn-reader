import reader/[console, hn]

import asyncdispatch
import algorithm
import browsers
import colors
import options
import parseopt
import sequtils
import strformat
import strutils
import sugar
import terminal
import unicode

type
  ReaderCmd = enum
    ## Possible command line actions.
    help, load, sort, find, next, open, read, quit

# constant colors used for the terminal
let
  indexColor = ansiForegroundColorCode(rgb(0x33, 0x33, 0x33))
  titleColor = ansiForegroundColorCode(rgb(0xdd, 0x77, 0x33))
  linkColor = ansiForegroundColorCode(rgb(0x33, 0x33, 0xdd))
  statusColor = ansiForegroundColorCode(rgb(0x33, 0x33, 0x33))
  promptColor = ansiForegroundColorCode(rgb(0x33, 0xdd, 0xdd))
  warnColor = ansiForegroundColorCode(rgb(0xdd, 0x33, 0x33))

# global list of loaded stories and current view
var stories: seq[Story]
var view: iterator(): tuple[story: Story, i: int]

proc showHelp() =
  ## Show usage output.
  echo "Hacker News | reader\n"
  echo "COMMANDS"
  echo "  load    [top|new|best|show|ask]     - reload stories (defaul=top)"
  echo "  sort    [rank|time|score|comments]  - sort stories (default=rank)"
  echo "  find    [topic]                     - search stories"
  echo "  open    [n]                         - open story url in browser"
  echo "  read    [n]                         - open comments in browser"
  echo "  next                                - list next page of stories"
  echo "  help"
  echo "  quit"

proc warn(s: string) =
  ## Output a warning text.
  echo &"{warnColor}{s}\n"
  resetAttributes()

proc resetView() =
  ## Reset the view into the story list.
  view = iterator(): tuple[story: Story, i: int] =
    for i, story in stories.pairs:
      yield (story, i)

const progressBar = '#'.repeat(50)

proc showProgress(n, m: int) {.gcsafe.} =
  ## Display a simple progress bar growing.
  let arrow = progressBar[0..<(n * 50 / m).int]

  write(stdout, &"Downloading stories from HN [{arrow:<50}] {n}/{m}\r")

proc downloadStories(get: Get) =
  ## Download all stories, sort then, and reset the view.
  stories = waitFor hnGetStories(get, progress=showProgress)

  # clear the progress bar
  eraseLine()

  # sort them appropriately
  case get
  of newstories: stories.sort(bytime)
  of askstories: stories.sort(bycomments)
  else: stories.sort(byrank)

  # reset and echo
  resetView()

proc echoStory(n: int, story: Story) =
  ## Output a story with a given index.
  echo &"{indexColor}{n:>3}. {titleColor}{story.title}"
  echo &"     {linkColor}{story.url}"
  echo &"     {statusColor}{story.postStatus}\n"

## Show the next set of stories
proc echoStories() =
  let n = max(1, ((terminalHeight() - 6) / 4).int)

  for i in 0..<n:
    let next = view()

    # output the next story
    if finished(view):
      if i == 1:
        warn("No more stories; reload or sort to reset")
    else:
      echoStory(next.i + 1, next.story)

proc prompt(): string =
  ## Show the prompt and wait for user input.
  write(stdout, fmt"{promptColor}> ")
  resetAttributes()

  # read user input, parse it as a set of options
  readLine(stdin).string

proc parseCmd[T: enum](s: string, def: T): T =
  ## Parse a string -> an enum, but allow for shortened matches.
  for e in low(T)..high(T):
    let n = min(high(s), high($e))

    if cmpIgnoreCase(s, ($e)[..n]) == 0:
      return e

  # indicate that it was unknown, using something else instead
  warn(fmt"Unknown option: {s}; defaulting to {$def}")

  return def

proc openStory(opts: iterator(): string, comments: bool=false) =
  ## Open a story to its URL link or comments page.
  try:
    stories[opts().parseInt() - 1].open(comments=comments)
  except ValueError:
    warn("Invalid story index!")
  except IndexError:
    warn("Invalid story index!")

proc loadStories(opts: iterator(): string) =
  ## Load stories.
  let get = parseCmd[Get](opts(), topstories)

  # re-download and echo stories
  downloadStories(get)
  echoStories()

proc sortStories(opts: iterator(): string) =
  ## Sort the stories.
  stories.sort(parseCmd[Sort]("by" & opts(), byrank))

  # reset and echo
  resetView()
  echoStories()

proc findStories(opts: iterator(): string) =
  ## Search loaded stories for possible terms.
  let terms = unicode.split(opts()).map(proc (s: string): string = unicode.toLower(s))

  # keep stories that match any of the terms
  stories.keepIf((s) => terms.any((t) => unicode.toLower(s.title).contains(t)))

  # reset and echo
  resetView()
  echoStories()

proc exec(opts: iterator (): string) =
  ## Execute whatever comment was entered by the user.
  case parseCmd[ReaderCmd](opts(), help)
  of help: showHelp()
  of load: loadStories(opts)
  of sort: sortStories(opts)
  of find: findStories(opts)
  of open: openStory(opts, comments=false)
  of read: openStory(opts, comments=true)
  of next: echoStories()
  of quit: quit()

#
# Run program
#

downloadStories(topstories)
echoStories()

# process user input forever
while true:
  let it = iterator (): string =
    for word in unicode.strip(prompt()).split(Whitespace, 1):
      yield word

  it.exec()
