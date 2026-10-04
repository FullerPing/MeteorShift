local fs = require('@lune/fs')
local luau = require('@lune/luau')
local roblox = require('@lune/roblox')
local modules = {}
local function load(path, extra)
    local env = { require = function(name) return assert(modules[name], 'Unknown '..tostring(name)) end, Color3 = roblox.Color3, Enum = roblox.Enum, Random = {new=function(seed) local state=seed; return {NextNumber=function() state=(state*16807)%2147483647;return state/2147483647 end} end} }
    for k,v in extra or {} do env[k] = v end
    return luau.load(fs.readFile(path), {debugName=path, environment=env, injectGlobals=true})()
end
local config={}
for _,key in {'Home','Balance','Meteor','Pickaxes','Backpacks','Debris','Rebirth','Index','Monetization'} do
    config[key] = load('src/shared/Config/'..key..'.luau')
    modules[key]=config[key]
end
modules.Config=config
modules.Format=load('src/shared/Format.luau')
local parent={Config='Config',Format='Format'}
local p=load('src/shared/Pacing.luau',{script={Parent=parent}})
local result=p.simulate(10*3600)
print('PACING CYCLE',result.cycle)
for _,buy in result.purchases do print('BUY',buy.id,buy.time,buy.cost,buy.cashAfter) end
for _,time in {1800,3600,7200,4*3600,5*3600,6*3600,7*3600,8*3600,10*3600} do
    local s=p.sampleAt(result,time); print('SAMPLE',time,s.cash,s.earned,s.shards,s.incomePerMinute,s.owned.pickaxe,s.owned.backpack,s.owned.conveyor,s.owned.refinery)
end
modules.RebirthConfig=config.Rebirth; parent.Config={Meteor='Meteor',Home='Home',Pickaxes='Pickaxes',Backpacks='Backpacks',Balance='Balance',Rebirth='RebirthConfig',Index='Index'}
local power=load('src/shared/MiningPower.luau',{script={Parent=parent}})
local types=load('src/shared/MeteorTypes.luau',{script={Parent=parent}})
for n=1,4 do
    local group=table.create(n,1)
    local sized=power.serverPower(group)
    local seconds=(config.Meteor.CrustSeconds*.6+config.Meteor.CoreSeconds)*sized/(n*power.perSecond(1))
    print('CRACKLOWERBOUND',n,seconds,seconds/.7,seconds*.8)
end
for tier=1,8 do
    local pick=config.Pickaxes[tier]
    local debris=if tier==3 or tier==4 then 'frost' else config.Debris.Ore
    local value=pick.OrePerHit*config.Debris.YieldFraction*config.Home.BarPrices[debris]
    print('DEBRISHIT',tier,debris,value,value/pick.Swing)
end
for _,tier in {1,2,3,4} do
    local cap=types.underTierCap(tier,config.Backpacks[if tier==1 then 1 elseif tier<4 then 2 else 4].Capacity,config.Meteor.Types.Crystal)
    print('CRYSTALUNDER',tier,cap,cap*3000,math.floor(cap)*3000)
end
print('OVERCLKL1',math.min(.3,.25),math.min(.3,.25*2))
print('OFFLINECAPL1FREE',p.offlineCap(), 'PASS',p.offlineCap(8))
local source=fs.readFile('src/shared/Pacing.luau')
source=source:gsub('debris %* BarPrice', 'debris * ((owned.pickaxe == 3 or owned.pickaxe == 4) and Config.Home.BarPrices.frost or BarPrice)')
source=source:gsub('else BarPrice', 'else ((owned.pickaxe == 3 or owned.pickaxe == 4) and Config.Home.BarPrices.frost or BarPrice)')
local q=luau.load(source,{debugName='sensitivity-memory-only', environment={require=function() return config end,script={Parent={Config='Config'}}},injectGlobals=true})()
local sensitivity=q.simulate(8*3600)
print('SENSITIVITY ONLY DEBRIS VALUATION CHANGED')
for _,buy in sensitivity.purchases do print('BUY',buy.id,buy.time,buy.cost,buy.cashAfter) end
for _,time in {1800,3600,7200,4*3600,5*3600,6*3600,7*3600,8*3600} do
local s=q.sampleAt(sensitivity,time); print('SAMPLE',time,s.cash,s.earned,s.shards,s.incomePerMinute,s.owned.pickaxe,s.owned.backpack,s.owned.conveyor,s.owned.refinery)
end
modules.Pacing=p
modules.MiningPower=power
modules.MeteorTypes=types
modules.DebrisOre=load('src/shared/DebrisOre.luau',{script={Parent={Config={Debris='Debris'}}}})
modules.Rebirth=load('src/shared/Rebirth.luau',{script={Parent=parent}})
modules.MineralIndex=load('src/shared/MineralIndex.luau',{script={Parent=parent}})
modules.Rewards=load('src/server/Lib/Rewards.luau',{game={GetService=function() return {Shared={Config='Config'}} end}})
local shared={Config='Config',Pacing='Pacing',MiningPower='MiningPower',MeteorTypes='MeteorTypes',DebrisOre='DebrisOre',Rebirth='Rebirth',MineralIndex='MineralIndex'}
shared.Config=parent.Config; modules[shared.Config]=config; shared.Format="Format"
local passed,failed=0,0
local t={shared=shared,lib={Rewards='Rewards'}}
function t.test(name,fn) local ok,err=pcall(fn);if ok then passed+=1 else failed+=1;print('FAIL',name,err) end end
function t.eq(a,b,msg) assert(a==b,(msg or 'eq')..': '..tostring(a)..' != '..tostring(b)) end
function t.near(a,b,eps,msg) assert(math.abs(a-b)<=eps,msg or 'near') end
function t.ok(v,msg) assert(v,msg or 'ok') end
for _,key in {'Pacing','MiningPower','MeteorTypes','DebrisOre','Rebirth','MineralIndex','Rewards'} do load('tests/'..key..'.spec.luau')(t) end
print('ECONOMY PURE SPEC TOTAL',passed,failed)
assert(failed==0)


