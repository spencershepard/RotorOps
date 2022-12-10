RotorOpsServer = {}
RotorOpsServer.version = "0.3"
trigger.action.outText("ROTOROPS SERVER SCRIPT: "..RotorOpsServer.version, 5)
env.info("ROTOROPS SERVER SCRIPT STARTED: "..RotorOpsServer.version)

--For SpecialK's DCSServerBot
RotorOpsServer.dcsbot = {}
RotorOpsServer.dcsbot.enabled = true
RotorOpsServer.dcsbot.points = {}
RotorOpsServer.dcsbot.points.troop_drop = 6
RotorOpsServer.dcsbot.points.unpack = 5
RotorOpsServer.dcsbot.points.rearm_repair = 3

--Mission Ending
RotorOpsServer.time_to_end = 600

function RotorOpsServer.endMission(secs)
	if secs then
		RotorOpsServer.time_to_end = secs
	end

	local function countdown()
		local minutes = math.floor(RotorOpsServer.time_to_end / 60)
		local seconds = RotorOpsServer.time_to_end - (minutes * 60) --handle as string
		if seconds < 10 then
			seconds = "0" .. seconds
		end
		trigger.action.outText("RTB now.  Mission will end in "..minutes..":"..seconds, 2, true)
		RotorOpsServer.time_to_end = RotorOpsServer.time_to_end - 1
		if RotorOpsServer.time_to_end <= 0 then
			trigger.action.setUserFlag('mission_end', 2)
		else
			timer.scheduleFunction(countdown, {}, timer.getTime() + 1)
		end
	end
	countdown()
end

function RotorOpsServer.registerCtldCallbacks()
	ctld.addCallback(function(_args)
		local action = _args.action
		local unit = _args.unit
		local picked_troops = _args.onboard
		local dropped_troops = _args.unloaded
		--env.info("ctld callback: ".. mist.utils.tableShow(_args)) 
		  
		local playername = unit:getPlayerName()
		if RotorOpsServer.dcsbot.enabled and dcsbot and playername then
			if action == "unload_troops_zone" or action == "dropped_troops" then
				if RotorOps.isUnitInZone(unit, RotorOps.active_zone) then
				  env.info('RotorOpsServer: adding points (unload troops in active zone) for ' ..playername)
				  net.send_chat(playername .. " dropped troops into the active zone. [" .. RotorOpsServer.dcsbot.points.troop_drop .. " points]")
				  dcsbot.addUserPoints(playername, RotorOpsServer.dcsbot.points.troop_drop)
				end
			elseif action == "rearm" or action == "repair" then
				env.info('RotorOpsServer: adding points (rearm/repair) for ' ..playername)
				net.send_chat(playername .. " repaired/rearmed our defenses. [" .. RotorOpsServer.dcsbot.points.rearm_repair .. " points]")
				dcsbot.addUserPoints(playername, RotorOpsServer.dcsbot.points.rearm_repair)
			elseif action == "unpack" then
				env.info('RotorOpsServer: adding points (unpack) for ' ..playername)
				net.send_chat(playername .. " unpacked ground units. [" .. RotorOpsServer.dcsbot.points.unpack .. " points]")
				dcsbot.addUserPoints(playername, RotorOpsServer.dcsbot.points.unpack)
			end
		end
	end)
end

RotorOpsServer.registerCtldCallbacks()
