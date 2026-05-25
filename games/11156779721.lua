local run = function(func) 
	func() 
end
local cloneref = cloneref or function(obj) 
	return obj 
end

local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local tweenService = cloneref(game:GetService('TweenService'))

local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer

local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local prediction = vape.Libraries.prediction
local color = vape.Libraries.color
local uipallet = vape.Libraries.uipallet
local getcustomasset = vape.Libraries.getcustomasset

local clientData = require(replicatedStorage.modules.player.ClientData)
local aiController = require(lplr.PlayerScripts.AIController)
local projectiles = require(replicatedStorage.modules.game.Projectiles).Projectile
local itemData = {}
for _, v in debug.getupvalue(require(replicatedStorage.game.Items).getItemData, 1) do 
	itemData[v.id] = v 
end
local Crypt = require(replicatedStorage.Crypt)

local top = replicatedStorage:WaitForChild('Water'):WaitForChild('top')
local topY = top.Position.Y + top.Size.Y / 2
--local anticheatloop = getconnections(main.Marco.OnClientEvent)[1].Function

local function getSpeed()
	local factor = 3.25
	local realSpeed = math.max(clientData.getSpeedFactor(), 0.8)
	if entitylib.isAlive and entitylib.character.RootPart.Position.Y < (topY - 1) and realSpeed >= 1 then 
		factor += 1
	end
	return 16 * (realSpeed * factor)
end	

local function getTool(breakType)
	local bestTool, bestToolData, bestToolDamage = nil, nil, 0
	for slot, item in clientData.getHotbar() do
		if item == -1 then continue end
		local toolMeta = itemData[item]
		if toolMeta.itemStats then
			local toolDamage = toolMeta.itemStats[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolData, bestToolDamage = slot, toolMeta, toolDamage
			end
		end
	end
	return bestTool, bestToolData
end

run(function()
	local function waitForChildOfType(obj, name, timeout, prop)
		local checktick = tick() + timeout
		local returned
		repeat
			returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
			if returned or checktick < tick() then break end
			task.wait()
		until false
		return returned
	end

	local oldstart = entitylib.start
	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in workspace.AI_Client:GetChildren() do 
				task.spawn(entitylib.addEntity, ent) 
			end
			table.insert(entitylib.Connections, workspace.AI_Client.ChildAdded:Connect(function(v) 
				entitylib.addEntity(v) 
			end))
			table.insert(entitylib.Connections, workspace.AI_Client.ChildRemoved:Connect(function(v) 
				entitylib.removeEntity(v) 
			end))
		end
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum = plr and waitForChildOfType(char, 'Humanoid', 10) or {
				RootPart = char.PrimaryPart,
				HipHeight = char:GetAttribute('HipHeight') or 2,
				Health = 100,
				MaxHealth = 100,
				GetPropertyChangedSignal = function() end
			}
			local humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
			local head = char:WaitForChild('Head', 10) or humrootpart and {Name = 'Head', Size = Vector3.one, Parent = char}

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = hum.Health,
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					MaxHealth = hum.MaxHealth,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
				else
					entity.Targetable = entitylib.targetCheck(entity)

					for i, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = hum.Health
							entity.MaxHealth = hum.MaxHealth
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end
			end
			entitylib.EntityThreads[char] = nil
		end)
	end
end)
entitylib.start()

run(function()
	local InfiniteStamina
	
	InfiniteStamina = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteStamina',
		Function = function(callback)
			if callback then 
				repeat
					lplr:SetAttribute('stamina', 1)
					task.wait(0.1)
				until not InfiniteStamina.Enabled
			end
		end,
		Tooltip = 'Tiredless simulator'
	})
end)
	
