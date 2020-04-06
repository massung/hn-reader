import reader/[console, hn, story]

import asyncdispatch
import algorithm
import browsers
import colors
import iup
import options
import sequtils
import strformat
import strutils
import sugar
import terminal
import unicode

type
  ReaderCmd = enum
    ## Possible command line actions.
    help, load, next, open, read, quit

# constant colors used for the terminal
let
  indexColor = ansiForegroundColorCode(rgb(0x33, 0xdd, 0xdd))
  titleColor = ansiForegroundColorCode(rgb(0xdd, 0x77, 0x33))
  linkColor = ansiForegroundColorCode(rgb(0x33, 0x33, 0xdd))
  statusColor = ansiForegroundColorCode(rgb(0x77, 0x77, 0x77))
  promptColor = ansiForegroundColorCode(rgb(0x33, 0xdd, 0xdd))
  warnColor = ansiForegroundColorCode(rgb(0xdd, 0x33, 0x33))

# global list of loaded stories and current view
var stories: seq[Story]
var view: iterator(): int64

proc showHelp() =
  ## Show usage output.
  echo "Hacker News | reader\n"
  echo "COMMANDS"
  echo "  load    [top|new|best|show|ask]     - reload stories (defaul=top)"
  echo "  open    [n]                         - open story url in browser"
  echo "  read    [n]                         - open comments in browser"
  echo "  next                                - list next page of stories"
  echo "  help"
  echo "  quit"

proc warn(s: string) =
  ## Output a warning text.
  echo &"{warnColor}{s}\n"
  resetAttributes()

proc downloadStories(get: Get) =
  ## Download all stories, sort then, and reset the view.
  stories.setLen(0)
  view = iterator(): int64 =
    for id in waitFor hnGetStoryIds(get):
      yield id

proc echoStory(n: int, story: Story) =
  ## Output a story with a given index.
  echo &"{indexColor}{n:>3}. {titleColor}{story.title}"
  echo &"     {linkColor}{story.url}"
  echo &"     {statusColor}{story.postStatus}\n"

## Show the next set of stories
proc echoStories() =
  let n = max(1, ((terminalHeight() - 6) / 4).int)
  let m = len(stories)

  # take the next n ids from the view
  var ids = newSeqOfCap[int64](n)
  for i in 0..<n:
    if finished(view):
      break
    ids.add(view())

  # check for nothing more to load
  if len(ids) == 0:
    warn("No more stories; load to get a new list")

  # download the next batch of stories
  stories = concat(stories, waitFor hnGetStories(ids))

  # output the stories to terminal
  for i, story in stories[m..stories.high].pairs:
    echoStory(m + i + 1, story)

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

proc getStory(opts: iterator(): string): Option[Story] =
  ## Return a story by index provided.
  try:
    result = some(stories[opts().parseInt() - 1])
  except ValueError:
    warn("Invalid story index!")
  except IndexError:
    warn("Invalid story index!")

proc openStory(opts: iterator(): string, comments: bool=false) =
  ## Open a story to its URL link or comments page.
  opts.getStory().map((s: Story) => s.open(comments=comments))

proc loadStories(opts: iterator(): string) =
  ## Load stories.
  let get = parseCmd[Get](opts(), topstories)

  # re-download and echo stories
  downloadStories(get)
  echoStories()

proc exec(opts: iterator (): string) =
  ## Execute whatever comment was entered by the user.
  case parseCmd[ReaderCmd](opts(), help)
  of help: showHelp()
  of load: loadStories(opts)
  of open: openStory(opts, comments=false)
  of read: openStory(opts, comments=true)
  of next: echoStories()
  of quit: quit()

#
# Run program
#

when isMainModule:
  downloadStories(topstories)
  echoStories()

  # process user input forever
  while true:
    let it = iterator (): string =
      for word in unicode.strip(prompt()).split(Whitespace, 1):
        yield word

    it.exec()
