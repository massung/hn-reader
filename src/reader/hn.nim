import asyncdispatch
import asyncfutures
import httpclient
import json
import options
import sequtils
import story
import strformat

type
  Get* = enum
    ## Defines the end-point within the HN API for a list of story IDs.
    topstories, newstories, beststories, showstories, askstories

const api = "https://hacker-news.firebaseio.com/v0"

proc hnGet*(path: string): Future[JsonNode] {.async.} =
  ## Downloads and parses a JSON response from the HN API.
  let resp = newAsyncHttpClient().getContent(fmt"{api}/{path}.json")
  return parseJson(await resp)

proc hnGetStoryIds*(get: Get): Future[seq[int64]] {.async.} =
  ## Downloads a list of story IDs from HN.
  return to(await hnGet($get), seq[int64])

proc hnGetStory*(id: int64): Future[Option[Story]] {.async.} =
  ## Downloads and parses a single Story from HN.
  return newStory(await hnGet(fmt"item/{id}"))

proc hnGetStories*(ids: seq[int64]): Future[seq[Story]] {.async.} =
  ## Downloads a list of stories in parallel given their IDs.
  let stories = await all(ids.mapIt(it.hnGetStory))

  # keep only valid stories
  return stories.filterIt(it.isSome).mapIt(it.get).filterIt(not it.dead)
