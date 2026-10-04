local fs=require('@lune/fs')
local luau=require('@lune/luau')
local modules={}
local function load(path,extra)
local env={require=function(k) return assert(modules[k],tostring(k)) end,warn=function(...) end}
for k,v in extra or {} do env[k]=v end
return luau.load(fs.readFile(path),{debugName=path,environment=env,injectGlobals=true})()
end
modules.Config={Monetization=load('src/shared/Config/Monetization.luau'),Home={OfflineCap=7200,OfflineCapPass=28800}}
-- Inject IDs ONLY into a detached config table so disabled purchase paths can be tested.
modules.Config.Monetization.Products.Overclock.Id=99
modules.Format={number=tostring}
local function signal() return {Fire=function() end,FireAll=function() end} end
local services={}
modules.Knit={CreateService=function(s) return s end,CreateSignal=signal,CreateProperty=function(v) return {SetFor=function() end,Set=function() end,Get=function() return v end} end,GetService=function(k) return services[k] end}
modules.Signal={new=signal}
local player={Name='Fake',Parent=true}
local data={receipts={},credits={callMeteor=0},overclockLeft=0}
local saveResult=false
services.DataService={Save=function() return saveResult end}
services.PlayerStateService={Get=function() return data end,ReplicateNow=function() end}
services.MeteorService={CallMeteor=function() return true end}
local apis={MarketplaceService={},Players={GetPlayerByUserId=function() return player end},ReplicatedStorage={Packages={Knit='Knit',Signal='Signal'},Shared={Config='Config',Format='Format'}},RunService={IsStudio=function() return false end},ServerStorage={GetAttribute=function() return nil end}}
local service=load('src/server/Services/MonetizationService.luau',{game={GetService=function(_,k) return apis[k] end},Enum={ProductPurchaseDecision={NotProcessedYet='RETRY',PurchaseGranted='GRANTED'}}})
service:KnitInit()
local old={PlayerId=1,ProductId=99,PurchaseId='old'}
print('FIRST',service:_processReceipt(old),data.overclockLeft,#data.receipts)
saveResult=true
for i=1,50 do service:_processReceipt({PlayerId=1,ProductId=99,PurchaseId='later'..i}) end
print('AFTER50',data.overclockLeft,#data.receipts,table.find(data.receipts,'old'))
print('RETRYOLD',service:_processReceipt(old),data.overclockLeft,#data.receipts)
assert(data.overclockLeft==52*1800)
print('Confirmed: one unacknowledged receipt is awarded a second time after the 50-entry eviction')
-- Independently verify whether the first value grant is protected from notification failures.
data={receipts={},credits={callMeteor=0},overclockLeft=0}
local throws=1
service.Client.Notice.Fire=function()
if throws>0 then throws-=1;error('fake network side effect') end
end
local ok=pcall(function() service:_processReceipt({PlayerId=1,ProductId=99,PurchaseId='notice'}) end)
print('NOTICEFAIL',ok,data.overclockLeft,#data.receipts)
print('NOTICERETRY',service:_processReceipt({PlayerId=1,ProductId=99,PurchaseId='notice'}),data.overclockLeft,#data.receipts)
assert(data.overclockLeft==3600)
print('Confirmed: a throw in notice after value mutation precedes recording and doubles Overclock on retry')
