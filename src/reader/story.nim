import browsers
import json
import options
import strformat
import times

type
  Story* = object
    id*: int64
    author*: string
    time*: int
    comments*: int
    score*: int
    title*: string
    url*: string
    dead*: bool

proc itemUrl*(id: int64): string =
  ## Get the HN URL for a the comments page of a story.
  fmt"https://news.ycombinator.com/item?id={id}"

proc newStory*(json: JsonNode): Option[Story] =
  ## Parse a story from a JSON node.
  if json.kind != JNull:
    let id = json{"id"}.getInt()
    let story = Story(
      id: id,
      author: json{"by"}.getStr(),
      title: json{"title"}.getStr(),
      url: json{"url"}.getStr(id.itemUrl),
      score: json{"score"}.getInt(),
      time: json{"time"}.getInt(),
      comments: json{"descendants"}.getInt(),
      dead: json{"dead"}.getBool(),
    )

    result = some(story)

proc age*(story: Story): float64 =
  ## Age of a story in hours.
  (now().utc.toTime().toUnix() - story.time).float64 / 3600

proc open*(story: Story, comments: bool=false) =
  ## Open a story's URL or item URL page in the browser.
  let url =
    if comments or story.url == "":
      story.id.itemUrl
    else:
      story.url

  # launch the external browser
  openDefaultBrowser(url)

proc postStatus*(story: Story): string =
  ## A string about who posted, when, popularity, etc.
  let
    age = story.age()
    ago =
      if age < 1: "less than an hour"
      elif age < 2: "an hour"
      elif age < 24: fmt"{age.int} hours"
      elif age < 168: fmt"{(age / 24).int} days"
      elif age < 672: fmt"{(age / 168).int} weeks"
      elif age < 8760: fmt"{(age / 672).int} months"
      else: fmt"{(age / 8760).int} years"

  fmt"posted by {story.author} {ago} ago ({story.score} votes) - {story.comments} comments"
