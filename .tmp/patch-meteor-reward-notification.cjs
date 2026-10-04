const fs = require('node:fs');
const file='src/client/Controllers/HUDController.luau';
let source=fs.readFileSync(file,'utf8');
fs.writeFileSync('.tmp/meteor-reward-HUDController-before.luau',source);
function replace(oldText,newText){if(!source.includes(oldText))throw new Error('Missing patch target '+oldText.slice(0,70));source=source.replace(oldText,newText);}
replace('--   * announcement banner, results panel, small toasts','--   * announcement banner, personal meteor reward line, small toasts');
replace('local results = scope:Value(nil :: any)','local meteorReward = scope:Value(nil :: any)');
replace('return use(toast) ~= nil or use(announcement) ~= nil end)','return use(toast) ~= nil or use(announcement) ~= nil or use(meteorReward) ~= nil end)');
replace('player:SetAttribute("HudNotificationActive", false)',`player:SetAttribute("HudNotificationActive", false)
	local rewardActive = scope:Computed(function(use) return use(meteorReward) ~= nil end)
	scope:Observer(rewardActive):onChange(function() player:SetAttribute("HudRewardNotificationActive", Fusion.peek(rewardActive)) end)
	player:SetAttribute("HudRewardNotificationActive", false)`);
replace('local resultsToken = 0','local rewardToken = 0');
replace('resultsToken += 1','rewardToken += 1');
replace('local token = resultsToken','local token = rewardToken');
replace('results:set(message)','meteorReward:set(message)');
replace('task.delay(9, function()','task.delay(6, function()');
replace('if resultsToken == token then','if rewardToken == token then');
replace('results:set(nil)','meteorReward:set(nil)');
const start=source.indexOf('\t\t\t-- Results panel');
const end=source.indexOf('\t\t\t-- One reserved notification area:',start);
if(start<0||end<start)throw new Error('Results modal boundaries missing');
source=source.slice(0,start)+source.slice(end);
replace('-- One reserved notification area: a toast temporarily takes priority\r\n\t\t\t-- over meteor announcements, so text never stacks over HUD controls.', '-- One reserved notification area: keep the personal reward directly below\n\t\t\t-- the announcement, with toasts retaining priority in the first row.');
replace('Size = scope:Computed(function(use) local r = use(hud).notification; return UDim2.fromOffset(r.w, r.h) end),', 'Size = scope:Computed(function(use) local r = use(hud).notification; return UDim2.fromOffset(r.w, if use(rewardActive) then math.floor((r.h - 4) * 0.55) else r.h) end),');
replace('Visible = notificationActive,','Visible = scope:Computed(function(use) return use(toast) ~= nil or use(announcement) ~= nil end),');
const marker='\t\t\t-- Studio-only playtest helpers';
const rewardView=`			UI.label(scope, {
				Name = "MeteorReward",
				Position = scope:Computed(function(use)
					local r = use(hud).notification
					return UDim2.fromOffset(r.x, r.y + math.floor((r.h - 4) * 0.55) + 4)
				end),
				Size = scope:Computed(function(use)
					local r = use(hud).notification
					return UDim2.fromOffset(r.w, r.h - math.floor((r.h - 4) * 0.55) - 4)
				end),
				RichText = true, TextScaled = true, TextWrapped = false,
				TextStrokeColor3 = UI.OUTLINE, TextStrokeTransparency = 0,
				Text = scope:Computed(function(use)
					local r = use(meteorReward)
					return if r then HudMessages.meteorReward(r.shards, r.top, Config.Meteor.TopBonus) else ""
				end),
				TextSize = 24, TextColor3 = WHITE, Visible = rewardActive,
				[Children] = { scope:New("UITextSizeConstraint")({
					MinTextSize = 10,
					MaxTextSize = scope:Computed(function(use) return if use(hud).notificationCompact then 16 elseif use(hud).touch then 20 else 24 end),
				}) },
			}),

`;
replace(marker,rewardView+marker);
fs.writeFileSync(file,source);
console.log('Replaced results modal with personal reward notification row');
