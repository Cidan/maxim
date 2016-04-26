request = require 'request'
numeral = require 'numeral'
async = require 'async'
redis = require 'redis'
xml2js = require 'xml2js'

client = redis.createClient()
crest = "https://public-crest.eveonline.com"
xmlapi = "https://api.eveonline.com"
evescout = "https://eve-scout.com/api"

## Local functions
String.prototype.capitalize = () ->
	return @charAt(0).toUpperCase() + @slice(1).toLowerCase()

# Pretty print a number
pnum = (n) ->
	return numeral(n).format('0,0')

# Initial work here
init = (cb) ->
	clean = [
		'solarsystems_id_to_name',
		'solarsystems_name_to_id',
		'kills_by_id'
	]
	ops = []

	ops.push (icb) ->
		async.each clean, (item, ecb) ->
			client.del item, ecb
		, icb

	async.series ops, cb

# Refresh our solor systems and keep a local, in memory cache lookup
# table indexed by both id, and name.
refreshSolarSystems = (cb) ->
	request.get "#{crest}/solarsystems/", (err, resp) ->
		return setTimeout(cb, 60000) if err
		data = JSON.parse(resp.body)
		async.each data.items, (item, icb) ->
			client.hset 'solarsystems_id_to_name', item.id, item.name.toLowerCase(), () ->
				client.hset 'solarsystems_name_to_id', item.name.toLowerCase(), item.id, icb
		, () ->
			console.log "Solar system data refreshed."
			setTimeout cb, 120000

# Refresh system kills.
# TODO: cache based on cache time returned by the API.
refreshKills = (cb) ->
	request.get "#{xmlapi}/map/kills.xml.aspx", (err, resp) ->
		return setTimeout(cb, 60000) if err
		xml2js.parseString resp.body, (err, data) ->
			return setTimeout(cb, 60000) if err
			async.each data.eveapi.result[0].rowset[0].row, (row, icb) ->
				client.hset 'kills_by_id', row['$'].solarSystemID, JSON.stringify(row['$']), icb
			, () ->
				console.log "Solar system kill data refreshed."
				setTimeout cb, 3900000


## Chat commands

# Get a count of current people online in eve.
playersOnline = (msg) ->
	request.get crest, (err, resp) ->
		return console.log(err) if err
		data = JSON.parse(resp.body)
		msg.send "There are #{pnum(data.userCounts.eve)} space nerds online right now."

lookupSystemKills = (msg) ->
	name = msg.match[1].toLowerCase()
	ops = []

	ops.push (cb) ->
		client.hget 'solarsystems_name_to_id', name, cb

	ops.push (id, cb) ->
		return msg.send("Either #{name.capitalize()} has had no kills in the last hour, or that system doesn't exist.") if not id
		client.hget 'kills_by_id', id, cb

	ops.push (data, cb) ->
		data = JSON.parse(data)
		msg.send "#{name.capitalize()} has had #{pnum(data.shipKills)} ship kills, #{pnum(data.factionKills)} faction kills, and #{pnum(data.podKills)} pod kills in the last hour."
		cb()

	async.waterfall ops

lookupTheraDistance = (msg) ->
	system = msg.match[1].toLowerCase()

	request.get "#{evescout}/wormholes?systemSearch=#{system}", (err, resp) ->
		return console.log(err) if err
		data = JSON.parse(resp.body)

		jumps = 0
		targetSystem = undefined

		for reqSystem in data when reqSystem.jumps < jumps or jumps == 0
			jumps = reqSystem.jumps
			targetSystem = reqSystem.destinationSolarSystem.name

		msg.send("The closest Thera connection I found to #{system.capitalize()} is **#{jumps}** jumps away in **#{targetSystem}**")


module.exports = (robot) ->
	init () ->
		async.forever refreshSolarSystems
		async.forever refreshKills
	robot.respond /online count/i, playersOnline
	robot.respond /who's online\?/i, playersOnline

	robot.respond /how safe is (.*)\?/i, lookupSystemKills
	robot.respond /info on (.*)/i, lookupSystemKills
	robot.respond /is (.*) safe\?/i, lookupSystemKills

	robot.respond /how far from (.*) to thera\?/i, lookupTheraDistance
	robot.respond /distance to thera from (.*)\?/i, lookupTheraDistance
	robot.respond /distance from (.*) to thera\?/i, lookupTheraDistance
