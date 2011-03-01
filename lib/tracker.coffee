fs = require "fs"
util = require "./util"
ucs = util.colorizeString
uct = util.colorizeText
ccn = util.colorizeCommentNumber
cfl = util.cutFirstLine
sys = require "sys"
path = require "path"

class Tracker
  constructor: (@config) ->
    @editTimeLimit = 15 * 60000 # 15 minutes
    @_create()
    @created = yes

  ###
  Create new object from params

  @param {Object} params Params object
  @api private
  ###
  _create: (params={}) ->
    @name = params.name || ""   # project name
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
  load: () ->
    preWd = ""
    cwd = process.cwd()
    trackerFile = @config.get "trackerFile"
    while cwd != preWd
      preWd = cwd
      cwd = path.dirname cwd
      try
        @filename = "#{preWd}/#{trackerFile}"
        @_create JSON.parse fs.readFileSync @filename
        return
      catch err
    cwd = process.cwd()
    @filename = "#{cwd}/#{trackerFile}"
    @_create()
    if "yes" == @config.get "askBeforeCreate"
      @created = no
      self = @
      util.readOneLine "Create new tracker in #{cwd} (yes/no) ? ", (answer) ->
          if  answer.toLowerCase() in ["yes", "y"]
            self.save()

  ###
  Save tracker file

  @param {String} filename Path to tracker file
  @api public
  ###
  save: () ->
    name = "\"name\": \"#{@name}\""
    states = '"states":' + JSON.stringify @states
    tickStr = '"tickets": {\n'
    tickets = []
    for k,v of @tickets
      tickets.push '"' + k + '": ' + JSON.stringify v
    tickStr += tickets.join(", \n") + "\n}"
    data = "{#{name},\n#{tickStr},\n#{states}\n}\n"
    fs.writeFileSync @filename, data

  ###
  Show project states

  @api public
  ###
  showStates: (which=null) ->
    if null == which
      console.log "Project states:"
      console.log "Initial: #{@states.initial.join ', '} "
      console.log "Final: #{@states.final.join ', '} "
    else if which in ["initial", "final"]
      console.log "#{which} states: #{@states[which].join ', '}"
    else
      console.log 'use "initial" or "final", not #{which}'

  ###
  Update states. Can update "initial" or "final" states

  @param {Array} params List of params. First param must be "initial" of "final",
                        rest params are values for initial or final states
  @api public
  ###
  updateStates: (params) ->
    if params[0] in ["initial", "final"]
      @states[params[0]] = params[1..]
      @save()
      console.log "Project #{params[0]} states updated to #{params[1..].join ', '}" if "true" == @config.get "verbose"
    else
      console.log "Project states not updated" if "true" == @config.get "verbose"

  ###
  Search ticket in tracker

  @param {String} ticketId Ticket id starting numbers
  @return {Array} result Tickets, which have id, strarting from ticketId
  @api private
  ###
  _searchTicket: (ticketId) ->
    result = []
    if ticketId.match /^\^.$/
      tickets = @_sortTickets()
      id = parseInt ticketId[1], 36
      result.push tickets[id] if id < tickets.length
    else
      for id, t of @tickets
        if 0 == id.indexOf ticketId
          result.push t
    result

  ###
  Get single ticket by id.
  If ticket id is not unique, method throws exception

  @param {String} ticketId Ticket id starting numbers
  @return {Object} ticket Ticket object
  @api public
  ###
  getSingleTicket: (id) ->
    tickets = @_searchTicket id, @config
    switch tickets.length
      when 1
        return tickets[0]
      when 0
        console.log "Ticket with id, starting from '#{id}' not found"
      else
        console.log "Duplicate tickets with id = #{id} "
    process.exit(-1)


  ###
  Add ticket to tracker

  @param {String} text Text of ticket
  @api public
  ###
  addTicket: (text) ->
    d = new Date()
    meta = util.parseText text
    t =
      created: d
      modified: d
      author: @config.makeUserDict()
      text: text
      id: util.createId text, @config
      comments: []
      log: []
    @tickets[t.id] = t
    @save()
    console.log "You'we added ticket:\n#{text}" if "true" == @config.get "verbose"

  ###
  Add unique ticket. Check ticket text for unique before adding

  @param {String} text Text of ticket
  @api public
  ###
  addUniqueTicket: (text) ->
    for id, t of @tickets
      if text.split("\n")[0] == t.text.split("\n")[0]
        console.log "Add duplicate ticket declined" if "true" == @config.get "verbose"
        return
    @addTicket text

  ###
  Remove ticket from tracker.

  @param {String} id Ticket id  starting numbers
  @api public
  ###
  removeTicket: (id) ->
    t = @getSingleTicket id
    delete @tickets[t.id]
    @save()
    console.log "Ticket with #{id.yellow} removed"  if "true" == @config.get "verbose"

  ###
  Remove tickets in list

  @param {Array} idList List of ids that must to deleted
  @api public
  ###
  removeTickets: (idList) ->
    for id in idList
      try
        t = @getSingleTicket id
        delete @tickets[t.id]
        console.log "Ticket with #{id.yellow} removed"  if "true" == @config.get "verbose"
      catch err
    @save()

  ###
  Change ticket text

  @param {String} ticketId Ticket id
  @param {Object} text New ticket text
  @api public
  ###
  changeTicket: (id, text) ->
    t = @getSingleTicket id
    t.author = @config.makeUserDict()
    t.text = text
    @updateTicket t

  ###
  Update ticket

  @param {Object} ticket Ticket to update
  @api public
  ###
  updateTicket: (ticket) ->
    @tickets[ticket.id] = ticket
    @save()


  ###
  Comment ticket

  @param {String} ticketId Ticket id
  @param {String} comment Comment text
  @api public
  ###
  commentTicket: (id, text) ->
    t = @getSingleTicket id
    d = new Date()
    comment = {
        date: d
        author: @config.makeUserDict()
        comment: text
        id: util.createId comment, @config}

    comment.sign = @_signComment comment
    t.comments.push comment
    @updateTicket t
    console.log "You add a comment:\n#{comment.comment}"  if "true" == @config.get "verbose"

  ###
  Sign comment

  @param {Object} comment Comment object
  @return {String} signature Comment signature
  @api private
  ###
  _signComment: (c) ->
    util.sign c.comment + c.id, @config

  ###
  Can edit this comment. Only author can edit his comment at a limited
  time (editTimeLimit)

  @param {String} ticketId Ticket id
  @param {String} commentId Comment id
  @return {Boolean} result REsult for current user (from config)
  @api public
  ###
  canEditComment: (id, cid) ->
    commLst = @getComment id, cid
    if commLst
      [ticket, id] = commLst
      c = ticket.comments[id]
      d = new Date()
      cdate = new Date Date.parse c.date
      return @editTimeLimit >  d - cdate && c.sign == @_signComment c

    return no


  ###
  Update comment on ticket

  @param {String} ticketId Ticket id
  @param {String} cid Commetn id
  @param {String} newComment New comment
  @api public
  ###
  updateComment: (id, cid, newComment) ->
    comLst = @getComment id, cid
    if comLst
      [t, i] = comLst
      c = t.comments[i]
      d = new Date()
      cdate = new Date Date.parse c.date
      if @editTimeLimit <  d - cdate
        throw new Error "time limit to edit exeeded"
      else
        sign = @_signComment c
        if sign == c.sign
          c.edited = d
          c.comment = newComment
          c.sign = @_signComment c
        else
          throw new Error "signature not match"
      @updateTicket t
      console.log "You update comment:\n#{newComment}" if "true" == @config.get "verbose"
    else
      console.log "Error! can't update comment for ticket #{id}" if "true" == @config.get "verbose"

  ###
  Get comment by id

  @param {String} ticketId Ticket id
  @param {String} cid Comment id
  @return {Array|null} comment Return array of ticket and comment index in comments.
                               If comment not found, return null
  ###
  getComment: (id, cid) ->
    t = @getSingleTicket id
    c = no
    i = 0
    if "." == cid[0] && t.comments[cid.substring 1]
      return [t, cid.substring 1]
    else
      for com in t.comments
        if 0 == com.id.indexOf cid
          return [t, i]
        i++
    null

  ###
  Show commnets on ticket

  @param {String} ticketId Ticket id
  @api public
  ###
  showComments: (id) ->
    t = @getSingleTicket id
    @_showTicketComments t, util.getState(t.text, @config) in @states.final

  ###
  Change ticket state

  @param {String} ticketId Ticket id
  @param {String} newState New State value
  @api public
  ###
  changeState: (id, newState) ->
    if 0 == newState.indexOf util.statePrefix
      t = @getSingleTicket id
      console.log "State of: #{t.text}\nchanged to #{newState}"  if "true" == @config.get "verbose"
      text = util.replaceState t.text, newState
      t.text = if text != t.text then text else "#{newState} #{text}"
      t.modified = new Date()
      @updateTicket t


  ###
  Show info on ticket

  @param {String} ticketId Ticket id
  @api public
  ###
  info: (id) ->
    @_logOne @getSingleTicket(id), null

  ###
  Log one ticket full info

  @param {Object} ticket Ticket object
  @param {String} search Search string, default null
  @api private
  ###
  _logOne: (t, search=null) ->
    done = util.getState(t.text, @config) in @states.final
    console.log ucs "Ticket: #{t.id.yellow}", done, "grey", ""
    console.log ucs "Author: #{t.author.user} <#{t.author.email}>", done, "grey", ""
    console.log ucs "Created: #{t.created}\n", done, "grey", ""
    console.log ucs "Last modified: #{t.modified}", done, "grey", ""
    console.log uct t.text, search, done
    @_showTicketComments t, done
    console.log  "\n-----------------------------------------"+
      "---------------------------------------\n"

  ###
  Show comments on ticket

  @param {Object} t Ticket object
  @param {Boolean} done Is ticket done
  ###
  _showTicketComments: (t, done) ->
    if 0 < t.comments.length
      console.log ucs "\nComments:\n",  done, "grey", ""
      i = 0
      for c in t.comments
        console.log ccn(i, c.id) +
          ucs " #{c.author.user} <#{c.author.email}> :", done, "grey", ""
        console.log ucs c.comment,  done, "grey", ""
        i++
    else
      console.log "No comments"


  ###
  Sort tickets

  @return {Array} tickets Tickets, sorted by asc or desc, depends on config "sortOrder" option
  @api private
  ###
  _sortTickets: () ->
    tickets = []
    for id, t of @tickets
      t.state = util.getState t.text, @config
      tickets.push t

    [pos, neg] = [1, -1]
    if "desc" == @config.get "sortOrder"
      [pos, neg] = [neg, pos]
    states = @states
    tickets.sort (t1, t2) ->
      final1 = t1.state in states.final
      final2 = t2.state in states.final
      if final1 == final2
        if t1.modified == t2.modified
          0
        else if t1.modified  < t2.modified
          pos
        else
          neg
      else if final1
        pos
      else
        neg
    tickets

  ###
  Log + search tickets

  @param {String} search Search string, default null
  @api public
  ###
  log: (search=null) ->
    stat = todo:0, done: 0   if null == search
    i = -1
    for t in @_sortTickets()
      i++
      state = util.getState t.text, @config
      done = state in @states.final
      if stat         # statistics
        if done
          stat.done++
          continue if "false" == @config.get "showDone"
        else
          stat.todo++

      if null == search || 0 <= t.text.indexOf search
        num = if 36 > i then ucs " ^#{i.toString(36)} ", done, "grey", "" else "    "
        num = num.green.inverse.bold if "yes" == @config.get("useZebra") && 0 == i % 2

        comments =
          if 0 < t.comments.length then ucs " [c:#{t.comments.length}]\t", done, "grey", "" else "     \t"
        switch @config.get "log"
          when "tiny"
            console.log "#{num}\t#{uct cfl(t.text, 60), null, done} " +
              "\t#{comments}".blue
          when "long"
            @_logOne t, search
          else                  # short of anything else is default
            id = cfl(t.id, 10).yellow  # todo +feature move width to settings
            id = id.inverse.bold if "yes" == @config.get("useZebra") && 0 == i % 2
            console.log "#{id}#{num}\t#{uct cfl(t.text, 60), search, done}\t#{comments}" +
                ucs "#{util.formatDateTime t.modified}\t#{t.author.user}",
                  done, "grey", ""
    if null == search
      total = stat.todo + stat.done
      if 0 < total
        console.log "Tickets: #{stat.done}/#{stat.todo + stat.done}"
      else
        console.log "No tickets yet"
exports.Tracker = Tracker
