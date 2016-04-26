request = require 'request'
numeral = require 'numeral'

crest = "https://public-crest.eveonline.com/"

playersOnline = (msg) ->
	request.get crest, (err, resp) ->
		return console.log(err) if err
		data = JSON.parse(resp.body)
		msg.send "There are #{numeral(data.userCounts.eve).format('0,0')} space nerds online right now."

module.exports = (robot) ->
	robot.respond /online count/, playersOnline
	robot.respond /who's online\?/, playersOnline
