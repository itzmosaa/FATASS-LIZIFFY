local run = function(func) func() end
local cloneref = cloneref or function(obj) return obj end

local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local collectionService = cloneref(game:GetService('CollectionService'))
local runService = cloneref(game:GetService('RunService'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local prediction = vape.Libraries.prediction

local bd = {}
local store = {
	blocks = {},
	serverBlocks = {}
}

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function parsePositions(v, func)
	if v:IsA('Part') then
		local start = -(v.Size / 2) + Vector3.new(1.5, 1.5, 1.5)
		for x = 0, v.Size.X - 1, 3 do
			for y = 0, v.Size.Y - 1, 3 do
				for z = 0, v.Size.Z - 1, 3 do
					local vec = start + Vector3.new(x, y, z)
					vec = v.CFrame:PointToWorldSpace(vec)
					vec = Vector3.new(math.round(vec.X), math.round(vec.Y), math.round(vec.Z))
					func(vec)
				end
			end
		end
	end
end

run(function()
	local Knit = require(replicatedStorage.Modules.Knit.Client)
	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	bd = setmetatable({
		BedwarsShop = require(replicatedStorage.Constants.BedWarsShop),
		BedwarsUpgrades = require(replicatedStorage.Constants.BedWarsTeamUpgrades),
		Blink = require(replicatedStorage.Blink.Client),
		BreakTimes = require(replicatedStorage.Constants.Blocks),
		BowClient = require(replicatedStorage.Client.Components.All.Tools.BowClient),
		CombatConstants = require(replicatedStorage.Constants.Melee),
		Communication = require(replicatedStorage.Client.Communication),
		Knit = Knit,
		Entity = require(replicatedStorage.Modules.Entity),
		ServerData = require(replicatedStorage.Modules.ServerData),
	}, {
		__index = function(self, ind)
			rawset(self, ind, ind:find('Service') and Knit.GetService(ind) or Knit.GetController(ind))
			return rawget(self, ind)
		end
	})

	task.spawn(function()
		local map = workspace:WaitForChild('Map', 99999)
		if map and vape.Loaded ~= nil then
			vape:Clean(map.DescendantAdded:Connect(function(v)
				parsePositions(v, function(pos)
					store.blocks[pos] = v
				end)
			end))
			vape:Clean(map.DescendantRemoving:Connect(function(v)
				parsePositions(v, function(pos)
					if store.blocks[pos] == v then
						store.blocks[pos] = nil
						store.serverBlocks[pos] = nil
					end
				end)
			end))
			for _, v in map:GetDescendants() do
				parsePositions(v, function(pos)
					store.blocks[pos] = v
					store.serverBlocks[pos] = v
				end)
			end
		end
	end)

	vape:Clean(function()
		table.clear(store.blocks)
		table.clear(store)
	end)
end)

for _, v in {'Reach', 'SilentAim', 'Disabler', 'HitBoxes', 'MurderMystery', 'AutoRejoin'} do
	vape:Remove(v)
end
run(function()
	local AutoClicker
	local CPS
	
	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				repeat
					local tool = getTool()
					if tool and inputService:IsMouseButtonPressed(0) then
						tool:Activate()
					end
					task.wait(1 / CPS.GetRandomValue())
				until not AutoClicker.Enabled
			end
		end,
		Tooltip = 'Automatically clicks for you'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 8,
		DefaultMax = 12
	})
end)
	
run(function()
	local old
	
	vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				old = rawget(bd.CombatConstants, 'REACH_IN_STUDS')
				rawset(bd.CombatConstants, 'REACH_IN_STUDS', 18)
				rawset(bd.Entity.LocalEntity, 'Reach', 18)
			else
				rawset(bd.CombatConstants, 'REACH_IN_STUDS', old)
				rawset(bd.Entity.LocalEntity, 'Reach', old)
				old = nil
			end
		end,
		Tooltip = 'Extends attack reach'
	})
end)
	
run(function()
	local Velocity = {Enabled = false}
	local VelocityHorizontal = {Value = 100}
	local VelocityVertical = {Value = 100}
	local VelocityChance = {Value = 100}
	local VelocityTargeting = {Enabled = false}
	local applyKnockback
	local connection
	
	local function velocityFunction(velo, ...)
		if Random.new():NextNumber(0, 100) > VelocityChance.Value then return end
		local check = (not VelocityTargeting.Enabled) or entitylib.EntityPosition({
			Range = 50,
			Part = 'RootPart',
			Players = true
		})
		if check then
			local hort, vert = (VelocityHorizontal.Value / 100), (VelocityVertical.Value / 100)
			if hort == 0 and vert == 0 then return end
			velo = Vector3.new(velo.X * hort, velo.Y * vert, velo.Z * hort)
		end
		return applyKnockback(velo, ...)
	end
	
	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				connection = getconnections(bd.CombatService.KnockBackApplied._re.OnClientEvent)[1]
				if not connection then return end
				applyKnockback = hookfunction(connection.Function, function(...)
					return velocityFunction(...)
				end)
			else
				if applyKnockback then hookfunction(connection.Function, applyKnockback) end
				connection = nil
			end
		end,
		Tooltip = 'Reduces knockback taken'
	})
	VelocityHorizontal = Velocity:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	VelocityVertical = Velocity:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	VelocityChance = Velocity:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	VelocityTargeting = Velocity:CreateToggle({Name = 'Only when targeting'})
end)
	
run(function()
	local old
	
	vape.Categories.Blatant:CreateModule({
		Name = 'Criticals',
		Function = function(callback)
			if callback then 
				old = hookfunction(bd.Blink.item_action.attack_entity.fire, function(...)
					local data = ...
					if type(data) == 'table' then 
						rawset(data, 'is_crit', true)
					end
					return old(...)
				end)
			else
				hookfunction(bd.Blink.item_action.attack_entity.fire, old)
				old = nil
			end
		end,
		Tooltip = 'Always hit criticals'
	})
end)
	
run(function()
	local old
	
	vape.Categories.Blatant:CreateModule({
		Name = 'InvMove',
		Function = function(callback)
			if callback then
				old = hookfunction(bd.MovementController.AddSpeedOverride, function(...)
					if select(2, ...) == 'MenuOpen' then
						return
					end
					return old(...)
				end)
				bd.MovementController:RemoveSpeedOverride('MenuOpen')
			else
				hookfunction(bd.MovementController.AddSpeedOverride, old)
				old = nil
			end
		end,
		Tooltip = 'Prevents slowing down when using items.'
	})
end)
	
run(function()
	local Killaura
	local Targets
	local CPS
	local SwingRange
	local AttackRange
	local AngleSlider
	local Max
	local Mouse
	local Swing
	local Block
	local AutoBlock
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local LegitAura
	local Particles, Boxes, AttackDelay, SwingDelay, ClickDelay = {}, {}, tick(), tick(), tick()
	local lMouse = cloneref(lplr:GetMouse())
	
	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end
		if LegitAura.Enabled then
			if ClickDelay < tick() then return false end
		end
	
		return getTool()
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				if LegitAura.Enabled then
					Killaura:Clean(inputService.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							ClickDelay = tick() + 0.1
						end
					end))
				end
	
				repeat
					local tool = getAttackData()
					local attacked = {}
					if tool and tool:HasTag('Sword') then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = Max.Value
						})
	
						if #plrs > 0 then
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	
							if AutoBlock.Enabled and not bd.Entity.LocalEntity.IsBlocking then
								firesignal(lMouse.Button2Down)
							end
	
							for _, v in plrs do
								local delta = (v.RootPart.Position - selfpos)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end
								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1
								if Block.Enabled then
									if bd.Entity.LocalEntity.IsBlocking then continue end
								end
	
								if not Swing.Enabled and SwingDelay < tick() then
									SwingDelay = tick() + 0.25
									entitylib.character.Humanoid.Animator:LoadAnimation(tool.Animations.Swing):Play()
	
									if vape.ThreadFix then
										setthreadidentity(2)
									end
									bd.ViewmodelController:PlayAnimation(tool.Name)
									if vape.ThreadFix then
										setthreadidentity(8)
									end
								end
	
								if delta.Magnitude > AttackRange.Value then continue end
								if AttackDelay < tick() then
									AttackDelay = tick() + (1 / CPS.GetRandomValue())
									local bdent = bd.Entity.FindByCharacter(v.Character)
									if bdent then
										bd.Blink.item_action.attack_entity.fire({
											target_entity_id = bdent.Id,
											is_crit = entitylib.character.RootPart.AssemblyLinearVelocity.Y < 0,
											weapon_name = tool.Name,
											extra = {
												rizz = 'No.',
												sigma = 'The...',
												those = workspace.Name == 'Ok'
											}
										})
									end
								end
							end
						else
							if AutoBlock.Enabled and bd.Entity.LocalEntity.IsBlocking then
								firesignal(lMouse.Button2Up)
							end
						end
					end
	
					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end
	
					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end
	
					task.wait()
				until not Killaura.Enabled
			else
				if AutoBlock.Enabled and bd.Entity.LocalEntity.IsBlocking then
					firesignal(lMouse.Button2Up)
				end
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({Players = true})
	CPS = Killaura:CreateTwoSlider({
		Name = 'Attacks per Second',
		Min = 1,
		Max = 20,
		DefaultMin = 12,
		DefaultMax = 12
	})
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 16,
		Default = 16,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 16,
		Default = 16,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	Max = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 10,
		Default = 10
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	Block = Killaura:CreateToggle({Name = 'No Block'})
	AutoBlock = Killaura:CreateToggle({Name = 'AutoBlock'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.14,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Function = function()
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end,
		Tooltip = 'Only attacks while swinging manually'
	})
end)
	
run(function()
	local old
	
	vape.Categories.Blatant:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			if callback then 
				old = hookfunction(bd.Blink.player_state.take_fall_damage.fire, function() end)
			else
				hookfunction(bd.Blink.player_state.take_fall_damage.fire, old)
				old = nil
			end
		end,
		Tooltip = 'Prevents taking fall damage.'
	})
end)
	
run(function()
	local old
	
	vape.Categories.Blatant:CreateModule({
		Name = 'NoSlowdown',
		Function = function(callback)
			local func = debug.getproto(bd.MovementController.KnitStart, 5)
			if callback then
				old = debug.getconstants(debug.getproto(bd.MovementController.KnitStart, 5))
				for i, v in old do 
					debug.setconstant(func, i, v == 'IsSneaking' and v or 'IsSpectating')
				end
			else
				for i, v in old do 
					debug.setconstant(func, i, v)
				end
				table.clear(old)
			end
		end,
		Tooltip = 'Prevents slowing down when using items.'
	})
end)
	
run(function()
	local TargetPart
	local FOV
	local old
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	local function aimFunction(...)
		local plr = entitylib.EntityMouse({
	        Range = FOV.Value,
	        Part = 'RootPart',
	        Players = true
	    })
	
	    if plr then
	        rayCheck.FilterDescendantsInstances = {plr.Character, gameCamera}
	        rayCheck.CollisionGroup = plr[TargetPart.Value].CollisionGroup
	        local offsetpos = entitylib.character.Head.CFrame
	        local calc = prediction.SolveTrajectory(offsetpos.Position, 180, 60, plr[TargetPart.Value].Position, plr[TargetPart.Value].Velocity, workspace.Gravity, plr.HipHeight, nil, rayCheck)
	
	        if calc then
	            targetinfo.Targets[plr] = tick() + 1
	            return offsetpos.Position + CFrame.new(offsetpos.Position, calc).LookVector * 100
	        end
	    end
	
		return old(...)
	end
	
	local ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
				old = hookfunction(debug.getupvalue(bd.BowClient.Start, 11), function(...)
					return aimFunction(...)
				end)
			else
	            hookfunction(debug.getupvalue(bd.BowClient.Start, 11), old)
				old = nil
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
end)
	
