#  Get the latest jstip from https://github.com/loverajoel/jstips
#
# Notes:
#   Because learning is fun
#
# Commands:
#   hubot jstip - Get jstip
#   hubot jstip help - See a help document explaining how to use.
#   hubot create jstip hh:mm - Creates a jstip at hh:mm every weekday for this room
#   hubot create jstip hh:mm UTC+2 - Creates a jstip at hh:mm every weekday for this room (relative to UTC)
#   hubot list jstips - See all jstips for this room
#   hubot list jstips in every room - See all jstips in every room
#   hubot delete hh:mm jstip - If you have a jstip at hh:mm, deletes it
#   hubot delete all jstips - Deletes all jstips for this room.
#
# Dependencies:
#   underscore
#   cron

cheerio = require('cheerio');
cronJob = require('cron').CronJob
_ = require('underscore')

module.exports = (robot) ->
  robot.respond /jstip/i, (resp) ->
      robot.http("https://github.com/loverajoel/jstips/blob/master/README.md")
	      .get() (err, res, body) ->
	      # pretend there's error checking code here
	        if res.statusCode isnt 200
	          resp.send "Request came back" + res.statusCode
	          return
	        $ = cheerio.load(body);
	        $tipHeader = $('h1:contains(Tips list)').next();
	        tip = '\n'+ $tipHeader.text() + '\n';
	        $tipPointer = $tipHeader.next();
	        while !$tipPointer.is 'h2'
            tip = tip + $tipPointer.text() + '\n'
            $tipPointer = $tipPointer.next()
          resp.send tip;

  # Compares current time to the time of the jstip
  # to see if it should be fired.

  jstipShouldFire = (jstip) ->
    jstipTime = jstip.time
    utc = jstip.utc
    now = new Date
    currentHours = undefined
    currentMinutes = undefined
    if utc
      currentHours = now.getUTCHours() + parseInt(utc, 10)
      currentMinutes = now.getUTCMinutes()
      if currentHours > 23
        currentHours -= 23
    else
      currentHours = now.getHours()
      currentMinutes = now.getMinutes()
    jstipHours = jstipTime.split(':')[0]
    jstipMinutes = jstipTime.split(':')[1]
    try
      jstipHours = parseInt(jstipHours, 10)
      jstipMinutes = parseInt(jstipMinutes, 10)
    catch _error
      return false
    if jstipHours == currentHours and jstipMinutes == currentMinutes
      return true
    false
    
  # Returns all jstips.

  getJstips = ->
    robot.brain.get('jstips') or []

  # Returns just jstips for a given room.

  getJstipsForRoom = (room) ->
    _.where getJstips(), room: room

  # Gets all jstips, fires ones that should be.

  checkJstips = ->
    jstips = getJstips()
    _.chain(jstips).filter(jstipShouldFire).pluck('room').each doJstip
    return

  # Fires the jstip message.

  doJstip = (room) ->
    robot.http("http://www.jstips.co/")
	        .get() (err, res, body) ->
	      # pretend there's error checking code here
	          if res.statusCode isnt 200
              message = "Request came back" + res.statusCode
              robot.messageRoom room, message
              return
            $ = cheerio.load(body);
            $tipHeader = $('.posts');
            tip = $tipHeader.find('p').first().text() + '\n'
            tip = tip + "http://www.jstips.co" + $tipHeader.find('a').attr('href') + '\n';
            robot.messageRoom room, tip
            return

  # Finds the room for most adaptors
  findRoom = (msg) ->
    room = msg.envelope.room
    if _.isUndefined(room)
      room = msg.envelope.user.reply_to
    room

  # Stores a jstip in the brain.

  saveJstip = (room, time, utc) ->
    jstips = getJstips()
    newjstip = 
      time: time
      room: room
      utc: utc
    jstips.push newjstip
    updateBrain jstips
    return

  # Updates the brain's jstip knowledge.

  updateBrain = (jstips) ->
    robot.brain.set 'jstips', jstips
    return

  clearAllJstipsForRoom = (room) ->
    jstips = getJstips()
    jstipsToKeep = _.reject(jstips, room: room)
    updateBrain jstipsToKeep
    jstips.length - (jstipsToKeep.length)

  clearSpecificJstipForRoom = (room, time) ->
    jstips = getJstips()
    jstipsToKeep = _.reject(jstips,
      room: room
      time: time)
    updateBrain jstipsToKeep
    jstips.length - (jstipsToKeep.length)

  # Check for jstips that need to be fired, once a minute
  # Monday to Sunday.
  new cronJob('1 * * * * 1-7', checkJstips, null, true)

  robot.respond /delete all jstips for (.+)$/i, (msg) ->
    room = msg.match[1]
    jstipsCleared = clearAlljstipsForRoom(room)
    msg.send 'Deleted ' + jstipsCleared + ' .js tips for ' + room

  robot.respond /delete all jstips$/i, (msg) ->
    jstipsCleared = clearAllJstipsForRoom(findRoom(msg))
    msg.send 'Deleted ' + jstipsCleared + ' .js tip' + (if jstipsCleared == 1 then '' else 's') + '. No more .js tips for you.'
    return
  robot.respond /delete ([0-5]?[0-9]:[0-5]?[0-9]) jstip/i, (msg) ->
    time = msg.match[1]
    jstipsCleared = clearSpecificJstipForRoom(findRoom(msg), time)
    if jstipsCleared == 0
      msg.send 'Nice try. You don\'t even have a .js tip scheduled at ' + time
    else
      msg.send 'Deleted your ' + time + ' .js tip.'
    return
  robot.respond /create jstip ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9])$/i, (msg) ->
    time = msg.match[1]
    room = findRoom(msg)
    saveJstip room, time
    msg.send 'Ok, from now on I\'ll provide this room a .js tip every day at ' + time
    return
  robot.respond /create jstip ((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9]) UTC([+-]([0-9]|1[0-3]))$/i, (msg) ->
    time = msg.match[1]
    utc = msg.match[2]
    room = findRoom(msg)
    saveJstip room, time, utc
    msg.send 'Ok, from now on I\'ll provide this room a .js tip every day at ' + time + ' UTC' + utc
    return
  robot.respond /list jstips$/i, (msg) ->
    jstips = getJstipsForRoom(findRoom(msg))
    if jstips.length == 0
      msg.send 'Well this is awkward. You haven\'t got any .js tips set :-/'
    else
      jstipsText = [ 'Here\'s your .js tips:' ].concat(_.map(jstips, (jstip) ->
        if jstip.utc
          jstip.time + ' UTC' + jstip.utc
        else
          jstip.time
      ))
      msg.send jstipsText.join('\n')
    return
  robot.respond /list jstips in every room/i, (msg) ->
    jstips = getjstips()
    if jstips.length == 0
      msg.send 'No, because there aren\'t any.'
    else
      jstipsText = [ 'Here\'s the .js tips for every room:' ].concat(_.map(jstips, (jstip) ->
        'Room: ' + jstip.room + ', Time: ' + jstip.time
      ))
      msg.send jstipsText.join('\n')
    return
  robot.respond /jstip help/i, (msg) ->
    message = []
    message.push 'I can provide you with a daily .js tip!'
    message.push 'Use me to create a .js tip event, and then I\'ll post in this room every day at the time you specify. Here\'s how:'
    message.push ''
    message.push robot.name + ' create jstip hh:mm - I\'ll post a .js tip in this room at hh:mm every day.'
    message.push robot.name + ' create jstip hh:mm UTC+2 - I\'ll post a .js tip in this room at hh:mm every day.'
    message.push robot.name + ' list jstips - See all .js tips scheduled for this room.'
    message.push robot.name + ' list jstips in every room - Be nosey and see when other rooms have their .js tips.'
    message.push robot.name + ' delete hh:mm jstip - If you have a .js tip scheduled at hh:mm, I\'ll delete it.'
    message.push robot.name + ' delete all jstips - Deletes all .js tips for this room.'
    msg.send message.join('\n')
    return
  return