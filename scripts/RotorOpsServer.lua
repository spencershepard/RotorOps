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






