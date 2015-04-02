#!/bin/env node

express = require "express"
fs = require "fs"
querystring = require "querystring"
https = require "https"
TOKEN = require "./token.js"

IP = process.env.OPENSHIFT_NODEJS_IP || "127.0.0.1"
PORT = process.env.OPENSHIFT_NODEJS_PORT || 8080
LOGFILE_PATH = "./log.json"
TERMINATION_HANDLERS = [
  "SIGHUP", "SIGINT", "SIGQUIT", "SIGILL", "SIGTRAP", "SIGABRT",
  "SIGBUS", "SIGFPE", "SIGUSR1", "SIGSEGV", "SIGUSR2", "SIGTERM"
]

TERMINATION_HANDLERS.forEach (sig) ->
  process.on sig, ->
    console.log("#{Date()}: Received #{sig} - terminating logservice ...")
    process.exit(1)
    console.log("#{Date()}: Regservice stopped.")

process.on "exit", ->
  console.log("#{Date()}: Regservice stopped.")

cache = "index.html": fs.readFileSync("./index.html")
server = express.createServer()

server.use(express.compress())
server.use(express.static(__dirname + "/public"))

server.get "/", (req, res) ->
  res.setHeader("Content-Type", "text/html")
  res.send(cache["index.html"])

server.get "/invite", (req, res) ->
  email = req.query.email
  data = querystring.stringify
    "token": TOKEN
    "email": email
    "set_active": true
    "_attempts": 1
  options =
    host: "codechan.slack.com"
    port: "443"
    path: "/api/users.admin.invite?t=" + (new Date).getTime().toString()
    method: "POST"
    headers:
      "Content-Type": "application/x-www-form-urlencoded"
      "Content-Length": data.length
  console.log("Sending invite to '#{email}' (using token = '#{TOKEN}')...")
  req = https.request options, (slack_res) ->
    slack_res.setEncoding("utf8")
    content = ""
    slack_res.on "data", (chunk) -> content += chunk
    slack_res.on "end", () ->
      json = JSON.parse(content)
      if json["ok"]
        res.send("Success!")
      else
        res.send("Error: #{json['error']}!")
  req.write(data)
  req.end()

server.listen PORT, IP, ->
  console.log("%s: regservice started on %s:%d ...", Date(Date.now()), IP, PORT)