run(function()
	local AutoPlay
	local Delay
	
	AutoPlay = vape.Categories.Utility:CreateModule({
		Name = 'AutoPlay',
		Function = function(callback)
			if callback then
				AutoPlay:Clean(bd.Blink.game_state.team_won.on(function()
					if bd.ServerData.Submode ~= 'Playground' then
						bd.MatchController:EnterQueue(bd.ServerData.Submode)
					end
				end))
			end
		end,
		Tooltip = 'Automatically queues after the match ends.'
	})
end)
	
run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local adjacent, lastpos = {}, Vector3.zero
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				local vec = Vector3.new(x, y, z)
				if vec.Y ~= 0 and (vec.X ~= 0 or vec.Z ~= 0) then
					continue
				end
	
				if vec ~= Vector3.zero then
					table.insert(adjacent, vec)
				end
			end
		end
	end
	
	local function getBlocksInPoints(s, e)
		local list = {}
		for x = s.X, e.X, 3 do
			for y = s.Y, e.Y, 3 do
				for z = s.Z, e.Z, 3 do
					local vec = Vector3.new(x, y, z)
					if store.blocks[vec] then
						table.insert(list, vec)
					end
				end
			end
		end
		return list
	end
	
	local function roundPos(vec)
		return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
	end
	
	local function nearCorner(poscheck, pos)
		local startpos = poscheck - Vector3.new(3, 3, 3)
		local endpos = poscheck + Vector3.new(3, 3, 3)
		local check = poscheck + (pos - poscheck).Unit * 100
		if math.abs(check.Y - startpos.Y) > 3 then
			return Vector3.new(poscheck.X, math.clamp(check.Y, startpos.Y, endpos.Y), poscheck.Z)
		end
		return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
	end
	
	local function blockProximity(pos)
		local mag, returned = 60
		local tab = getBlocksInPoints(pos - Vector3.new(21, 21, 21), pos + Vector3.new(21, 21, 21))
		for _, v in tab do
			local blockpos = nearCorner(v, pos)
			local newmag = (pos - blockpos).Magnitude
			if newmag < mag then
				mag, returned = newmag, blockpos
			end
		end
		table.clear(tab)
		return returned
	end
	
	local function checkAdjacent(pos)
		for _, v in adjacent do
			if store.blocks[pos + v] then return true end
		end
		return false
	end
	
	local function getBlock()
		local tool = getTool()
		if tool and tool:HasTag('Blocks') then
			local btype = tool.Name == 'Blocks' and 'Clay' or tool.Name:sub(1, -6)
			return btype, btype == 'Clay' and 'Blocks' or ("%*Block"):format(btype)
		end
	
		if LimitItem.Enabled then return end
		for _, tool in lplr.Backpack:GetChildren() do
			if tool:IsA('Tool') and tool:HasTag('Blocks') then
				local btype = tool.Name == 'Blocks' and 'Clay' or tool.Name:sub(1, -6)
				return btype, btype == 'Clay' and 'Blocks' or ("%*Block"):format(btype)
			end
		end
	end
	
	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						local btype, bname = getBlock()
	
						if btype then
							local root = entitylib.character.RootPart
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
								root.Velocity = Vector3.new(root.Velocity.X, 38, root.Velocity.Z)
							end
	
							for i = Expand.Value, 1, -1 do
								local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + (Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + entitylib.character.Humanoid.MoveDirection * (i * 3))
								if Diagonal.Enabled then
									if math.abs(math.round(math.deg(math.atan2(-entitylib.character.Humanoid.MoveDirection.X, -entitylib.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
										local dt = (lastpos - currentpos)
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											currentpos = lastpos
										end
									end
								end
	
								local block = store.blocks[currentpos]
								if not block then
									blockpos = checkAdjacent(currentpos) and currentpos or blockProximity(currentpos)
									if blockpos then
										local fake = replicatedStorage.Assets.Blocks[btype]:Clone()
										fake.Name = 'TempBlock'
										fake.Position = blockpos
										fake:AddTag('TempBlock')
										fake:AddTag('Block')
										fake.Parent = workspace.Map
										bd.EffectsController:PlaySound(blockpos)
										bd.Entity.LocalEntity:RemoveTool(bname, 1)
	
										task.spawn(function()
											local suc, block = bd.Blink.item_action.place_block.invoke({
												position = blockpos,
												block_type = btype,
												extra = {
													rizz = 'No.',
													sigma = 'The...',
													those = workspace.Name == 'Ok'
												}
											})
											fake:Destroy()
											if not (suc or block) then
												bd.Entity.LocalEntity:AddTool(bname, 1)
											end
										end)
									end
								end
								lastpos = currentpos
							end
						end
					end
					task.wait(0.03)
				until not Scaffold.Enabled
			end
		end,
		Tooltip = 'Helps you make bridges/scaffold walk.'
	})
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 6
	})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Default = true
	})
	LimitItem = Scaffold:CreateToggle({Name = 'Limit to items'})
end)
	
run(function()
	local AutoBuy
	local Sword
	local Armor
	local Upgrades
	local NPCs = {}
	local UpgradeToggles = {}
	local Functions = {}
	local Callbacks = {Functions}
	local npctick = tick()
	
	local function canBuy(item, currencytable, amount)
		return (currencytable[item.currency or 'Iron'] or 0) >= (item.cost * (amount or 1))
	end
	
	local function buyItem(item, itemTier, itemCategory, currencytable)
		notif('AutoBuy', 'Bought '..item.name, 3)
		task.spawn(function()
			bd.Blink.player_state.bedwars_buy_item.invoke({
				item = itemCategory or item.name,
				tier = itemTier
			})
		end)
		currencytable[item.currency or 'Iron'] -= item.cost
	end
	
	local function buyTier(category, currencytable)
		local nextItem, itemTier
		for i, v in category.tiers do
			if currencytable[v.name] then
				nextItem, nextTier = category.tiers[i + 1], i + 1
				break
			end
		end
	
		if nextItem and canBuy(nextItem, currencytable) then
			buyItem(nextItem, nextTier, category.name, currencytable)
		end
	end
	
	local function buyUpgrade(upgrade, currencytable)
		local upgradeItem = bd.BedwarsUpgrades[upgrade]
		local localTeam = bd.Entity.LocalEntity.Team or {Name = ''}
		local teamUpgrades = bd.Communication.team_upgrades.value[localTeam.Name] or {}
		local currentTier = (teamUpgrades[upgrade] or 0) + 1
		local bought = false
	
		for i = currentTier, #upgradeItem.tiers do
			local tier = upgradeItem.tiers[i]
	
			if canBuy({currency = 'Diamond', cost = tier.cost}, currencytable) then
				notif('AutoBuy', 'Bought '..upgrade..' '..i, 3)
				task.spawn(function()
					bd.Blink.player_state.bedwars_buy_upgrade.invoke(upgrade)
				end)
				currencytable.Diamond -= tier.cost
				bought = true
			else
				break
			end
		end
	
		return bought
	end
	
	local function getShopNPC()
		local shop, items, upgrades, newid = nil, false, false, nil
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for ent, upgrade in NPCs do
				if (ent.Position - localPosition).Magnitude <= 10 then
					shop = true
					items = items or not upgrade
					upgrades = upgrade or upgrades
				end
			end
		end
		return shop, items, upgrades
	end
	
	AutoBuy = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then
				AutoBuy:Clean(collectionService:GetInstanceAddedSignal('menu_opener'):Connect(function(obj)
					NPCs[obj.Parent] = obj:GetAttribute('menu') == 'TeamUpgrades'
				end))
	
				for _, obj in collectionService:GetTagged('menu_opener') do
					NPCs[obj.Parent] = obj:GetAttribute('menu') == 'TeamUpgrades'
				end
	
				repeat
					local npc, shop, upgrades, newid = getShopNPC()
	
					if npc and npctick <= tick() then
						local currencytable = table.clone(bd.Entity.LocalEntity.Inventory)
						for _, tab in Callbacks do
							for _, callback in tab do
								callback(currencytable, shop, upgrades)
							end
						end
						npctick = tick() + 0.4
					end
	
					task.wait(0.1)
				until not AutoBuy.Enabled
			else
				table.clear(NPCs)
			end
		end,
		Tooltip = 'Automatically buys items when you go near the shop'
	})
	Sword = AutoBuy:CreateToggle({
		Name = 'Buy Sword',
		Function = function(callback)
			npctick = tick()
			Functions[2] = callback and function(currencytable, shop)
				if not shop then return end
				buyTier(bd.BedwarsShop[2].items[1], currencytable)
			end or nil
		end,
		Default = true
	})
	Armor = AutoBuy:CreateToggle({
		Name = 'Buy Armor',
		Function = function(callback)
			npctick = tick()
			Functions[1] = callback and function(currencytable, shop)
				if not shop then return end
				buyTier(bd.BedwarsShop[2].items[2], currencytable)
			end or nil
		end,
		Default = true
	})
	Pickaxe = AutoBuy:CreateToggle({
		Name = 'Buy Pickaxe',
		Function = function(callback)
			npctick = tick()
			Functions[1] = callback and function(currencytable, shop)
				if not shop then return end
				buyTier(bd.BedwarsShop[3].items[1], currencytable)
			end or nil
		end
	})
	Upgrades = AutoBuy:CreateToggle({
		Name = 'Buy Upgrades',
		Function = function(callback)
			for _, v in UpgradeToggles do
				v.Object.Visible = callback
			end
		end,
		Default = true
	})
	local count = 0
	for i, v in bd.BedwarsUpgrades do
		local toggleCount = count
		table.insert(UpgradeToggles, AutoBuy:CreateToggle({
			Name = 'Buy '..i,
			Function = function(callback)
				npctick = tick()
				Functions[5 + toggleCount + (i == 'ArmorProtection' and 20 or 0)] = callback and function(currencytable, shop, upgrades)
					if not upgrades then return end
					return buyUpgrade(i, currencytable)
				end or nil
			end,
			Darker = true,
			Default = (i == 'ArmorProtection' or i == 'SwordDamage')
		}))
		count += 1
	end
	--[[for i, v in bedwars.TeamUpgradeMeta do
		local toggleCount = count
		table.insert(UpgradeToggles, AutoBuy:CreateToggle({
			Name = 'Buy '..(v.name == 'Armor' and 'Protection' or v.name),
			Function = function(callback)
				npctick = tick()
				Functions[5 + toggleCount + (v.name == 'Armor' and 20 or 0)] = callback and function(currencytable, shop, upgrades)
					if not upgrades then return end
					if v.disabledInQueue and table.find(v.disabledInQueue, store.queueType) then return end
					return buyUpgrade(i, currencytable)
				end or nil
			end,
			Darker = true,
			Default = (i == 'ARMOR' or i == 'DAMAGE')
		}))
		count += 1
	end]]
end)
	
