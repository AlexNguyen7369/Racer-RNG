--!nonstrict
-- Runs the physics scenarios and prints machine-readable results for the test agents.
--   [CARTEST] START
--   [CARTEST] {"scenario":"accel","pass":true,...}
--   [CARTEST] END pass=5 fail=0
-- Also mirrored into ReplicatedStorage attribute "CarTestResult" (JSON) for execute_luau readers.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestConfig = require(script.Parent.TestConfig)
local Scenarios = require(script.Parent.Scenarios)

local running = false

-- Harness stability fix, NOT a loosening: no limit or expectation changed. The first scenarios of a
-- cold start were disturbed by start-up frame hitches (tracks/money building right before the run),
-- so wait for the world to settle first.
local WARMUP_MIN_SECONDS = 3
local WARMUP_STABLE_FRAMES = 90
local WARMUP_MAX_DT = 0.03
local WARMUP_CAP_SECONDS = 20

local RunService = game:GetService("RunService")

local function warmUp()
	local start = os.clock()
	local frames, streak = 0, 0
	while true do
		local dt = RunService.Heartbeat:Wait()
		frames += 1
		if dt < WARMUP_MAX_DT then
			streak += 1
		else
			streak = 0
		end
		local waited = os.clock() - start
		local stable = waited >= WARMUP_MIN_SECONDS and streak >= WARMUP_STABLE_FRAMES
		if stable or waited >= WARMUP_CAP_SECONDS then
			print(("[CARTEST] WARMUP frames=%d waited=%.1f stable=%s"):format(frames, waited, tostring(stable)))
			return
		end
	end
end

local function runAll()
	if running then
		return
	end
	running = true
	print("[CARTEST] START")
	warmUp()

	-- Track the worst frame time per scenario (reported as metrics.max_dt).
	local maxDt = 0
	local dtConn = RunService.Heartbeat:Connect(function(dt)
		if dt > maxDt then
			maxDt = dt
		end
	end)
	local results, pass, fail = {}, 0, 0

	local names = table.clone(TestConfig.Scenarios)
	local trackTests = script.Parent:FindFirstChild("TrackTests")
	if trackTests then
		local found = {}
		for _, module in trackTests:GetChildren() do
			if module:IsA("ModuleScript") then
				table.insert(found, "track:" .. module.Name)
			end
		end
		table.sort(found)
		table.move(found, 1, #found, #names + 1, names)
	end

	for _, name in names do
		maxDt = 0
		local ok, res = pcall(Scenarios.Run, name)
		if not ok then
			res = { scenario = name, pass = false, error = tostring(res), checks = {}, metrics = {} }
		end
		if type(res.metrics) == "table" then
			res.metrics.max_dt = math.floor(maxDt * 1000 + 0.5) / 1000
		end
		table.insert(results, res)
		if res.pass then
			pass += 1
		else
			fail += 1
		end
		print("[CARTEST] " .. HttpService:JSONEncode(res))
	end
	dtConn:Disconnect()
	ReplicatedStorage:SetAttribute(
		"CarTestResult",
		HttpService:JSONEncode({ pass = pass, fail = fail, results = results })
	)
	print(("[CARTEST] END pass=%d fail=%d"):format(pass, fail))
	ReplicatedStorage:SetAttribute("CarTestRun", false)
	running = false
end

ReplicatedStorage:GetAttributeChangedSignal("CarTestRun"):Connect(function()
	if ReplicatedStorage:GetAttribute("CarTestRun") == true then
		task.spawn(runAll)
	end
end)

if TestConfig.Enabled then
	task.delay(2, runAll)
end
