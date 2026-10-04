local fs=require('@lune/fs')
local luau=require('@lune/luau')
local serde=require('@lune/serde')
local function copy(x) if type(x)~='table'then return x end local r={} for k,v in x do r[k]=copy(v)end return r end
local function signal()local callbacks={}return{Connect=function(_,fn)table.insert(callbacks,fn)end,Fire=function(_,...)for _,fn in callbacks do fn(...)end end}end
local function fixture(failProbe)
 local state={records={},storeWrites=0,warnings={},clock=1000,delayed={}}
 local db={GetAsync=function()if failProbe then error('injected production datastore outage')end return nil end}
 function db:UpdateAsync(key,fn)
  state.storeWrites+=1
  if state.pauseNext then state.pauseNext=false;coroutine.yield('write paused before provider commit')end
  local value=fn(copy(state.records[key]))
  if value~=nil then state.records[key]=copy(value)end
  return copy(value)
 end
 local players={PlayerAdded=signal(),PlayerRemoving=signal(),GetPlayers=function()return{}end}
 local modules={Knit={CreateService=function(def)return def end},Signal={new=signal}}
 local template=luau.load(fs.readFile('src/server/Lib/ProfileTemplate.luau'))()
 modules.Template=template
 local services={DataStoreService={GetDataStore=function()return db end},HttpService={GenerateGUID=function()return'SESSION-A'end},Players=players,ReplicatedStorage={Packages={Knit='Knit',Signal='Signal'}},RunService={IsStudio=function()return false end}}
 local service=luau.load(fs.readFile('src/server/Services/DataService.luau'),{debugName='DataServiceAudit',injectGlobals=true,environment={
  game={JobId='SESSION-A',GetService=function(_,name)return assert(services[name])end,BindToClose=function()end},
  script={Parent={Parent={Lib={ProfileTemplate='Template'}}}},require=function(name)return assert(modules[name])end,
  task={wait=function()end,spawn=function(fn,...)table.insert(state.delayed,{fn,...})end},
  os={time=function()return state.clock end,clock=function()return state.clock end},
  warn=function(...)table.insert(state.warnings,{...})end,
 }})()
 service:KnitInit()
 local function player(id)local p={UserId=id,Name='Test'..id,Parent=true,Kick=function()end}return p end
 return service,state,player
end
local report={}
do
 local service,state,player=fixture(false)
 local a,b=player(1),player(2);service:_load(a);service:_load(b)
 state.records.player_1.lock={session='OTHER',time=1000}
 report.lockLossSaveResult=service:Save(a)
 service:GetProfile(b).Data.cash=123
 report.unrelatedSaveResultAfterLockLoss=service:Save(b)
 report.unrelatedCashActuallyPersisted=state.records.player_2.data.cash
end
do
 local service,state,player=fixture(true)
 local p=player(3);service:_load(p);service:GetProfile(p).Data.cash=999
 report.nonStudioMemoryProfile=service:GetProfile(p).Memory
 report.nonStudioMemorySaveReportsSuccess=service:Save(p)
 report.nonStudioDurableWriteCount=state.storeWrites
end
do
 local service,state,player=fixture(false)
 local p=player(4);service:_load(p);service:GetProfile(p).Data.cash=100
 state.pauseNext=true
 local pending=coroutine.create(function()service:Save(p)end)
 assert(coroutine.resume(pending))
 service:GetProfile(p).Data.cash=200
 service:_release(p)
 report.cashAfterRelease=state.records.player_4.data.cash
 report.lockAfterRelease=state.records.player_4.lock
 assert(coroutine.resume(pending))
 report.cashAfterOlderSaveCompletes=state.records.player_4.data.cash
 report.lockAfterOlderSaveCompletes=state.records.player_4.lock.session
end
fs.writeFile('.tmp/audit-data-service.json',serde.encode('json',report,true))
print(serde.encode('json',report,true))