run(function()
	local Breaker
	local Value
	local OnlyPlayer
	
	local function getBlocksInPoints(s, e)
		local list = {}
		for x = s.X, e.X, 3 do
			for y = s.Y, e.Y, 3 do
				for z = s.Z, e.Z, 3 do
					local vec = Vector3.new(x, y, z)
					if store.blocks[vec] then
						list[vec] = store.blocks[vec]
					end
				end
			end
		end
		return list
	end
	
	local function getPickaxe()
		for name in bd.Entity.LocalEntity.Inventory do
			if name:find('Pickaxe') then
				return name
			end
		end
	end
	
	Breaker = vape.Categories.Minigames:CreateModule({
		Name = 'Breaker',
		Function = function(callback)
			if callback then
				local breakBlock
				local breakTime = 0
				local lastBreak
	
				repeat
					breakBlock = nil
	
					if entitylib.isAlive then
						local pickaxe = getPickaxe()
	
						if pickaxe then
							local pos = (entitylib.character.RootPart.Position // 3) * 3
							local rvec = Vector3.new(3, 3, 3) * Range.Value
	
							for blockpos, block in getBlocksInPoints(pos - rvec, pos + rvec) do
								if block and block.Name == 'Block' and (block.Parent.Name == 'Bed' and lplr.Team and block.Parent:GetAttribute('Team') ~= lplr.Team.Name) then
									breakBlock = block
									break
								end
							end
	
							if breakBlock ~= lastBreak then
								if breakBlock then
									breakTime = os.clock() + bd.BreakTimes[breakBlock:GetAttribute('block_type') or 'Clay']
									bd.Blink.item_action.start_break_block.fire({
										position = breakBlock.Position,
										pickaxe_name = pickaxe,
										timestamp = workspace:GetServerTimeNow()
									})
								else
									bd.Blink.item_action.stop_break_block.fire(false)
								end
								lastBreak = breakBlock
							elseif breakBlock and breakTime < os.clock() then
								bd.Blink.item_action.stop_break_block.fire(true)
								breakTime = math.huge
							end
						end
					end
					task.wait(1 / 60)
				until not Breaker.Enabled
			end
		end,
		Tooltip = 'Breaks enemy blocks around you'
	})
	Range = Breaker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 5,
		Default = 5,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

-- aero BetterKillaura 
local Attacking
run(function()
    local BetterKillaura
    local Targets
    local Sort
    local SwingRange
    local AttackRange
    local RangeCircle
    local RangeCirclePart
    local UpdateRate
    local AngleSlider
    local MaxTargets
    local Mouse
    local Swing
    local GUI
    local BoxSwingColor
    local BoxAttackColor
    local ParticleTexture
    local ParticleColor1
    local ParticleColor2
    local ParticleSize
    local Face
    local FaceSpeed
    local Animation
    local AnimationMode
    local AnimationSpeed
    local AnimationTween
    local Limit
    local LegitAura
    local SyncHits
    local lastAttackTime = 0
    local lastManualSwing = 0
    local lastSwingServerTime = 0
    local lastSwingServerTimeDelta = 0
    local AttackCheck
    local kitChecks
    local SwingTime
    local SwingTimeSlider
    local swingCooldown = 0
    local ContinueSwinging
    local ContinueSwingTime
    local lastTargetTime = 0
    local continueSwingCount = 0
    local Particles, Boxes = {}, {}
    local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
    local AttackRemote
    local TargetPriority
    local CustomHitReg
    local CustomHitRegSlider
    local lastCustomHitTime = 0
    local AirHit
    local AirHitsChance
    local FROZEN_THRESHOLD = 10
    local FastHits
    local FastHitsMode
    local LegitSwitch
    local OldShootInterval
    local OldSwitchDelay
    local OldWaitDelay
    local OldFirstPersonCheck
    local lastOldShootTime = 0
    local Legit
    local FireRate
    local AutoFireball
    local autoFireballLoop = nil
    local projectileRemote = {InvokeServer = function() end}
    local ProjectileDelay = {}
    local lastShot = tick()
    local Usage = 1

    task.spawn(function()
        AttackRemote = bedwars.Client:Get(remotes.AttackEntity)
        projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)

    local function canHitWithCustomReg()
        if not CustomHitReg or not CustomHitReg.Enabled then return true end
        if not CustomHitRegSlider then return true end
        if CustomHitRegSlider.Value >= 36 then return true end
        local currentTime = tick()
        local delayBetweenHits = 10 / CustomHitRegSlider.Value
        if currentTime - lastCustomHitTime >= delayBetweenHits then
            lastCustomHitTime = lastCustomHitTime + delayBetweenHits
            if currentTime - lastCustomHitTime > delayBetweenHits then
                lastCustomHitTime = currentTime
            end
            return true
        end
        return false
    end

    local _t4LastHit = {}

    local function FireAttackRemote(attackTable, ...)
        if not AttackRemote then return end
        if not canHitWithCustomReg() then return end

        local _atkPlr = playersService:GetPlayerFromCharacter(attackTable.entityInstance)
        local t4ok = _atkPlr ~= nil
        local t4plr = _atkPlr
        if t4ok and t4plr then
			local targetTier = getAccountTier(t4plr)
			if targetTier >= 99 then return end
			if targetTier >= 4 and getAccountTier(lplr) == 0 then
                local uid = t4plr.UserId
                local now = tick()
                if _t4LastHit[uid] and now - _t4LastHit[uid] < (10/32) then return end
                _t4LastHit[uid] = now
            end
        end

        local suc = _atkPlr ~= nil
        local plr = _atkPlr

        local selfpos = attackTable.validate.selfPosition.value
        local targetpos = attackTable.validate.targetPosition.value
        local actualDistance = (selfpos - targetpos).Magnitude

        store.attackReach = (actualDistance * 100) // 1 / 100
        store.attackReachUpdate = tick() + 1

        if actualDistance > 14.4 and actualDistance <= 30 then
            local direction = (targetpos - selfpos).Unit

            local moveDistance = math.min(actualDistance - 14.3, 8)
            attackTable.validate.selfPosition.value = selfpos + (direction * moveDistance)

            local pullDistance = math.min(actualDistance - 14.3, 4)
            attackTable.validate.targetPosition.value = targetpos - (direction * pullDistance)

            attackTable.validate.raycast = attackTable.validate.raycast or {}
            attackTable.validate.raycast.cameraPosition = attackTable.validate.raycast.cameraPosition or {}
            attackTable.validate.raycast.cursorDirection = attackTable.validate.raycast.cursorDirection or {}

            local extendedOrigin = selfpos + (direction * math.min(actualDistance - 12, 15))
            attackTable.validate.raycast.cameraPosition.value = extendedOrigin
            attackTable.validate.raycast.cursorDirection.value = direction

            attackTable.validate.targetPosition = attackTable.validate.targetPosition or {value = targetpos}
            attackTable.validate.selfPosition = attackTable.validate.selfPosition or {value = selfpos}
        end

        if suc and plr then
            if not select(2, whitelist:get(plr)) then return end
        end

        return AttackRemote:SendToServer(attackTable, ...)
    end

    local function createRangeCircle()
        local suc, err = pcall(function()
            if (not shared.CheatEngineMode) then
                RangeCirclePart = Instance.new("MeshPart")
                RangeCirclePart.MeshId = "rbxassetid://3726303797"
                if shared.RiseMode and GuiLibrary.GUICoreColor and GuiLibrary.GUICoreColorChanged then
                    RangeCirclePart.Color = GuiLibrary.GUICoreColor
                    GuiLibrary.GUICoreColorChanged.Event:Connect(function()
                        RangeCirclePart.Color = GuiLibrary.GUICoreColor
                    end)
                else
                    RangeCirclePart.Color = Color3.fromHSV(BoxSwingColor["Hue"], BoxSwingColor["Sat"], BoxSwingColor.Value)
                end
                RangeCirclePart.CanCollide = false
                RangeCirclePart.Anchored = true
                RangeCirclePart.Material = Enum.Material.Neon
                RangeCirclePart.Size = Vector3.new(SwingRange.Value * 0.7, 0.01, SwingRange.Value * 0.7)
                if BetterKillaura.Enabled then
                    RangeCirclePart.Parent = gameCamera
                end
                RangeCirclePart:SetAttribute("gamecore_GameQueryIgnore", true)
            end
        end)
        if (not suc) then
            pcall(function()
                if RangeCirclePart then
                    RangeCirclePart:Destroy()
                    RangeCirclePart = nil
                end
                notif("BetterKillaura - Range Visualiser Circle", "There was an error creating the circle. Disabling...", 2)
            end)
        end
    end

    local function getAttackData()
		if AttackCheck and AttackCheck.Enabled then
			local stunTime = lplr.Character and lplr.Character:GetAttribute('StunnedUntilTime')
			if stunTime and stunTime > workspace:GetServerTimeNow() then return false end
			if kitChecks then
				for _, check in pairs(kitChecks) do
					if check() then return false end
				end
			end
        end

        if Mouse.Enabled then
            local recentSwing = LegitAura.Enabled and (tick() - bedwars.SwordController.lastSwing) <= 0.2
            if not recentSwing then
                local mousePressed = inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                if not mousePressed then 
                    return false 
                end
            end
        end

        if tick() - store.silasAbilityTime < 2.2 then return false end
        if tick() - store.terraStompTime < 0.7 then return false end
        if tick() - store.terraKickTime < 0.5 then return false end

        if GUI.Enabled then
            if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
        end

        local sword = Limit.Enabled and store.hand or store.tools.sword
        if not sword or not sword.tool then return false end

        local meta = bedwars.ItemMeta[sword.tool.Name]
        if Limit.Enabled then
            if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
        end

        if LegitAura.Enabled then
            if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
        end

        if SwingTime.Enabled then
            local swingSpeed = SwingTimeSlider.Value
            return sword, meta, (tick() - lastAttackTime) >= swingSpeed
        else
            return sword, meta, true
        end
    end
    
    local function resetSwordCooldown()
        if bedwars.SwordController then
            bedwars.SwordController.lastAttack = 0
            bedwars.SwordController.lastSwing = 0

            if bedwars.SwordController.lastChargedAttackTimeMap then
                for weaponName, _ in pairs(bedwars.SwordController.lastChargedAttackTimeMap) do
                    bedwars.SwordController.lastChargedAttackTimeMap[weaponName] = 0
                end
            end
        end
    end

    local function shouldContinueSwinging()
        if not ContinueSwinging.Enabled then return false end
        
        if lastTargetTime == 0 then
            return false
        end
        
        local timeSinceLastTarget = tick() - lastTargetTime
        local swingDuration = ContinueSwingTime.Value
        
        if timeSinceLastTarget <= swingDuration then
            return true
        end
        
        return false
    end

    local function getAmmo(check)
        for _, item in store.inventory.inventory.items do
            if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
                return item.itemType
            end
        end
        return
    end

	local _projectilesCache = {}

	local function getProjectiles()
		table.clear(_projectilesCache)
		for _, item in store.inventory.inventory.items do
			local proj = bedwars.ItemMeta[item.itemType].projectileSource
			local ammo = proj and getAmmo(proj)
			if ammo and table.find({'arrow'}, ammo) then
				table.insert(_projectilesCache, {
					item,
					ammo,
					proj.projectileType(ammo),
					proj
				})
			end
		end
		return _projectilesCache
	end

    local function canShoot(proj)
        return tick() > (ProjectileDelay[proj[1].itemType] or 0)
    end

	local function shootFunc(item, ammo, projectile, itemMeta, pos, ent, ign)
		local meta = bedwars.ProjectileMeta[projectile]
		local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
		local switched
		switched = switchItem(item.tool, 0.05)
		local targetBodyPart = ent.RootPart
		local selfVelocity = entitylib.character.RootPart and entitylib.character.RootPart.Velocity or Vector3.zero
		local targetVelocity = targetBodyPart.Velocity
		local playerGravity = workspace.Gravity
		local balloons = ent.Character and ent.Character:GetAttribute('InflatedBalloons')
		if balloons and balloons > 0 then
			playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end
		if ent.Character and ent.Character.PrimaryPart and ent.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
			playerGravity = 6
		end
		if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
			for _, owl in ipairs(collectionService:GetTagged('Owl')) do
				if owl:GetAttribute('Target') == ent.Player.UserId and owl:GetAttribute('Status') == 2 then
					playerGravity = 0
					break
				end
			end
		end
		local bowRelX = bedwars.BowConstantsTable.RelX or 0
		local bowRelY = bedwars.BowConstantsTable.RelY or 0
		local bowRelZ = bedwars.BowConstantsTable.RelZ or 0
		local chestPos = targetBodyPart.Position - Vector3.new(0, ent.HipHeight * 0.3, 0)
		local newlook = CFrame.new(pos, chestPos) * CFrame.new(Vector3.new(bowRelX, bowRelY, bowRelZ))
		local ping = math.clamp(lplr:GetNetworkPing(), 0.03, 0.15)
		local extPos = chestPos + targetVelocity * ping
		local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, extPos, targetVelocity, playerGravity, 0, nil, sharedFastHitsRayParams)
		if calc then
			targetinfo.Targets[ent] = tick() + 1
			task.spawn(function()
				local dir, id = CFrame.lookAt(newlook.Position, calc).LookVector, httpService:GenerateGUID(true)
				local shootPosition = (CFrame.new(newlook.Position, calc) * CFrame.new(Vector3.new(-bowRelX, -bowRelY, -bowRelZ))).Position
				bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
				local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - ping)
				if res then
					pcall(function() res.Parent = replicatedStorage end)
					local shoot = itemMeta.launchSound
					shoot = shoot and shoot[math.random(1, #shoot)] or nil
					if shoot then bedwars.SoundManager:playSound(shoot) end
				else
					ProjectileDelay[item.itemType] = tick() + 0.1
				end
			end)
			ProjectileDelay[item.itemType] = tick() + itemMeta.fireDelaySec
			if switched and not ign then task.wait(0.05) end
		end
	end

    local function doFastHitsLegitSwitch(ent)
        if not ent or not ent.RootPart then return end
        local pos = entitylib.character.RootPart.Position

        local bowItem, bowAmmo, bowProjectile, bowMeta = nil, nil, nil, nil
        for _, item in store.inventory.inventory.items do
            local _itemMeta = bedwars.ItemMeta[item.itemType]
            local proj = _itemMeta and _itemMeta.projectileSource
            if not proj then continue end
            for _, inv in store.inventory.inventory.items do
                if proj.ammoItemTypes and table.find(proj.ammoItemTypes, inv.itemType) then
                    bowItem = item
                    bowAmmo = inv.itemType
                    bowProjectile = proj.projectileType(inv.itemType)
                    bowMeta = bedwars.ProjectileMeta[bowProjectile]
                    break
                end
            end
            if bowItem then break end
        end

        if not bowItem or not bowMeta then return end
        if (FastHitsFireDelays[bowItem.itemType] or 0) >= tick() then return end

        local bowSlot = nil
        local hotbar = store.inventory.hotbar
        for i = 1, #hotbar do
            local v = hotbar[i]
            if v and v.item and v.item == bowItem then
                bowSlot = i - 1
                break
            end
        end
        if not bowSlot then return end

        local originalSlot = store.inventory.hotbarSlot
        if hotbarSwitch(bowSlot) then task.wait(0.05) end

        local holdingCrossbow = bowItem.itemType:find('crossbow')
        local holdingBow = bowItem.itemType:find('bow') and not holdingCrossbow
        if holdingCrossbow then
            pcall(function() bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE) end)
            bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.CROSSBOW_FIRE)
        elseif holdingBow then
            pcall(function() bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE) end)
            bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.BOW_FIRE)
        else
            local shootAnim = bedwars.ItemMeta[bowItem.tool.Name].thirdPerson and bedwars.ItemMeta[bowItem.tool.Name].thirdPerson.shootAnimation
            if shootAnim then
                bedwars.GameAnimationUtil:playAnimation(lplr, shootAnim)
            end
        end

        local meta = bowMeta
        local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
        local bowRelX = bedwars.BowConstantsTable.RelX or 0
        local bowRelY = bedwars.BowConstantsTable.RelY or 0
        local bowRelZ = bedwars.BowConstantsTable.RelZ or 0
        local newlook = CFrame.new(pos, ent.RootPart.Position) * CFrame.new(Vector3.new(bowRelX, bowRelY, bowRelZ))
        local playerGravityLS = workspace.Gravity
        local balloonsLS = ent.Character and ent.Character:GetAttribute('InflatedBalloons')
        if balloonsLS and balloonsLS > 0 then
            playerGravityLS = workspace.Gravity * (1 - (balloonsLS >= 4 and 1.2 or balloonsLS >= 3 and 1 or 0.975))
        end
        if ent.Character and ent.Character.PrimaryPart and ent.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
            playerGravityLS = 6
        end
        if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
            for _, owl in ipairs(collectionService:GetTagged('Owl')) do
                if owl:GetAttribute('Target') == ent.Player.UserId and owl:GetAttribute('Status') == 2 then
                    playerGravityLS = 0
                    break
                end
            end
        end

        local _pingLS = lplr:GetNetworkPing()
        local _extPosLS = ent.RootPart.Position + ent.RootPart.Velocity * _pingLS
        local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, _extPosLS, ent.RootPart.Velocity, playerGravityLS, ent.HipHeight, ent.Jumping and 42.6 or nil, sharedFastHitsRayParams)

        if calc then
            targetinfo.Targets[ent] = tick() + 1
            task.spawn(function()
                local dir = CFrame.lookAt(newlook.Position, calc).LookVector
                local id = httpService:GenerateGUID(true)
                local shootPosition = (CFrame.new(newlook.Position, calc) * CFrame.new(Vector3.new(-bowRelX, -bowRelY, -bowRelZ))).Position
                bedwars.ProjectileController:createLocalProjectile(meta, bowAmmo, bowProjectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
                local ping = math.clamp(lplr:GetNetworkPing(), 0.02, 0.2)
                local res = projectileRemote:InvokeServer(bowItem.tool, bowAmmo, bowProjectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - ping)
                if not res then
                    FastHitsFireDelays[bowItem.itemType] = tick()
                else
                    local shoot = bowMeta.launchSound
                    shoot = shoot and shoot[math.random(1, #shoot)] or nil
                    if shoot then bedwars.SoundManager:playSound(shoot) end
                end
            end)
            FastHitsFireDelays[bowItem.itemType] = tick() + AutoShootInterval.Value
        end

        task.wait(0.05)
        hotbarSwitch(originalSlot)
    end

    local function doFastHitsNEW(ent)
        if not ent or not ent.RootPart then return end
        local pos = entitylib.character.RootPart.Position
        local projectiles = getProjectiles()
        NEWFastHitsUsage += 1
        if not projectiles[NEWFastHitsUsage] then NEWFastHitsUsage = 1 end
        if projectiles and projectiles[NEWFastHitsUsage] and canShoot(projectiles[NEWFastHitsUsage]) then
            local item, ammo, projectile, itemMeta = unpack(projectiles[NEWFastHitsUsage])
            shootFunc(item, ammo, projectile, itemMeta, pos, ent)
        end
    end

	local function startAutoFireballLoop()
        if autoFireballLoop then return end
        autoFireballLoop = task.spawn(function()
            while AutoFireball and AutoFireball.Enabled do
                if entitylib.isAlive then
                    local pos = entitylib.character.RootPart.Position
                    local closest = store.BetterKillauraTarget
                    if closest and closest.RootPart and BetterKillaura.Enabled then
						local _afbRayParams = RaycastParams.new()
						local function shootProj(ammoType)
							local items = getProjectileItems({ammoType})
							local proj = items and items[1]
							if not proj then return end
							local item, ammo, projectile, itemMeta = unpack(proj)
							local meta = bedwars.ProjectileMeta[projectile]
							if not meta then return end
							local projSpeed = meta.launchVelocity
							local gravity = meta.gravitationalAcceleration or 196.2
							local targetPart = closest.RootPart
							local bowRelX = bedwars.BowConstantsTable.RelX or 0
							local bowRelY = bedwars.BowConstantsTable.RelY or 0
							local bowRelZ = bedwars.BowConstantsTable.RelZ or 0
							local _afbChest = targetPart.Position - Vector3.new(0, (closest.HipHeight or 2) * 0.3, 0)
							local newlook = CFrame.new(pos, _afbChest) * CFrame.new(Vector3.new(bowRelX, bowRelY, bowRelZ))
							local _pingAFB = math.clamp(lplr:GetNetworkPing(), 0.03, 0.15)
							local _extPosAFB = _afbChest + targetPart.Velocity * _pingAFB
							local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, _extPosAFB, targetPart.Velocity, workspace.Gravity, 0, nil, _afbRayParams)
							if calc then
								switchItem(item.tool, 0.05)
								local dir = CFrame.lookAt(newlook.Position, calc).LookVector
								local id = httpService:GenerateGUID(true)
								local shootPos = (CFrame.new(newlook.Position, calc) * CFrame.new(Vector3.new(-bowRelX, -bowRelY, -bowRelZ))).Position
								bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPos, id, dir * projSpeed, {drawDurationSeconds = 1})
								task.spawn(function()
									local _afbPing = math.clamp(lplr:GetNetworkPing(), 0.03, 0.2)
									local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPos, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - _afbPing)
									if res then pcall(function() res.Parent = replicatedStorage end) end
								end)
							end
						end
                        shootProj('fireball')
                        task.wait(0.6)
                        if closest and closest.RootPart and (not closest.Health or closest.Health > 0) then
                            shootProj('arrow')
                        end
                        task.wait(1.5)
                    end
                end
                task.wait(0.05)
            end
            autoFireballLoop = nil
        end)
    end

    local function stopAutoFireballLoop()
        if autoFireballLoop then
            task.cancel(autoFireballLoop)
            autoFireballLoop = nil
        end
    end

    local rayCheckFastHits = cloneRaycast()
	local sharedFastHitsRayParams = RaycastParams.new()
    local function doFastHitsProjectileAura(ent)
        if not ent or not ent.RootPart then return end
        local pos = entitylib.character.RootPart.Position

        local bowItem, bowAmmo, bowProjectile, bowMeta = nil, nil, nil, nil
        for _, item in store.inventory.inventory.items do
            local _itemMeta = bedwars.ItemMeta[item.itemType]
            local proj = _itemMeta and _itemMeta.projectileSource
            if not proj then continue end
            for _, inv in store.inventory.inventory.items do
                if proj.ammoItemTypes and table.find(proj.ammoItemTypes, inv.itemType) then
                    bowItem = item
                    bowAmmo = inv.itemType
                    bowProjectile = proj.projectileType(inv.itemType)
                    bowMeta = bedwars.ProjectileMeta[bowProjectile]
                    break
                end
            end
            if bowItem then break end
        end

        if not bowItem or not bowMeta then return end
        if (FastHitsFireDelays[bowItem.itemType] or 0) >= tick() then return end

        local originalSlot = store.inventory.hotbarSlot
        local switched = switchItem(bowItem.tool)
        if switched then task.wait(0.05) end

        local meta = bowMeta
        local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
        local bowRelX = bedwars.BowConstantsTable.RelX or 0
        local bowRelY = bedwars.BowConstantsTable.RelY or 0
        local bowRelZ = bedwars.BowConstantsTable.RelZ or 0
        local newlook = CFrame.new(pos, ent.RootPart.Position) * CFrame.new(Vector3.new(bowRelX, bowRelY, bowRelZ))
        local playerGravityPA = workspace.Gravity
        local balloonsPA = ent.Character and ent.Character:GetAttribute('InflatedBalloons')
        if balloonsPA and balloonsPA > 0 then
            playerGravityPA = workspace.Gravity * (1 - (balloonsPA >= 4 and 1.2 or balloonsPA >= 3 and 1 or 0.975))
        end
        if ent.Character and ent.Character.PrimaryPart and ent.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
            playerGravityPA = 6
        end
        if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
            for _, owl in ipairs(collectionService:GetTagged('Owl')) do
                if owl:GetAttribute('Target') == ent.Player.UserId and owl:GetAttribute('Status') == 2 then
                    playerGravityPA = 0
                    break
                end
            end
        end
        local _pingPA = lplr:GetNetworkPing()
        local _extPosPA = ent.RootPart.Position + ent.RootPart.Velocity * _pingPA
        local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, _extPosPA, ent.RootPart.Velocity, playerGravityPA, ent.HipHeight, ent.Jumping and 42.6 or nil, sharedFastHitsRayParams)

        if calc then
            targetinfo.Targets[ent] = tick() + 1

            task.spawn(function()
                local dir = CFrame.lookAt(newlook.Position, calc).LookVector
                local id = httpService:GenerateGUID(true)
                local shootPosition = (CFrame.new(newlook.Position, calc) * CFrame.new(Vector3.new(-bowRelX, -bowRelY, -bowRelZ))).Position

                local holdingCrossbow = bowItem.itemType:find('crossbow')
                local holdingBow = bowItem.itemType:find('bow') and not holdingCrossbow
                if holdingCrossbow then
                    pcall(function() bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE) end)
                    bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.CROSSBOW_FIRE)
                elseif holdingBow then
                    pcall(function() bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_CROSSBOW_FIRE) end)
                    bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.AnimationType.BOW_FIRE)
                else
                    local shootAnim = bedwars.ItemMeta[bowItem.tool.Name].thirdPerson and bedwars.ItemMeta[bowItem.tool.Name].thirdPerson.shootAnimation
                    if shootAnim then
                        bedwars.GameAnimationUtil:playAnimation(lplr, shootAnim)
                    end
                end

                bedwars.ProjectileController:createLocalProjectile(meta, bowAmmo, bowProjectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
                local ping = math.clamp(lplr:GetNetworkPing(), 0.02, 0.2)
                local res = projectileRemote:InvokeServer(bowItem.tool, bowAmmo, bowProjectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - ping)
                if not res then
                    FastHitsFireDelays[bowItem.itemType] = tick()
                else
                    local shoot = bowItem.launchSound
                    shoot = shoot and shoot[math.random(1, #shoot)] or nil
                    if shoot then bedwars.SoundManager:playSound(shoot) end
                end
            end)

            FastHitsFireDelays[bowItem.itemType] = tick() + AutoShootInterval.Value
            if switched then
                task.wait(0.05)
                hotbarSwitch(originalSlot)
            end
        end
    end

    local function doFastHitsVirtualInput(ent)
        if not ent or not ent.RootPart then return end
        if not hasArrows() then return end
        if FirstPersonCheck.Enabled and not isFirstPerson() then return end

        local currentTime = tick()
        if (currentTime - lastAutoShootTime) < AutoShootInterval.Value then return end

        local bows = getBows()
        if #bows == 0 then return end
        local bowSlot = bows[1]
        local originalSlot = store.inventory.hotbarSlot

        if hotbarSwitch(bowSlot) then
            task.wait(AutoShootSwitchSpeed.Value)
            local hotbarItem = store.inventory.hotbar[bowSlot + 1]
            if hotbarItem and hotbarItem.item then
                local itemMeta = bedwars.ItemMeta[hotbarItem.item.itemType]
                if itemMeta and itemMeta.projectileSource then
                    local projSource = itemMeta.projectileSource
                    if projSource.ammoItemTypes and #projSource.ammoItemTypes > 0 then
                        local ammo = projSource.ammoItemTypes[1]
                        local projectile = nil
                        if type(projSource.projectileType) == "function" then
                            local success, result = pcall(function() return projSource.projectileType(ammo) end)
                            if success then projectile = result end
                        else
                            projectile = projSource.projectileType
                        end
                        if projectile then
                            local pos = entitylib.character.RootPart.Position
                            if AutoShootWaitDelay.Value > 0 then task.wait(AutoShootWaitDelay.Value) end

                            local meta = bedwars.ProjectileMeta[projectile]
                            local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
                            local calc = prediction.SolveTrajectory(pos, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.Velocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheckFastHits)

                            if calc then
                                local dir = CFrame.lookAt(pos, calc).LookVector
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                                task.wait(0.05)
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                            else
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                                task.wait(0.05)
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                            end
                        end
                    end
                end
            end
            task.wait(0.05)
        end

        local swordSlot = getSwordSlot()
        if swordSlot then
            hotbarSwitch(swordSlot)
        else
            hotbarSwitch(originalSlot)
        end

        lastAutoShootTime = currentTime  
    end

    local function getEntityFromCharacterFH(char)
        for _, ent in ipairs(entitylib.List) do
            if ent.Character == char then return ent end
        end
        return nil
    end

    local function doOldFastHits()
        if not store.BetterKillauraTarget then return end

        local currentTime = tick()
        if (currentTime - lastOldShootTime) < OldShootInterval.Value then return end

        if OldFirstPersonCheck and OldFirstPersonCheck.Enabled then
            local cf = gameCamera.CFrame
            local char = entitylib.character
            if char and char.RootPart then
                local dist = (cf.Position - char.RootPart.Position).Magnitude
                if dist > 1 then return end
            end
        end

        local arrowItem = getItem('arrow')
        if not arrowItem or arrowItem.amount <= 0 then return end

        local bows = {}
        local swordSlot = nil
        local hotbar = store.inventory.hotbar
        for i = 1, #hotbar do
            local v = hotbar[i]
            if v and v.item and v.item.itemType then
                local itemMeta = bedwars.ItemMeta[v.item.itemType]
                if itemMeta then
                    if itemMeta.projectileSource then
                        local ps = itemMeta.projectileSource
                        if ps.ammoItemTypes and table.find(ps.ammoItemTypes, 'arrow') then
                            table.insert(bows, i - 1)
                        end
                    end
                    if itemMeta.sword and not swordSlot then
                        swordSlot = i - 1
                    end
                end
            end
        end

        if #bows == 0 then return end

        lastOldShootTime = currentTime
        local originalSlot = store.inventory.hotbarSlot

        for i = 1, #bows do
            local bowSlot = bows[i]
            if hotbarSwitch(bowSlot) then
                task.wait(OldSwitchDelay.Value)
                leftClick()
                task.wait(0.05)
            end
        end

        if swordSlot then
            hotbarSwitch(swordSlot)
        else
            hotbarSwitch(originalSlot)
        end
    end

    local function doFastHits()
        if not FastHits.Enabled then return end
        if not Attacking then return end
        if not store.BetterKillauraTarget then return end

        if FastHitsHitsRequiredToggle and FastHitsHitsRequiredToggle.Enabled then
            if not fastHitsActivationReady then return end
            if fastHitsTrackedEntity and fastHitsTrackedEntity ~= store.BetterKillauraTarget then
                fastHitsActivationReady = false
                return
            end
        end

        local ent = store.BetterKillauraTarget
        if not ent or not ent.RootPart then return end

        local selfpos = entitylib.character.RootPart.Position
        local dist = (ent.RootPart.Position - selfpos).Magnitude
        if dist > (AttackRange.Value + 1) then return end

        if FastHitsMode.Value == 'OGFastHits' then
            doFastHitsVirtualInput(ent)
        elseif FastHitsMode.Value == 'NEWFastHits' then
            if LegitSwitch and LegitSwitch.Enabled then
                doFastHitsLegitSwitch(ent)
            else
                doFastHitsNEW(ent)
            end
        end
    end

    local function startAutoShootLoop()
        if autoShootLoop then return end

        fastHitsHitTarget = nil
        fastHitsTrackedEntity = nil
        fastHitsHitCount = 0
        fastHitsActivationReady = false
        fastHitsLastHitTime = 0

        if FastHitsHitsRequiredToggle and FastHitsHitsRequiredToggle.Enabled then
            local hitsRequiredConn
            hitsRequiredConn = vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                if not FastHits.Enabled or not FastHitsHitsRequiredToggle.Enabled then return end
                local attackerChar = damageTable.fromEntity
                local victimChar = damageTable.entityInstance
                if not attackerChar or not victimChar then return end
                local isLocalAttacker = lplr.Character and attackerChar == lplr.Character
                if not isLocalAttacker then
                    local ap = playersService:GetPlayerFromCharacter(attackerChar)
                    if ap == lplr then isLocalAttacker = true end
                end
                if not isLocalAttacker then return end
                local now = tick()
                if now - fastHitsLastHitTime < FASTHITS_HIT_DEBOUNCE then return end
                fastHitsLastHitTime = now
                local victimEnt = getEntityFromCharacterFH(victimChar)
                if not victimEnt then return end
                if fastHitsHitTarget == victimChar then
                    fastHitsHitCount = fastHitsHitCount + 1
                else
                    fastHitsHitTarget = victimChar
                    fastHitsTrackedEntity = victimEnt
                    fastHitsHitCount = 1
                    fastHitsActivationReady = false
                end
                if fastHitsHitCount >= (FastHitsHitsRequiredSlider and FastHitsHitsRequiredSlider.Value or 2) then
                    fastHitsActivationReady = true
                end
			end)
            FastHits:Clean(hitsRequiredConn)
        end

        autoShootLoop = task.spawn(function()
            while BetterKillaura.Enabled and FastHits.Enabled do
                doFastHits()
                task.wait(0.05)  
            end
            autoShootLoop = nil
        end)
    end

    local function stopAutoShootLoop()
        if autoShootLoop then
            task.cancel(autoShootLoop)
            autoShootLoop = nil
        end
        table.clear(FastHitsFireDelays)
        table.clear(NEWFastHitsProjectileDelay)
        NEWFastHitsLastShot = 0
        NEWFastHitsUsage = 1
        fastHitsHitTarget = nil
        fastHitsTrackedEntity = nil
        fastHitsHitCount = 0
        fastHitsActivationReady = false
        fastHitsLastHitTime = 0
    end
    
    BetterKillaura = vape.Categories.Blatant:CreateModule({
        Name = 'BetterKillaura',
        Function = function(callback)
            if callback then 
				local attacked = {}   
                lastSwingServerTime = Workspace:GetServerTimeNow()
                lastSwingServerTimeDelta = 0
                lastAttackTime = 0
                swingCooldown = 0
                resetSwordCooldown() 
                lastTargetTime = 0 
                continueSwingCount = 0
                if Mouse and LegitAura and Mouse.Enabled and LegitAura.Enabled then
                    Mouse:Toggle(false)
                    LegitAura:Toggle(false)
                    notif("BetterKillaura", "yo u cant have require mouse down AND swing only both on at da same time turned both off 4 u", 5)
                end

                if RangeCircle.Enabled then
                    createRangeCircle()
                end
                if inputService.TouchEnabled and not preserveSwordIcon then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
                    end)
                end

                if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
                    local fake = {
                        Controllers = {
                            ViewmodelController = {
                                isVisible = function()
                                    return not Attacking
                                end,
                                playAnimation = function(...)
                                    local args = {...}
                                    if not Attacking then
                                        pcall(function()
                                            bedwars.ViewmodelController:playAnimation(select(2, unpack(args)))
                                        end)
                                    end
                                end
                            }
                        }
                    }

                    task.spawn(function()
                        local started = false
                        repeat
                            if Attacking then
                                if not armC0 then
                                    armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
                                end
                                local first = not started
                                started = true

                                if AnimationMode.Value == 'Random' then
                                    anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
                                end

                                for _, v in anims[AnimationMode.Value] do
                                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
                                        C0 = armC0 * v.CFrame
                                    })
                                    AnimTween:Play()
                                    AnimTween.Completed:Wait()
                                    first = false
                                    if (not BetterKillaura.Enabled) or (not Attacking) then break end
                                end
                            elseif started then
                                started = false
                                AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                                    C0 = armC0
                                })
                                AnimTween:Play()
                            end

                            if not started then
                                task.wait(1 / UpdateRate.Value)
                            end
                        until (not BetterKillaura.Enabled) or (not Animation.Enabled)
                    end)
                end

				local _gatherSwing = {}
				local _gatherAttack = {}
				local _sortWrapA = {Entity = nil}
				local _sortWrapB = {Entity = nil}

				local function gatherTargets(selfpos)
					local swingPlrs = entitylib.AllPosition({
						Range = SwingRange.Value,
						Wallcheck = Targets.Walls.Enabled or nil,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Limit = MaxTargets.Value,
						Sort = sortmethods[Sort.Value]
					})
					local attackPlrs = entitylib.AllPosition({
						Range = AttackRange.Value,
						Wallcheck = Targets.Walls.Enabled or nil,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Limit = MaxTargets.Value,
						Sort = sortmethods[Sort.Value]
					})
					return swingPlrs, attackPlrs
				end

                local _cachedSwordType = nil
                local _cachedIsClaw = false

                repeat
					if AttackCheck and AttackCheck.Enabled then
						local triggered = false
						local stunTime = lplr.Character and lplr.Character:GetAttribute('StunnedUntilTime')
						if stunTime and stunTime > workspace:GetServerTimeNow() then triggered = true end
						if not triggered and kitChecks then
							for _, check in pairs(kitChecks) do
								if check() then triggered = true break end
							end
						end
                        if triggered then
                            Attacking = false
                            store.BetterKillauraTarget = nil
                            task.wait(0.3)
                            continue
                        end
                    end
                    
                    pcall(function()
                        if entitylib.isAlive and entitylib.character.HumanoidRootPart then
                            RangeCirclePart.Position = entitylib.character.HumanoidRootPart.Position - Vector3.new(0, entitylib.character.Humanoid.HipHeight, 0)
                        end
                    end)
					table.clear(attacked)
					local sword, meta, canAttack = getAttackData()
                    Attacking = false
                    store.BetterKillauraTarget = nil

                    if vapeTargetInfo and vapeTargetInfo.Targets then
                        vapeTargetInfo.Targets.BetterKillaura = nil
                    end

                    if sword and canAttack then
                        if sword.itemType ~= _cachedSwordType then
                            _cachedSwordType = sword.itemType
                            _cachedIsClaw = sword.itemType and sword.itemType:find("summoner_claw") ~= nil
                        end
                        local isClaw = _cachedIsClaw
                        
                        local selfpos = entitylib.character.RootPart.Position
                        local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
                        local maxAngle = math.rad(AngleSlider.Value) / 2
                        local swingPlrs, attackPlrs = gatherTargets(selfpos)
                        
                        local hasValidSwingTargets = false
                        local hasValidAttackTargets = false
                        
                        for _, v in swingPlrs do
                            local delta = (v.RootPart.Position - selfpos)
                            local _hd1 = delta * Vector3.new(1, 0, 1)
                            local angle = _hd1.Magnitude > 0.01 and math.acos(math.clamp(localfacing:Dot(_hd1.Unit), -1, 1)) or 0
                            if angle <= maxAngle then
                                hasValidSwingTargets = true
                                break
                            end
                        end
                        
                        for _, v in attackPlrs do
                            local delta = (v.RootPart.Position - selfpos)
                            local _hd2 = delta * Vector3.new(1, 0, 1)
                            local angle = _hd2.Magnitude > 0.01 and math.acos(math.clamp(localfacing:Dot(_hd2.Unit), -1, 1)) or 0
                            if angle <= maxAngle then  
                                hasValidAttackTargets = true
                                break
                            end
                        end
                        
                        if hasValidSwingTargets or hasValidAttackTargets then
                            lastTargetTime = tick()
                        end
                        
                        local shouldSwing = hasValidSwingTargets or hasValidAttackTargets or shouldContinueSwinging()
                        
                        if shouldSwing then
                            switchItem(sword.tool, 0)
                            
                            if hasValidAttackTargets then
                                for _, v in attackPlrs do
                                    local delta = (v.RootPart.Position - selfpos)
                                    local _hd3 = delta * Vector3.new(1, 0, 1)
                                    local angle = _hd3.Magnitude > 0.01 and math.acos(math.clamp(localfacing:Dot(_hd3.Unit), -1, 1)) or 0
                                    local swingAngle = math.rad(AngleSlider.Value)
                                    if angle > (swingAngle / 2) then continue end

                                    table.insert(attacked, {
                                        Entity = v,
                                        Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
                                    })
                                    targetinfo.Targets[v] = tick() + 1

                                    if vapeTargetInfo and vapeTargetInfo.Targets then
                                        local _vapeBetterKillauraInfo = {
                                            Humanoid = {Health = 0, MaxHealth = 0},
                                            Player = nil
                                        }
                                        _vapeBetterKillauraInfo.Humanoid.Health = v.Health
                                        _vapeBetterKillauraInfo.Humanoid.MaxHealth = v.MaxHealth
                                        _vapeBetterKillauraInfo.Player = v.Player
                                        vapeTargetInfo.Targets.BetterKillaura = _vapeBetterKillauraInfo
                                    end

                                    if not Attacking then
                                        Attacking = true
                                        store.BetterKillauraTarget = v
                                        if not isClaw then
                                            local inLegitRange = delta.Magnitude < 14.4
                                            local allowSwingAnim = not Swing.Enabled and AnimDelay <= tick() and (not LegitAura.Enabled or (not LegitAura.Enabled and not Mouse.Enabled) or (inLegitRange and (tick() - swingCooldown) >= math.max(SwingTime.Enabled and SwingTimeSlider.Value or 0.25, 0.11)))
                                            if allowSwingAnim then
                                                local swingSpeed = 0.25
                                                if SwingTime.Enabled then
                                                    swingSpeed = math.max(SwingTimeSlider.Value, 0.11)
                                                elseif meta.sword.respectAttackSpeedForEffects then
                                                    swingSpeed = meta.sword.attackSpeed
                                                end
                                                AnimDelay = tick() + swingSpeed
                                                pcall(function()
                                                    bedwars.SwordController:playSwordEffect(meta, false)
                                                    if meta.displayName:find(' Scythe') then
                                                        bedwars.ScytheController:playLocalAnimation()
                                                    end
                                                end)
                                                if vape.ThreadFix and setthreadidentity then
                                                    pcall(setthreadidentity, 8)
                                                end
                                            end
                                        end
                                    end

                                    local canHit = delta.Magnitude <= AttackRange.Value
                                    local fastHitsRange = delta.Magnitude <= (AttackRange.Value + 1)

                                    if not canHit and not fastHitsRange then continue end

                                    if AirHit and AirHit.Enabled then
                                        local humanoid = v.Character:FindFirstChildOfClass("Humanoid")
                                        if humanoid then
                                            local state = humanoid:GetState()
                                            if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Physics then
                                                if math.random(1, 100) > AirHitsChance.Value then
                                                    continue
                                                end
                                            end
                                        end
                                    end

                                    local swingSpeed = SwingTime.Enabled and SwingTimeSlider.Value or (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0.42)
                                    if SyncHits.Enabled then
                                        local timeSinceLastSwing = tick() - swingCooldown
                                        local requiredDelay = math.max(swingSpeed * 0.15, 0.03)
                                        
                                        if timeSinceLastSwing < requiredDelay then 
                                            continue 
                                        end
                                    end

                                    local actualRoot = v.Character.PrimaryPart
                                    if actualRoot then
                                        local pos = selfpos
                                        local targetPos = actualRoot.Position
                                        local camPos = gameCamera.CFrame.Position
                                        local dir = (targetPos - camPos).Unit

                                        if not SyncHits.Enabled or (tick() - swingCooldown) >= math.max(swingSpeed * 0.15, 0.03) then
                                            swingCooldown = tick()
                                        end
                                        lastSwingServerTimeDelta = workspace:GetServerTimeNow() - lastSwingServerTime
                                        lastSwingServerTime = workspace:GetServerTimeNow()

                                        store.attackReach = (delta.Magnitude * 100) // 1 / 100
                                        store.attackReachUpdate = tick() + 1

                                        if SwingTime.Enabled then
                                            lastAttackTime = tick()

                                            if delta.Magnitude < 14.4 and SwingTimeSlider.Value > 0.11 then
                                                AnimDelay = tick()
                                            end
                                        else
                                            lastAttackTime = tick()
                                        end

                                        if isClaw then
                                            KaidaController:request(v.Character)
                                        else
                                            local attackData = {
                                                weapon = sword.tool,
                                                entityInstance = v.Character,
                                                chargedAttack = {chargeRatio = 0},
                                                validate = {
                                                    raycast = {
                                                        cameraPosition = {value = camPos},
                                                        cursorDirection = {value = dir}
                                                    },
                                                    targetPosition = {value = targetPos},
                                                    selfPosition = {value = pos}
                                                }
                                            }
                                            
											if canHit then
                                                FireAttackRemote(attackData)
                                            end

											if FastHits.Enabled and (not (AutoFireball and AutoFireball.Enabled) or (LegitSwitch and LegitSwitch.Enabled)) and not autoShootLoop then
												if FastHitsMode.Value == 'NEWFastHits' then
													if delta.Magnitude <= (AttackRange.Value + 13) and (tick() - lastShot) >= (0.2 + lplr:GetNetworkPing() + FireRate.Value) then
														local projectiles = getProjectiles()
														Usage += 1
														if not projectiles[Usage] then Usage = 1 end
														if projectiles and projectiles[Usage] and canShoot(projectiles[Usage]) then
															local item, ammo, projectile, itemMeta = unpack(projectiles[Usage])
															if LegitSwitch and LegitSwitch.Enabled then
																local bowSlot = nil
																local swordSlot = nil
																local originalSlot = store.inventory.hotbarSlot
																local hotbar = store.inventory.hotbar
																for i = 1, #hotbar do
																	local hv = hotbar[i]
																	if hv and hv.item and hv.item.itemType then
																		if hv.item.itemType == item.itemType and not bowSlot then
																			bowSlot = i - 1
																		end
																		local hm = bedwars.ItemMeta[hv.item.itemType]
																		if hm and hm.sword and not swordSlot then
																			swordSlot = i - 1
																		end
																	end
																end
																if bowSlot then
																	bedwars.Store:dispatch({type = 'InventorySelectHotbarSlot', slot = bowSlot})
																	shootFunc(item, ammo, projectile, itemMeta, selfpos, v, false)
																	bedwars.Store:dispatch({type = 'InventorySelectHotbarSlot', slot = swordSlot or originalSlot})
																end
															else
																shootFunc(item, ammo, projectile, itemMeta, selfpos, v, true)
															end
															lastShot = tick()
														end
													end
												elseif FastHitsMode.Value == 'OLDFastHits' then
													doOldFastHits()
												end
											end
                                        end
                                    end
                                end
                            else
                                Attacking = true
                                if not isClaw then
                                    if not Swing.Enabled and AnimDelay <= tick() and not LegitAura.Enabled then
                                        local swingSpeed = 0.25
                                        if SwingTime.Enabled then
                                            swingSpeed = math.max(SwingTimeSlider.Value, 0.11)
                                        elseif meta.sword.respectAttackSpeedForEffects then
                                            swingSpeed = meta.sword.attackSpeed
                                        end
                                        AnimDelay = tick() + swingSpeed
                                        pcall(function()
                                            bedwars.SwordController:playSwordEffect(meta, false)
                                            if meta.displayName:find(' Scythe') then
                                                bedwars.ScytheController:playLocalAnimation()
                                            end
                                        end)
                                        if vape.ThreadFix and setthreadidentity then
                                            pcall(setthreadidentity, 8)
                                        end
                                    end
                                end

                                local currentSwingSpeed = SwingTime.Enabled and SwingTimeSlider.Value or (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0.42)
                                local minSwingDelay = math.max(currentSwingSpeed, 0.05)
                                
                                if not SyncHits.Enabled or (tick() - swingCooldown) >= minSwingDelay then
                                    swingCooldown = tick()
                                end
                            end
                        end
                    end

                    pcall(function()
                        for i, v in Boxes do
                            v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
                            if v.Adornee then
                                v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
                                v.Transparency = 1 - attacked[i].Check.Opacity
                            end
                        end

                        for i, v in Particles do
                            v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
                            v.Parent = attacked[i] and gameCamera or nil
                        end
                    end)

                    if Face.Enabled and attacked[1] then
                        if true then
                            local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
                            local targetCFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
                            local speed = FaceSpeed and FaceSpeed.Value or 15
                            local alpha = math.clamp(speed / 100, 0.01, 1)
                            entitylib.character.RootPart.CFrame = entitylib.character.RootPart.CFrame:Lerp(targetCFrame, alpha)
                        end
                    end
                    pcall(function() if RangeCirclePart ~= nil then RangeCirclePart.Parent = gameCamera end end)

                    task.wait(1 / UpdateRate.Value)
                until not BetterKillaura.Enabled
            else
                table.clear(ProjectileDelay)
                store.BetterKillauraTarget = nil
                for _, v in Boxes do
                    v.Adornee = nil
                end
                for _, v in Particles do
                    v.Parent = nil
                end
                if inputService.TouchEnabled then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['2'].Visible = true
                    end)
                end
                Attacking = false
                if armC0 then
                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                        C0 = armC0
                    })
                    AnimTween:Play()
                end
                if RangeCirclePart ~= nil then RangeCirclePart:Destroy() end
            end
        end,
        Tooltip = 'Attack players around you\nwithout aiming at them.'
    })

    pcall(function()
        local PSI = BetterKillaura:CreateToggle({
            Name = 'Preserve Sword Icon',
            Function = function(callback)
                preserveSwordIcon = callback
            end,
            Default = true
        })
        PSI.Object.Visible = inputService.TouchEnabled
    end)

    Targets = BetterKillaura:CreateTargets({
        Players = true,
        NPCs = true
    })
    
    TargetPriority = BetterKillaura:CreateDropdown({
        Name = 'Target Priority',
        List = {'Players First', 'NPCs First', 'Distance'},
        Default = 'Players First',
        Tooltip = 'Choose which targets to prioritize'
    })
    
    local methods = {'Damage', 'Distance'}
    for i in sortmethods do
        if not table.find(methods, i) then
            table.insert(methods, i)
        end
    end
    SwingRange = BetterKillaura:CreateSlider({
        Name = 'Swing range',
        Min = 1,
        Max = 40, 
        Default = 22, 
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    AttackRange = BetterKillaura:CreateSlider({
        Name = 'Attack range',
        Min = 1,
        Max = 22,
        Default = 22, 
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    RangeCircle = BetterKillaura:CreateToggle({
        Name = "Range Visualiser",
        Function = function(call)
            if call then
                createRangeCircle()
            else
                if RangeCirclePart then
                    RangeCirclePart:Destroy()
                    RangeCirclePart = nil
                end
            end
        end
    })
    AngleSlider = BetterKillaura:CreateSlider({
        Name = 'Max angle',
        Min = 1,
        Max = 360,
        Default = 360
    })
    UpdateRate = BetterKillaura:CreateSlider({
        Name = 'Update rate',
        Min = 1,
        Max = 120,
        Default = 60,
        Suffix = 'hz'
    })
    MaxTargets = BetterKillaura:CreateSlider({
        Name = 'Max targets',
        Min = 1,
        Max = 5,
        Default = 5
    })
    Sort = BetterKillaura:CreateDropdown({
        Name = 'Target Mode',
        List = methods
    })
    Mouse = BetterKillaura:CreateToggle({
        Name = 'Require mouse down',
        Function = function(callback)
            if callback and LegitAura and LegitAura.Enabled then
                Mouse:Toggle(false)
                LegitAura:Toggle(false)
                notif("BetterKillaura", "yo u cant have require mouse down AND swing only on at da same time turned both off 4 u ", 5)
            end
        end
    })
    Swing = BetterKillaura:CreateToggle({Name = 'No Swing'})
    GUI = BetterKillaura:CreateToggle({Name = 'GUI check'})
    SwingTime = BetterKillaura:CreateToggle({
        Name = 'Custom Swing Time',
        Function = function(callback)
            SwingTimeSlider.Object.Visible = callback
        end
    })
    SwingTimeSlider = BetterKillaura:CreateSlider({
        Name = 'Swing Time',
        Min = 0,
        Max = 1,
        Default = 0.42,
        Decimal = 100,
        Visible = false
    })
    ContinueSwinging = BetterKillaura:CreateToggle({
        Name = 'Continue Swinging',
        Tooltip = 'Swing X times after losing target (based on swing speed)',
        Function = function(callback)
            if ContinueSwingTime then
                ContinueSwingTime.Object.Visible = callback
            end
        end
    })
    ContinueSwingTime = BetterKillaura:CreateSlider({
        Name = 'Swing Duration',
        Min = 0,  
        Max = 5,  
        Default = 1,
        Decimal = 10,
        Suffix = 's',
        Visible = false
    })
    CustomHitReg = BetterKillaura:CreateToggle({
        Name = 'Custom Hit Reg',
        Tooltip = 'Limit how many hits per second',
        Function = function(callback)
            if CustomHitRegSlider then
                CustomHitRegSlider.Object.Visible = callback
            end
            if callback then
                lastCustomHitTime = 0
            end
        end
    })
    
    CustomHitRegSlider = BetterKillaura:CreateSlider({
        Name = 'Hits Per Second',
        Min = 1,
        Max = 36,
        Default = 30,
        Tooltip = 'Maximum hits per second',
        Visible = false
    })
    SyncHits = BetterKillaura:CreateToggle({
        Name = 'Sync Hits',
        Tooltip = 'Waits for sword animation before attacking'
    })
    BetterKillaura:CreateToggle({
        Name = 'Show target',
        Function = function(callback)
            BoxSwingColor.Object.Visible = callback
            BoxAttackColor.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local box = Instance.new('BoxHandleAdornment')
                    box.Adornee = nil
                    box.AlwaysOnTop = true
                    box.Size = Vector3.new(3, 5, 3)
                    box.CFrame = CFrame.new(0, -0.5, 0)
                    box.ZIndex = 0
                    box.Parent = vape.gui
                    Boxes[i] = box
                end
            else
                for _, v in Boxes do
                    v:Destroy()
                end
                table.clear(Boxes)
            end
        end
    })
    BoxSwingColor = BetterKillaura:CreateColorSlider({
        Name = 'Target Color',
        Darker = true,
        DefaultHue = 0.6,
        DefaultOpacity = 0.5,
        Visible = false,
        Function = function(hue, sat, val)
            if BetterKillaura.Enabled and RangeCirclePart ~= nil then
                RangeCirclePart.Color = Color3.fromHSV(hue, sat, val)
            end
        end
    })
    BoxAttackColor = BetterKillaura:CreateColorSlider({
        Name = 'Attack Color',
        Darker = true,
        DefaultOpacity = 0.5,
        Visible = false
    })
    BetterKillaura:CreateToggle({
        Name = 'Target particles',
        Function = function(callback)
            ParticleTexture.Object.Visible = callback
            ParticleColor1.Object.Visible = callback
            ParticleColor2.Object.Visible = callback
            ParticleSize.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local part = Instance.new('Part')
                    part.Size = Vector3.new(2, 4, 2)
                    part.Anchored = true
                    part.CanCollide = false
                    part.Transparency = 1
                    part.CanQuery = false
                    part.Parent = BetterKillaura.Enabled and gameCamera or nil
                    local particles = Instance.new('ParticleEmitter')
                    particles.Brightness = 1.5
                    particles.Size = NumberSequence.new(ParticleSize.Value)
                    particles.Shape = Enum.ParticleEmitterShape.Sphere
                    particles.Texture = ParticleTexture.Value
                    particles.Transparency = NumberSequence.new(0)
                    particles.Lifetime = NumberRange.new(0.4)
                    particles.Speed = NumberRange.new(16)
                    particles.Rate = 128
                    particles.Drag = 16
                    particles.ShapePartial = 1
                    particles.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
                    })
                    particles.Parent = part
                    Particles[i] = part
                end
            else
                for _, v in Particles do
                    v:Destroy()
                end
                table.clear(Particles)
            end
        end
    })
    ParticleTexture = BetterKillaura:CreateTextBox({
        Name = 'Texture',
        Default = 'rbxassetid://14736249347',
        Function = function()
            for _, v in Particles do
                v.ParticleEmitter.Texture = ParticleTexture.Value
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleColor1 = BetterKillaura:CreateColorSlider({
        Name = 'Color Begin',
        Function = function(hue, sat, val)
            for _, v in Particles do
                v.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
                })
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleColor2 = BetterKillaura:CreateColorSlider({
        Name = 'Color End',
        Function = function(hue, sat, val)
            for _, v in Particles do
                v.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
                })
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleSize = BetterKillaura:CreateSlider({
        Name = 'Size',
        Min = 0,
        Max = 1,
        Default = 0.2,
        Decimal = 100,
        Function = function(val)
            for _, v in Particles do
                v.ParticleEmitter.Size = NumberSequence.new(val)
            end
        end,
        Darker = true,
        Visible = false
    })
    Face = BetterKillaura:CreateToggle({
        Name = 'Face target',
        Function = function(callback)
            if FaceSpeed then FaceSpeed.Object.Visible = callback end
        end
    })

    FaceSpeed = BetterKillaura:CreateSlider({
        Name = 'Face Speed',
        Min = 1,
        Max = 100,
        Default = 15,
        Decimal = 10,
        Darker = true,
        Visible = false,
        Tooltip = 'How fast to snap towards target (lower = slower/smoother)'
    })
    Animation = BetterKillaura:CreateToggle({
        Name = 'Custom Animation',
        Function = function(callback)
            AnimationMode.Object.Visible = callback
            AnimationTween.Object.Visible = callback
            AnimationSpeed.Object.Visible = callback
            if BetterKillaura.Enabled then
                BetterKillaura:Toggle()
                BetterKillaura:Toggle()
            end
        end
    })
    local animnames = {}
    for i in anims do
        table.insert(animnames, i)
    end
    AnimationMode = BetterKillaura:CreateDropdown({
        Name = 'Animation Mode',
        List = animnames,
        Darker = true,
        Visible = false
    })
    AnimationSpeed = BetterKillaura:CreateSlider({
        Name = 'Animation Speed',
        Min = 0,
        Max = 2,
        Default = 1,
        Decimal = 10,
        Darker = true,
        Visible = false
    })
    AnimationTween = BetterKillaura:CreateToggle({
        Name = 'No Tween',
        Darker = true,
        Visible = false
    })
    Limit = BetterKillaura:CreateToggle({
        Name = 'Limit to items',
        Function = function(callback)
            if inputService.TouchEnabled and BetterKillaura.Enabled then
                pcall(function()
                    lplr.PlayerGui.MobileUI['2'].Visible = callback
                end)
            end
        end,
        Tooltip = 'Only attacks when the sword is held'
    })
    LegitAura = BetterKillaura:CreateToggle({
        Name = 'Swing only',
        Tooltip = 'Only attacks while swinging manually',
        Function = function(callback)
            if callback and Mouse and Mouse.Enabled then
                LegitAura:Toggle(false)
                Mouse:Toggle(false)
                notif("BetterKillaura", "yo u cant have swing only AND require mouse down on at da same time lol turned both off 4 u ", 5)
            end
        end
    })
    AirHit = BetterKillaura:CreateToggle({
        Name = 'Air Hits',
        Default = true,
        Tooltip = 'Control hit chance when target is airborne',
        Function = function(callback)
            if AirHitsChance then
                AirHitsChance.Object.Visible = callback
            end
            if BetterKillaura.Enabled and callback and AirHitsChance and AirHitsChance.Object then
                AirHitsChance.Object.Visible = true
            end
        end
    })
    AirHitsChance = BetterKillaura:CreateSlider({
        Name = 'Air Hits Chance',
        Min = 0,
        Max = 100,
        Default = 100,
        Suffix = '%',
        Decimal = 5,
        Darker = true,
        Visible = false
    })
	task.spawn(function()
		local wasAvailable = true
		while true do
			task.wait(0.05)
			if bedwars.AbilityController then
				local canUse = pcall(function()
					return bedwars.AbilityController:canUseAbility('rebellion_shield')
				end)
				local nowAvailable = bedwars.AbilityController:canUseAbility('rebellion_shield')
				if wasAvailable and not nowAvailable then
					store.silasAbilityTime = tick()
				end
				wasAvailable = nowAvailable
			end
		end
	end)
	task.spawn(function()
		local wasStompAvailable = true
		local wasKickAvailable = true
		while true do
			task.wait(0.05)
			if bedwars.AbilityController then
				local nowStomp = pcall(function() return bedwars.AbilityController:canUseAbility('BLOCK_STOMP') end) and bedwars.AbilityController:canUseAbility('BLOCK_STOMP')
				local nowKick = pcall(function() return bedwars.AbilityController:canUseAbility('BLOCK_KICK') end) and bedwars.AbilityController:canUseAbility('BLOCK_KICK')
				if wasStompAvailable and not nowStomp then
					store.terraStompTime = tick()
				end
				if wasKickAvailable and not nowKick then
					store.terraKickTime = tick()
				end
				wasStompAvailable = nowStomp
				wasKickAvailable = nowKick
			end
		end
	end)

	local kitChecks = {
        ['Sophia'] = function() return isFrozen(nil, FROZEN_THRESHOLD) end,
        ['Sigrid'] = function() return entitylib.isAlive and lplr.Character and lplr.Character:FindFirstChild('elk') ~= nil end,
    }
    AttackCheck = BetterKillaura:CreateToggle({
        Name = 'Attack Check',
        Tooltip = 'Stops BetterKillaura when a kit ability is detected (Sophia, etc) or when asleep',
        Function = function(callback)
        end,
        Default = false
    })

	FastHits = BetterKillaura:CreateToggle({
        Name = 'Fast Hits',
        Tooltip = 'Deals more damage quicker using projectiles',
        Default = false,
        Function = function(call)
            FastHitsMode.Object.Visible = call
            FireRate.Object.Visible = call and FastHitsMode.Value == 'NEWFastHits'
            if AutoFireball then AutoFireball.Object.Visible = call end
            if LegitSwitch then LegitSwitch.Object.Visible = call and FastHitsMode.Value == 'NEWFastHits' end
            if OldShootInterval then OldShootInterval.Object.Visible = call and FastHitsMode.Value == 'OLDFastHits' end
            if OldSwitchDelay then OldSwitchDelay.Object.Visible = call and FastHitsMode.Value == 'OLDFastHits' end
            if OldWaitDelay then OldWaitDelay.Object.Visible = call and FastHitsMode.Value == 'OLDFastHits' end
            if OldFirstPersonCheck then OldFirstPersonCheck.Object.Visible = call and FastHitsMode.Value == 'OLDFastHits' end
        end
    })
    FastHitsMode = BetterKillaura:CreateDropdown({
        Name = 'Fast Hits Mode',
        List = {'NEWFastHits', 'OLDFastHits'},
        Default = 'NEWFastHits',
        Darker = true,
        Visible = false,
        Function = function(val)
            FireRate.Object.Visible = val == 'NEWFastHits'
            LegitSwitch.Object.Visible = val == 'NEWFastHits'
            OldShootInterval.Object.Visible = val == 'OLDFastHits'
            OldSwitchDelay.Object.Visible = val == 'OLDFastHits'
            OldWaitDelay.Object.Visible = val == 'OLDFastHits'
            OldFirstPersonCheck.Object.Visible = val == 'OLDFastHits'
        end
    })
    LegitSwitch = BetterKillaura:CreateToggle({
        Name = 'Legit Switch',
        Default = false,
        Darker = true,
        Visible = false,
        Tooltip = 'Uses hotbarSwitch to switch to crossbow before shooting instead of silent switch'
    })
    OldShootInterval = BetterKillaura:CreateSlider({
        Name = 'Shoot Interval',
        Min = 0.1,
        Max = 3,
        Default = 0.5,
        Decimal = 10,
        Suffix = 's',
        Darker = true,
        Visible = false,
        Tooltip = 'How often to shoot bows'
    })
    OldSwitchDelay = BetterKillaura:CreateSlider({
        Name = 'Switch Delay',
        Min = 0,
        Max = 0.2,
        Default = 0.05,
        Decimal = 100,
        Suffix = 's',
        Darker = true,
        Visible = false,
        Tooltip = 'Delay between switching and shooting'
    })
    OldWaitDelay = BetterKillaura:CreateSlider({
        Name = 'Wait Delay',
        Min = 0,
        Max = 1,
        Default = 0,
        Decimal = 100,
        Suffix = 's',
        Darker = true,
        Visible = false,
        Tooltip = 'Delay before shooting'
    })
    OldFirstPersonCheck = BetterKillaura:CreateToggle({
        Name = 'First Person Only',
        Default = false,
        Darker = true,
        Visible = false,
        Tooltip = 'Only works in first person mode'
    })

	AutoFireball = BetterKillaura:CreateToggle({
        Name = 'Auto Fireball',
        Default = false,
        Visible = false,
        Tooltip = 'Shoots crossbow then fireball at target. Falls back to whichever you have.',
        Function = function(enabled)
            if enabled then
                startAutoFireballLoop()
            else
                stopAutoFireballLoop()
            end
        end
    })

    FireRate = BetterKillaura:CreateSlider({
        Name = 'Fire rate',
        Suffix = 's',
        Min = 0,
        Max = 2,
        Decimal = 100,
        Darker = true,
        Visible = false,
        Default = 0
    })

    task.defer(function()
        if AirHit and AirHit.Enabled and AirHitsChance and AirHitsChance.Object then
            AirHitsChance.Object.Visible = true
        end
    end)
end)

run(function()
    local BetterFastBreak
    local Time
    local BedCheck
    local Blacklist
    local blocks
    local string_lower = string.lower
    local string_find = string.find
    local task_wait = task.wait
    local currentBlock = nil
    local oldHitBlock = nil
    local bedCache = {}
    local blacklistCache = {}
    local lastCacheClean = 0
    local cacheCleanInterval = 5 
    
    local function isBed(block)
        if not block then return false end
        local cached = bedCache[block]
        if cached ~= nil then return cached end
        
        local result = false
        pcall(function()
            if collectionService:HasTag(block, 'bed') or (block.Parent and collectionService:HasTag(block.Parent, 'bed')) then
                result = true
            elseif string_find(string_lower(block.Name), 'bed', 1, true) then
                result = true
            end
        end)
        
        bedCache[block] = result
        return result
    end
    
    local cachedBlacklistLower = {}
    local function updateBlacklistCache()
        if not blocks or not blocks.ListEnabled then return end
        
        cachedBlacklistLower = {}
        for _, v in pairs(blocks.ListEnabled) do
            table.insert(cachedBlacklistLower, string_lower(v))
        end
    end
    
    local function isBlacklisted(block)
        if not block or #cachedBlacklistLower == 0 then return false end
        local cached = blacklistCache[block]
        if cached ~= nil then return cached end
        
        local name = string_lower(block.Name)
        local result = false
        for i = 1, #cachedBlacklistLower do
            if string_find(name, cachedBlacklistLower[i], 1, true) then
                result = true
                break
            end
        end
        
        blacklistCache[block] = result
        return result
    end
    
    local function shouldSkip(block)
        if not block then return false end
        if BedCheck and BedCheck.Enabled and isBed(block) then return true end
        if Blacklist and Blacklist.Enabled and isBlacklisted(block) then return true end
        return false
    end
    
    local lastBreakUpdate = 0
    local breakUpdateCooldown = 0.05
    local pendingUpdate = false
    
    local function updateBreakSpeed()
        if not BetterFastBreak or not BetterFastBreak.Enabled then return end
        local now = tick()
        if now - lastBreakUpdate < breakUpdateCooldown then
            pendingUpdate = true
            return
        end
        lastBreakUpdate = now
        pendingUpdate = false
        
        pcall(function()
            local cooldown = (shouldSkip(currentBlock)) and 0.3 or Time.Value
            bedwars.BlockBreakController.blockBreaker:setCooldown(cooldown)
        end)
    end
    
    BetterFastBreak = vape.Categories.Blatant:CreateModule({
        Name = 'BetterFastBreak',
        Function = function(callback)
            if callback then
                oldHitBlock = bedwars.BlockBreaker.hitBlock
				local lastHotbarSlot = nil

				bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
					local block = nil
					pcall(function()
						local blockInfo = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
						if blockInfo and blockInfo.target and blockInfo.target.blockInstance then
							block = blockInfo.target.blockInstance
						end
					end)
					
					local currentSlot = store.inventory and store.inventory.hotbarSlot
					local slotChanged = currentSlot ~= lastHotbarSlot
					if slotChanged then
						lastHotbarSlot = currentSlot
					end

					if block ~= currentBlock or slotChanged then
						currentBlock = block
						updateBreakSpeed()
					end
					return oldHitBlock and oldHitBlock(self, maid, raycastparams, ...)
				end
                
                updateBlacklistCache()
                
                task.spawn(function()
                    while BetterFastBreak.Enabled do
                        if tick() - lastCacheClean > cacheCleanInterval then
                            lastCacheClean = tick()
                            bedCache = {}
                            blacklistCache = {}
                        end
                        if pendingUpdate then updateBreakSpeed() end
                        task_wait(0.5) 
                    end
                end)
			else
				pcall(function() bedwars.BlockBreakController.blockBreaker:setCooldown(0.3) end)
				if oldHitBlock then
					bedwars.BlockBreaker.hitBlock = oldHitBlock
					oldHitBlock = nil
				end
				currentBlock = nil
				lastHotbarSlot = nil
				bedCache, blacklistCache, cachedBlacklistLower = {}, {}, {}
			end
        end,
        Tooltip = 'Decreases block hit cooldown'
    })
    
    Time = BetterFastBreak:CreateSlider({
        Name = 'Break speed',
        Min = 0, Max = 0.3, Default = 0.25, Decimal = 100, Suffix = 'seconds',
        Function = function() updateBreakSpeed() end
    })
    
    BedCheck = BetterFastBreak:CreateToggle({
        Name = 'Bed Check',
        Default = false,
        Tooltip = 'Use normal break speed when breaking beds',
        Function = function() bedCache = {}; updateBreakSpeed() end
    })
    
    Blacklist = BetterFastBreak:CreateToggle({
        Name = 'Blacklist Blocks',
        Default = false,
        Tooltip = 'Use normal break speed on blacklisted blocks',
        Function = function(v)
            if blocks then blocks.Object.Visible = v end
            blacklistCache = {}
            if v then updateBlacklistCache() end
            updateBreakSpeed()
        end
    })
    
    blocks = BetterFastBreak:CreateTextList({
        Name = 'Blacklisted Blocks',
        Placeholder = 'bed',
        Visible = false,
        Function = function()
            updateBlacklistCache()
            blacklistCache = {}
            updateBreakSpeed()
        end
    })
end)																									
