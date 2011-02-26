fs = require "fs"
trackerFile = ".track.json"
util = require "./util"
cFL = util.cutFirstLine
sys = require "sys"

class Tracker
  constructor: (params) ->
    @_create params

  ###
  Create new object from params

  @param {Object} params Params object
  @api private
  ###
  _create: (params={}) ->
    @tickets = params.tickets || {}
    @states = params.states || {
      initial: ["todo", "bug", "accept"]
      final: ["done", "fixed", "closed"]}

  ###
  Load tracker file. If file not exists, it will be created with
  default name in work dir

  @param {String} filename Path to tracker file
  @api public
  ###
  load: (filename) ->
    try
      filename ||= "./" + trackerFile
      @_create JSON.parse fs.readFileSync filename
    catch err
      if "EBADF" == err.code
        @_create()
        fs.writeFileSync filename, JSON.stringify @
      else
        throw err

  ###
  Save tracker file

  @param {String} filename Path to tracker file
  @api public
  ###
  save: (filename) ->
    filename ||=  "./" + trackerFile
    data = JSON.stringify @
    fs.writeFileSync filename, data


  ###
  Search ticket in tracker

  @param {String} ticketId Ticket id starting numbers
  @return {Array} result Tickets, which have id, strarting from ticketId
  @api private
  ###
  _searchTicket: (ticketId) ->
    result = []
    for id, t of @tickets
      if 0 == id.indexOf ticketId
        result.push t
    result

  ###
  Get single ticket by id.
  If ticket id is not unique, method throws exception

  @param {String} ticketId Ticket id starting numbers
  @return {Object} ticket Ticket object
  @api private
  ###
  _getSingleTicket: (id) ->
    tickets = @_searchTicket id
    switch tickets.length
      when 1
        return tickets[0]
      when 0
        console.log "Ticket with id, starting from '#{id}' not found"
      else
        console.log "Duplicate tickets with id = #{id} " #(#{sys.inspect tickets})"
    process.exit(-1)


  ###
  Add ticket to tracker

  @param {Object} config Config Object
  @param {String} text Text of ticket
  @api public
  ###
  addTicket: (config, text) ->
    d = new Date()
    meta = util.parseText text
    t =
      created: d
      modified: d
      author: config.makeUserDict()
      text: text
      id: util.createId text, config
      comments: []
      log: []
    @tickets[t.id] = t
    @save()
    console.log "You'we added ticket:\n#{text}" if "true" == config.get "verbose"

  ###
  Add unique ticket. Check ticket text for unique before adding

  @param {Object} config Config Object
  @param {String} text Text of ticket
  @api public
  ###
  addUniqueTicket: (config, text) ->
    for id, t of @tickets
      if text == t.text
        console.log "Add duplicate ticket declined" if "true" == config.get "verbose"
        return
    @addTicket config, text

  ###
  Remove ticket from tracker.

  @param {String} id Ticket id  starting numbers
  ###
  removeTicket: (id) ->
    t = @_getSingleTicket id
    delete @tickets[t.id]
    @save()
    console.log "Ticket with #{id.yellow} removed"  if "true" == config.get "verbose"

  removeTickets: (idList) ->
    for id in idList
      try
        t = @_getSingleTicket id
        delete @tickets[t.id]
        console.log "Ticket with #{id.yellow} removed"  if "true" == config.get "verbose"
      catch err
    @save()

  ###
  Change ticket text

  @param {Object} config Config Object
  @param {String} ticketId Ticket id
  @param {Object} text New ticket text
  @api public
  ###
  changeTicket: (config, id, text) ->
    t = @_getSingleTicket id
    t.author = config.makeUserDict()
    t.text = text
    @_updateTicket t

  ###
  Update ticket

  @param {Object} ticket Ticket to update
  @api private
  ###
  _updateTicket: (ticket) ->
    @tickets[ticket.id] = ticket
    @save()


  ###
  Comment ticket

  @param {Object} config Config Object
  @param {String} ticketId Ticket id
  @param {Object} comment Comment text
  @api public
  ###
  commentTicket: (config, id, comment) ->
    t = @_getSingleTicket id
    t.comments.push {
        date: new Date()
        author: config.makeUserDict()
        comment: comment
        id: util.createId comment, config}
      @_updateTicket t
    console.log "You add a comment:\n#{comment}"  if "true" == config.get "verbose"

  ###
  Change ticket state

  @param {Object} config Config Object
  @param {String} ticketId Ticket id
  @param {String} newState New State value
  @api public
  ###
  changeState: (config, id, newState) ->
    if 0 == newState.indexOf util.statePrefix
      t = @_getSingleTicket id
      console.log "State of: #{t.text}\nchanged to #{newState}"  if "true" == config.get "verbose"
      t.text = util.replaceState t.text, newState
      t.modified = new Date()
      @_updateTicket t


  ###
  Show info on ticket

  @param {String} ticketId Ticket id
  @api public
  ###
  info: (id) ->
    @_logOne @_getSingleTicket id

  ###
  Log one ticket full info

  @param {Object} ticket Ticket object
  @param {String} search Search string, default null
  @api private
  ###
  _logOne: (t, search=null) ->
    console.log "Ticket: #{t.id.yellow}"
    console.log "Author: #{t.author.user} <#{t.author.email}>"
    console.log "Created: #{t.created}\nLast modified: #{t.modified}"
    console.log util.colorizeText t.text, search
    console.log "\nComments:\n" if 0 < t.comments.length
    for c in t.comments
      console.log "#{c.author.user} <#{c.author.email}> :"
      console.log c.comment
    console.log  "\n--------------------------------------------------------------------------------\n"


  ###
  Log + search tickets

  @param {String} search Search string, default null
  @param {Object} config Config object
  @api public
  ###
  log: (search=null, config) ->
    stat = todo:0, done: 0   if null == search

    for id, t of @tickets       # todo sort results by date, etc
      if stat         # statistics
        state = util.getState t.text, config
        if state in @states.final
          stat.done++
          continue if "false" == config.get "showDonedTasks"
        else
          stat.todo++

      if null == search || 0 <= t.text.indexOf search
        switch config.get "log"
          when "tiny"
            console.log "#{util.colorizeText cFL(t.text, 60)}"
          when "long"
            @_logOne t, search
          else                  # short of anything else is default
            console.log "#{cFL(t.id, 12).yellow}\t#{util.colorizeText cFL(t.text, 60), search}\t#{util.formatTime t.modified}\t#{t.author.user}"
    if null == search
      total = stat.todo + stat.done
      if 0 < total
        console.log "Tickets: #{stat.done}/#{stat.todo + stat.done}"
      else
        console.log "No tickets yet"
exports.Tracker = Tracker
