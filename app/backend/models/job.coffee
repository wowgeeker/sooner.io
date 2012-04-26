mongoose = require 'mongoose'
Schema = mongoose.Schema
models = require __dirname
CronJob = require('cron').CronJob

schema = new Schema
  name:
    type: String
    required: true
  schedule:
    type: String
    validate: (v) ->
      try
        new String(v).length == 0 || new CronJob(v)
      catch err
        console.log(err)
        false
  hooks:
    type: String
    trim: yes
  workerName:
    type: String
    default: 'worker'
    index: true
  enabled:
    type: Boolean
    default: 'true'
    index: true
  createdAt:
    type: Date
    default: -> new Date()
  updatedAt:
    type: Date
  lastRanAt:
    type: Date
  lastStatus:
    type: String
  path:
    type: String
    required: true
  mutex:
    type: Boolean
    default: true
  deleted:
    type: Boolean
    default: false

schema.pre 'save', (next) ->
  if !@createdAt
    @createdAt = @updatedAt = new Date()
  else
    @updatedAt = new Date()
  next()

schema.methods.updateAttributes = (attrs) ->
  @name       = attrs.name
  @schedule   = attrs.schedule
  @enabled    = attrs.enabled == '1'
  @mutex      = attrs.mutex == '1'
  @hooks      = attrs.hooks
  @workerName = attrs.workerName

schema.methods.newRun = ->
  new models.run
    jobId:      @_id
    name:       @name
    path:       @path
    workerName: @workerName

schema.methods.newCron = ->
  new CronJob @schedule, =>
    run = @newRun()
    run.save (err, run) ->
      if err
        console.log err
      else
        GLOBAL.hook.emit 'trigger-job', runId: run._id, name: run.name

schema.methods.hookEvent = (hook, data) ->
  console.log "#{@name} triggered by event '#{hook}' with data #{JSON.stringify data}"
  run = @newRun()
  run.data = data
  run.save (err, run) ->
    if err then throw err
    GLOBAL.hook.emit 'trigger-job', runId: run._id, name: run.name

module.exports = model = mongoose.model 'Job', schema

model.sync = (socket) ->
  name = @modelName.toLowerCase()
  socket.on "#{name}:read", (data, callback) =>
    @find (err, records) ->
      callback null, records
