import algorithm
import asyncdispatch
import asyncfutures
import browsers
import httpclient
import json
import math
import options
import sequtils
import strformat
import times

type
  Story* = JsonNode

type
  Get* = enum
    topstories, newstories, beststories, showstories, askstories

  Sort* = enum
    byrank, bytime, byscore, bycomments

const api = "https://hacker-news.firebaseio.com/v0"

## Get the ID of a story
proc id*(story: Story): int64 =
  story{"id"}.getInt()

## URL of the HN item's comments page
proc itemUrl*(story: Story): string =
  fmt"https://news.ycombinator.com/item?id={story.id}"

## Get the author of a story
proc author*(story: Story): string =
  story{"by"}.getStr()

## Get the unix timestamp when it was posted
proc time*(story: Story): int =
  story{"time"}.getInt()

## Get the number of comments for a story
proc comments*(story: Story): int =
  story{"descendants"}.getInt()

## Get the number of upvotes for a story
proc score*(story: Story): int =
  story{"score"}.getInt()

## Get the title of a story
proc title*(story: Story): string =
  story{"title"}.getStr()

## Get the external URL of a story
proc url*(story: Story): string =
  story{"url"}.getStr(story.itemUrl())

## True if the story has been deleted
proc dead*(story: Story): bool =
  story{"bool"}.getBool()

## Age of a story in hours
proc age*(story: Story): float64 =
  (now().utc.toTime().toUnix() - story.time).float64 / 3600

## Page ranking of a story
proc rank*(story: Story): float64 =
  let
    score = (story.score.float64 - 1).pow(0.8)
    age = (story.age + 2).pow(1.8)
    factor = if story.url == "": 0.4 else: 1.0
  
  score * factor / age

## Open a story's URL or item URL page in the browser
proc open*(story: Story, comments: bool=false) =
  let url =
    if comments:
      story.itemUrl
    else:
      story.url
  
  # launch the external browser
  openDefaultBrowser(url)

## A string about who posted, when, popularity, etc.
proc postStatus*(story: Story): string =
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

## Downloads and parses a JSON response from the HN API
proc hnGet*(path: string): Future[JsonNode] {.async.} =
  let resp = newAsyncHttpClient().getContent(fmt"{api}/{path}.json")
  return parseJson(await resp)

## Downloads a list of story IDs from HN
proc hnGetStoryIds*(get: Get): Future[seq[int64]] {.async.} =
  return to(await hnGet($get), seq[int64])

## Downloads and parses a single Story from HN
proc hnGetStory*(id: int64): Future[Option[Story]] {.async.} =
  let json = await hnGet(fmt"item/{id}")

  # check to make sure the story downloaded
  if json.kind != JNull:
    return some(json.Story)

## Downloads a list of stories in parallel given their IDs
proc hnGetStories*(get: Get, progress: proc(n, m: int) {.gcsafe.}=nil): Future[seq[Story]] {.async.} =
  var futures = newSeq[Future[Option[Story]]]()
  var n = 0

  # download each story
  for id in await hnGetStoryIds(get):
    var f = hnGetStory(id)

    # when done, update the progress
    f.callback = proc() =
      n += 1
      
      if not progress.isNil:
        progress(n, futures.high + 1)
    
    # create a list of all the futures
    futures.add(f)

  # send an initial progress update
  if not progress.isNil:
    progress(0, futures.high + 1)

  # wait for all the stories to finish
  var stories = await all(futures)

  # remove any dead stories (none = dead by default)
  stories.keepIf(proc(s: Option[Story]): bool = not s.map(dead).get(true))
  
  # pull all the remaining stories out of the option
  return stories.map(proc(s: Option[Story]): Story = s.get())

## Sort using a sort compare enumeration
proc sort*(stories: var openArray[Story], by: Sort=byrank) =
  case by
  of byrank: sort(stories, proc(a, b: Story): int = cmp(b.rank(), a.rank()))
  of bytime: sort(stories, proc(a, b: Story): int = cmp(b.time, a.time))
  of byscore: sort(stories, proc(a, b: Story): int = cmp(b.score, a.score))
  of bycomments: sort(stories, proc(a, b: Story): int = cmp(b.comments(), a.comments()))