local Attacking
run(function()
	local Killaura
	local Targets
	local Range
	local AngleSlider
	local Max
	local Mouse
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local KillauraFunctions = {}
	local Particles, Boxes = {}, {}
	local AIHit = replicatedStorage.remoteInterface.interactions.meleeAI
	local meleePlayer = replicatedStorage.remoteInterface.interactions.meleePlayer
	local autoBlock = replicatedStorage.remoteInterface.character.setShield
	local blocking

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		local tool = getTool('meleeDamage')
		return tool
	end

	local function block(state)
		if blocking == state then return end
		blocking = state
		--autoBlock:FireServer(state)
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				repeat
					local tool = getAttackData()
					local attacked = {}
					Attacking = false
					if tool then
						local plrs = entitylib.AllPosition({
							Range = Range.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = Max.Value
						})

						if #plrs > 0 then
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							block(false)
							for i, v in plrs do
								local delta = (v.RootPart.Position - entitylib.character.RootPart.Position)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end
								table.insert(attacked, v)
								targetinfo.Targets[v] = tick() + 1
								Attacking = true

								if v.NPC then
									AIHit:FireServer(tool, aiController:GetServerModelFromClientModel(v.Character))
								else
									local key1, key2, key3 = Crypt.checkpublickeys()
									if key1 and key2 and key3 then
										meleePlayer:FireServer(tool, Crypt.crypt(key1, math.abs(v.Player.UserId) + key3, key2))
									end
								end
								break
							end
							block(true)
						else
							block(false)
						end
					end

					for i, v in KillauraFunctions do
						v(attacked)
					end

					task.wait(Attacking and 0.25 or 0.03)
				until not Killaura.Enabled
			else
				for i, v in KillauraFunctions do
					v({})
				end
				Attacking = false
				block(false)
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	Range = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 15,
		Default = 15,
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
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				KillauraFunctions.Box = function(attacked)
					if vape.ThreadFix then
						setthreadidentity(8)
					end

					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(BoxAttackColor.Hue, BoxAttackColor.Sat, BoxAttackColor.Value)
							v.Transparency = 1 - BoxAttackColor.Opacity
						end
					end
				end
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
				KillauraFunctions.Box = nil
				for i, v in Boxes do
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
				KillauraFunctions.Particles = function(attacked)
					if vape.ThreadFix then
						setthreadidentity(8)
					end

					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end
				end
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.one
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0, 1)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Rate = 1000
					particles.Speed = NumberRange.new(12)
					particles.Drag = 6
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for i, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function(val)
			for i, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for i, v in Particles do
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
			for i, v in Particles do
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
		Default = 0.25,
		Decimal = 100,
		Function = function(val)
			for i, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
end)
	
run(function()
	local NoFall
	local connections = {}
	
	NoFall = vape.Categories.Blatant:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			if callback then
				NoFall:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					task.delay(1, function()
						for _, v in getconnections(ent.Humanoid.StateChanged) do
							table.insert(connections, v)
							v:Disable()
						end
					end)
				end))
	
				if entitylib.isAlive then
					for _, v in getconnections(entitylib.character.Humanoid.StateChanged) do
						table.insert(connections, v)
						v:Disable()
					end
				end
			else
				for _, v in connections do 
					v:Enable() 
				end
				table.clear(connections)
			end
		end,
		Tooltip = 'Prevents you from taking fall damage.'
	})
end)
	
run(function()
	local Speed
	local Value
	local WallCheck
	local AutoJump
	local AlwaysJump
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	
	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local state = entitylib.character.Humanoid:GetState()
						if state == Enum.HumanoidStateType.Climbing then return end
	
						local root, velo = entitylib.character.RootPart, getSpeed()
						local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
						local destination = (moveDirection * math.max(velo - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
	
						if WallCheck.Enabled then
							rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
							rayCheck.CollisionGroup = root.CollisionGroup
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then 
								destination = ((ray.Position + ray.Normal) - root.Position) 
							end
						end
	
						root.CFrame += destination
					end
				end))
			end
		end,
		ExtraText = function() 
			return 'TSG' 
		end,
		Tooltip = 'Increases your movement with various methods.'
	})
	WallCheck = Speed:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
end)
	
run(function()
	local AutoEat
	local Health
	local eatRemote = replicatedStorage.remoteInterface.interactions.eat
	local maxHunger = replicatedStorage.game.maxHunger.Value
	local regenTick = tick()
	
	local function getEatenItem()
		local inv, hunger = clientData.getInventory(lplr), clientData.getHunger()
		if inv and entitylib.isAlive then
			local chosen, lowest = nil, math.huge
	
			for i, v in inv do
				v = itemData[i]
				local food = v and v.itemStats and v.itemStats.food
				if food and (v.instantHealth or 1) > 0 then
					local healthCheck = entitylib.character.Humanoid.Health < entitylib.character.Humanoid.MaxHealth and Health.Enabled
					if ((hunger + food) < maxHunger or healthCheck) and food < lowest and not table.find(v.effectsOnEat or {}, "Food_Poisoning") then
						chosen, lowest = i, food
					end
	
					if entitylib.character.Humanoid.Health < entitylib.character.Humanoid.MaxHealth and Health.Enabled then
						if (v.instantHealth or v.durationHealth) and regenTick < tick() then
							if v.durationHealth then 
								regenTick = tick() + (v.durationHealth / v.durationHealthRate) 
							end
							chosen = i
							break
						end
					end
				end
			end
	
			return chosen
		end
	end
	
	AutoEat = vape.Categories.Utility:CreateModule({
		Name = 'AutoEat',
		Function = function(callback)
			if callback then
				repeat
					local item = getEatenItem()
					if item then 
						eatRemote:FireServer(item) 
					end
					task.wait(0.1)
				until not AutoEat.Enabled
			end
		end,
		Tooltip = 'Automatically eats healing items'
	})
	Health = AutoEat:CreateToggle({
		Name = 'Eat Healing Items',
		Default = true
	})
end)
	
