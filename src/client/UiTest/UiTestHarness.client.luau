--!nonstrict
-- Runs the UI compatibility scenarios (UiScenarios) on the client and prints machine-readable results:
--   [UITEST] START
--   [UITEST] {"scenario":"ui_layout","pass":false,"checks":[{"name":...,"value":...,"limit":...,"pass":...}]}
--   [UITEST] END pass=N fail=N
-- Also mirrored into the LocalPlayer attribute "UiTestResult" (JSON) for execute_luau readers.
-- Trigger: ReplicatedStorage attribute UiTestRun = true (set it to false first if it is already true).
-- Clicks: ReplicatedStorage attribute UiTestClick = <UiSpec.Clicks Id> (set it to nil between clicks, and clear
-- UiTestClickDone before each click); see the protocol in UiSpec.Clicks. Owned by ui-test-writer.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiScenarios = require(script.Parent:WaitForChild("UiScenarios"))

local player = Players.LocalPlayer
local busy = false

UiScenarios.Init()

local function runAll()
	if busy then
		return
	end
	busy = true
	print("[UITEST] START")
	local results, pass, fail = {}, 0, 0
	for _, name in UiScenarios.Names do
		local ok, res = pcall(UiScenarios.Run, name)
		if not ok then
			res = {
				scenario = name,
				pass = false,
				error = tostring(res),
				checks = { { name = "scenario_ran", value = tostring(res), limit = "no error", pass = false } },
			}
		end
		table.insert(results, res)
		if res.pass then
			pass += 1
		else
			fail += 1
		end
		print("[UITEST] " .. HttpService:JSONEncode(res))
	end
	player:SetAttribute("UiTestResult", HttpService:JSONEncode({ pass = pass, fail = fail, results = results }))
	print(("[UITEST] END pass=%d fail=%d"):format(pass, fail))
	busy = false
end

local function runClick(id)
	while busy do
		task.wait(0.1)
	end
	busy = true
	local ok, res = pcall(UiScenarios.RunClick, id)
	if not ok then
		res = {
			scenario = "click:" .. tostring(id),
			pass = false,
			error = tostring(res),
			checks = { { name = "click_ran", value = tostring(res), limit = "no error", pass = false } },
		}
	end
	local json = HttpService:JSONEncode(res)
	print("[UITEST] " .. json)
	player:SetAttribute("UiTestClickResult", json)
	busy = false
end

ReplicatedStorage:GetAttributeChangedSignal("UiTestRun"):Connect(function()
	if ReplicatedStorage:GetAttribute("UiTestRun") == true then
		task.spawn(runAll)
	end
end)

ReplicatedStorage:GetAttributeChangedSignal("UiTestClick"):Connect(function()
	local id = ReplicatedStorage:GetAttribute("UiTestClick")
	if type(id) == "string" and id ~= "" then
		task.spawn(runClick, id)
	end
end)

if ReplicatedStorage:GetAttribute("UiTestRun") == true then
	task.spawn(runAll)
end
