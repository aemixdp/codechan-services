#!/bin/env node
express = require "express"
fs = require "fs"
Redis = require "redis"
Slack = require "slack-client"
TOKEN = require "./token.js"
REDIS = require "./redis_config.js"
PASSWORD = require "./password.js"

IP = process.env.OPENSHIFT_NODEJS_IP || "127.0.0.1"
PORT = process.env.OPENSHIFT_NODEJS_PORT || 8080
TERMINATION_HANDLERS = [
  "SIGHUP", "SIGINT", "SIGQUIT", "SIGILL", "SIGTRAP", "SIGABRT",
  "SIGBUS", "SIGFPE", "SIGUSR1", "SIGSEGV", "SIGUSR2", "SIGTERM"
]

TERMINATION_HANDLERS.forEach (sig) ->
  process.on sig, ->
    console.log("#{Date()}: Received #{sig} - terminating logservice ...")
    process.exit(1)
    console.log("#{Date()}: Logservice stopped.")

process.on "exit", ->
  console.log("#{Date()}: Logservice stopped.")

cache = "index.html": fs.readFileSync("./index.html")
server = express.createServer()
redis = Redis.createClient(REDIS.PORT, REDIS.IP, auth_pass: REDIS.PASS)

server.use(express.compress())
server.use(express.static(__dirname + "/public"))

server.get "/", (req, res) ->
  res.setHeader("Content-Type", "text/html")
  res.send(cache["index.html"])

server.get "/messages", (req, res) ->
  if req.query.pw != PASSWORD
    res.status(403).send("Access denied!")
  else
    redis.zrangebyscore ["log", req.query.from, req.query.to, "WITHSCORES"], (error, data) ->
      if error
        console.log("Error (retrieving messages from redis) - #{error}")
      res.status(200).send(data)

server.listen PORT, IP, ->
  console.log("%s: logservice started on %s:%d ...", Date(Date.now()), IP, PORT)

slack = new Slack(TOKEN, true, true)

slack.on 'raw_message', (message) ->
  if message.reply_to
    return
  try
    switch message.type
      when "presence_change"
        data = ["presence_change", message.user, slack.getUserByID(message.user).name, message.presence]
      when "user_typing"
        data = ["user_typing", message.user, slack.getUserByID(message.user).name,
          message.channel, slack.getChannelGroupOrDMByID(message.channel).name]
      when "message"
        cid = message.channel
        cname = slack.getChannelGroupOrDMByID(message.channel).name
        switch message.subtype
          when "bot_message"
            data = ["bot_message", message.username, cid, cname, message.text, message.ts]
          when "message_changed"
            edit = message.message.edited
            if edit
              data = ["message_changed", edit.user, slack.getUserByID(edit.user).name,
                cid, cname, message.message.text, message.message.ts, message.ts]
            else # fresh messages with attachments are coming as 'message_changed' but without 'edited' field
              msg = message.message
              data = ["message", msg.user, slack.getUserByID(msg.user).name, cid, cname, msg.text, msg.ts]
          when "message_deleted"
            data = ["message_deleted", cid, cname, message.deleted_ts, message.ts]
          else
            data = ["message", message.user, slack.getUserByID(message.user).name,
              cid, cname, message.text, message.ts]
      else return
    redis.zadd ["log", Date.now(), JSON.stringify(data)], (error, count) ->
      if error
        console.log("Error (saving data to redis) - #{error}")
  catch error
    console.log("Error (processing slack message) - #{error}")
    console.log(".. raw message: #{JSON.stringify(message)}")

slack.login()