run(function()
	local AutoPickup
	local dropped = workspace.droppedItems
	local pickupRemote =  replicatedStorage.remoteInterface.inventory.pickupItem
	local pickuptable = {}
	local pickupdelay = {}
	
	AutoPickup = vape.Categories.Utility:CreateModule({
		Name = 'AutoPickup',
		Function = function(callback)
			if callback then 
				AutoPickup:Clean(dropped.ChildAdded:Connect(function(v) 
					table.insert(pickuptable, v) 
				end))
				AutoPickup:Clean(dropped.ChildRemoved:Connect(function(v)
					local ind = table.find(pickuptable, v)
					if ind then 
						table.remove(pickuptable, ind) 
					end
				end))
				pickuptable = dropped:GetChildren()
				
				repeat
					if entitylib.isAlive then 
						for i, v in pickuptable do 
							if (v.Position - entitylib.character.RootPart.Position).Magnitude < 10 then 
								firetouchinterest(v, entitylib.character.RootPart, 1)
								firetouchinterest(v, entitylib.character.RootPart, 0)
							end
						end
					end
					task.wait(0.03)
				until not AutoPickup.Enabled
			else
				table.clear(pickuptable)
			end
		end,
		Tooltip = 'Picks up items within close range'
	})
end)
	
run(function()
	local Breaker
	local BreakerDisable
	local BreakerPart
	local BreakerUI
	local BreakerRef
	local BreakerObjects = {}
	local mine = replicatedStorage.remoteInterface.interactions.mine
	local chop = replicatedStorage.remoteInterface.interactions.chop
	local old
	
	local function clean()
		if not BreakerUI then return end
		if BreakerPart then 
			BreakerPart:Destroy() 
		end
		BreakerUI = nil
		BreakerPart = nil
		BreakerRef = nil
	end
	
	local function customHealthbar(block, health, maxHealth, changeHealth)
		if not BreakerPart then
			local percent = math.clamp(health / maxHealth, 0, 1)
			local part = Instance.new('Part')
			part.Size = Vector3.one
			part.CFrame = block.PrimaryPart.CFrame
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.Parent = workspace
			BreakerPart = part
			local billboard = Instance.new('BillboardGui')
			billboard.Size = UDim2.fromOffset(249, 102)
			billboard.StudsOffset = Vector3.new(0, 2.5, 0)
			billboard.Adornee = part
			billboard.MaxDistance = 100
			billboard.AlwaysOnTop = true
			billboard.Parent = part
			BreakerUI = billboard
			local holder = Instance.new('Frame')
			holder.Size = UDim2.fromOffset(160, 50)
			holder.Position = UDim2.fromOffset(44, 32)
			holder.BackgroundColor3 = Color3.new()
			holder.BackgroundTransparency = 0.5
			holder.Parent = billboard
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(0, 5)
			corner.Parent = holder
			local blur = Instance.new('ImageLabel')
			blur.Size = UDim2.new(1, 89, 1, 52)
			blur.Position = UDim2.fromOffset(-48, -31)
			blur.BackgroundTransparency = 1
			blur.Image = getcustomasset('newvape/assets/new/blur.png')
			blur.ScaleType = Enum.ScaleType.Slice
			blur.SliceCenter = Rect.new(52, 31, 261, 502)
			blur.Parent = holder
			local shadow = Instance.new('TextLabel')
			shadow.Size = UDim2.fromOffset(145, 14)
			shadow.Position = UDim2.fromOffset(13, 12)
			shadow.BackgroundTransparency = 1
			shadow.Text = block.Name
			shadow.TextXAlignment = Enum.TextXAlignment.Left
			shadow.TextYAlignment = Enum.TextYAlignment.Top
			shadow.TextColor3 = Color3.new()
			shadow.TextScaled = true
			shadow.Font = Enum.Font.Arial
			shadow.Parent = holder
			local shadow = Instance.new('TextLabel')
			shadow.Size = UDim2.fromOffset(145, 14)
			shadow.Position = UDim2.fromOffset(12, 11)
			shadow.BackgroundTransparency = 1
			shadow.Text = block.Name
			shadow.TextXAlignment = Enum.TextXAlignment.Left
			shadow.TextYAlignment = Enum.TextYAlignment.Top
			shadow.TextColor3 = color.Dark(uipallet.Text, 0.16)
			shadow.TextScaled = true
			shadow.Font = Enum.Font.Arial
			shadow.Parent = holder
			local barholder = Instance.new('Frame')
			barholder.Size = UDim2.fromOffset(138, 4)
			barholder.Position = UDim2.fromOffset(12, 32)
			barholder.BackgroundColor3 = uipallet.Main
			barholder.Parent = holder
			local barcorner = Instance.new('UICorner')
			barcorner.CornerRadius = UDim.new(1, 0)
			barcorner.Parent = barholder
			local healthbar = Instance.new('Frame')
			healthbar.Size = UDim2.fromScale(percent, 1)
			healthbar.BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
			healthbar.Parent = barholder
			BreakerRef = healthbar
			local healthcorner = Instance.new('UICorner')
			healthcorner.CornerRadius = UDim.new(1, 0)
			healthcorner.Parent = healthbar
		end
	
		local newpercent = math.clamp((health - changeHealth) / maxHealth, 0, 1)
		if newpercent == 0 then 
			clean() 
			return 
		end
		
		tweenService:Create(BreakerRef, TweenInfo.new(0.3), {
			Size = UDim2.fromScale(newpercent, 1),
			BackgroundColor3 = Color3.fromHSV(math.clamp(newpercent / 2.5, 0, 1), 0.89, 0.75)
		}):Play()
	end
	
	local function getBreakable()
		if entitylib.isAlive and (BreakerDisable.Enabled or not Attacking) then
			local closest, hp = nil, math.huge
			local localPosition = entitylib.character.RootPart.Position
	
			for _, v in BreakerObjects do
				if v:GetAttribute('health') > 0 and v.PrimaryPart and (localPosition - v.PrimaryPart.Position).Magnitude < 30 then
					local newhp = v:GetAttribute('health')
					if newhp <= hp then closest, hp = v, newhp end
				elseif v == old then
					clean()
				end
			end
	
			return closest
		end
	end
	
	Breaker = vape.Categories.Minigames:CreateModule({
		Name = 'Breaker',
		Function = function(callback)
			if callback then
				local oldhp = -1
	
				for _, obj in workspace.worldResources:GetDescendants() do
					if obj:GetAttribute('health') then 
						table.insert(BreakerObjects, obj) 
					end
				end
				Breaker:Clean(workspace.worldResources.DescendantAdded:Connect(function(obj)
					if obj:GetAttribute('health') then 
						table.insert(BreakerObjects, obj) 
					end
				end))
				Breaker:Clean(workspace.worldResources.DescendantRemoving:Connect(function(obj)
					local ind = table.find(BreakerObjects, obj)
					if ind then 
						table.remove(BreakerObjects, ind) 
					end
				end))
	
				repeat
					local obj = getBreakable()
					if obj then
						local axe, pickaxe = getTool('axeStrength'), getTool('pickaxeStrength')
						local done
						if obj:IsDescendantOf(workspace.worldResources.mineable) then 
							if pickaxe then
								done = true
								mine:FireServer(pickaxe, obj, obj.PrimaryPart.CFrame)
							end
						else
							if axe then
								done = true
								chop:FireServer(axe, obj, obj.PrimaryPart.CFrame)
							end
						end
	
						if done and (obj:GetAttribute('health') ~= oldhealth or obj ~= old) then
							if obj ~= old then
								oldhealth = obj:GetAttribute('health')
								clean()
							end
							customHealthbar(obj, oldhealth, obj:GetAttribute('maxHealth'), oldhealth - obj:GetAttribute('health'))
							oldhealth = obj:GetAttribute('health')
							old = obj
						end
					end
	
					task.wait(0.1)
				until not Breaker.Enabled
			else
				table.clear(BreakerObjects)
				clean()
			end
		end,
		Tooltip = 'Break resources around you automatically'
	})
	BreakerDisable = Breaker:CreateToggle({
		Name = 'Break while attacking',
		Default = true
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
