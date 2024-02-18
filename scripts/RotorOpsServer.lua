RotorOpsServer = {}
RotorOpsServer.version = "0.5"
trigger.action.outText("ROTOROPS SERVER SCRIPT: "..RotorOpsServer.version, 5)
env.info("ROTOROPS SERVER SCRIPT STARTED: "..RotorOpsServer.version)

--Mission Ending
RotorOpsServer.time_to_end = 300
RotorOpsServer.mission_ending = false
RotorOpsServer.result_text = "WE WON!"

--triggers may still be present in the miz to end the mission (20 minutes)
function RotorOpsServer.endMission(secs, winning_coalition_enum)
    if RotorOpsServer.mission_ending then
        return
    end
    env.info("RotorOpsServer: endMission called.")
    RotorOpsServer.mission_ending = true
	if secs then
		RotorOpsServer.time_to_end = secs
	end
    if winning_coalition_enum == 1 then
        RotorOpsServer.result_text = "WE LOST!"
    end

	local function countdown()
		local minutes = math.floor(RotorOpsServer.time_to_end / 60)
		local seconds = RotorOpsServer.time_to_end - (minutes * 60) --handle as string
		if seconds < 10 then
			seconds = "0" .. seconds
		end
		trigger.action.outText(RotorOpsServer.result_text .. " Standby. Mission will rotate in "..minutes..":"..seconds, 2, true)
		RotorOpsServer.time_to_end = RotorOpsServer.time_to_end - 1
		if RotorOpsServer.time_to_end <= 0 then
			trigger.action.setUserFlag('mission_end', winning_coalition_enum)
		else
			timer.scheduleFunction(countdown, {}, timer.getTime() + 1)
		end
	end
	countdown()
end

function RotorOpsServer.checkGameState()
    if RotorOps and RotorOps.game_state then
        if RotorOps.game_state == 98 then
            RotorOpsServer.endMission(240,1)
        elseif RotorOps.game_state == 99 then
            RotorOpsServer.endMission(240,2)
        end
    end
    timer.scheduleFunction(RotorOpsServer.checkGameState, {}, timer.getTime() + 4)
end
RotorOpsServer.checkGameState()


--The following code for integrating the server bot spawn credits with PERKS works fine, but it needs to
-- be moved to a server script so it's not dependent on this mission script.

-- function RotorOpsServer.convertPointsToSpawnCredits(playerName, points)
-- 	if dcsbot then
-- 	    env.info("RotorOpsServer: Converting "..points.." points to spawn credits for "..playerName)
-- 		dcsbot.addUserPoints(playerName, points)
-- 		return true
-- 	end
-- 	return false
-- end
--
-- function RotorOpsServer.addPerks()
--   env.info("RotorOpsServer: Adding perks to RotorOpsPerks.")
--   ---- PERKS: Convert points to spawn credits ----
--
--   RotorOpsPerks.perks["spawnCredits"] = {
--       perk_name='spawnCredits',
--       display_name='Buy 100 Spawn Slot Credits',
--       cost=100,
--       cooldown=0,
--       max_per_player=1000000,
--       max_per_mission=1000000,
--       at_mark=false,
--       at_position=true,
--       enabled=true,
--       sides={0,1,2},
--   }
--
--   RotorOpsPerks.perks.spawnCredits["action_function"] = function(args)
--     local playerName = Unit.getByName(args.player_unit_name):getPlayerName()
--       return RotorOpsServer.convertPointsToSpawnCredits(playerName, 100)
--   end
--
--   ---- End of Spawn Credits Perk ----
--
-- end
--
-- if dcsbot then
--   RotorOpsServer.addPerks()
-- else
--   env.warning("RotorOpsServer: DCSBot not found.  Perks not added.")
-- end





