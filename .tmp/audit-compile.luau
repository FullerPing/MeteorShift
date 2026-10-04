local fs=require('@lune/fs');local luau=require('@lune/luau');local serde=require('@lune/serde')
local list=serde.decode('json',fs.readFile('.tmp/audit-source-manifest.json'));local report={compiled=0,failures={}}
for _,e in list do local ok,err=pcall(function()luau.load(fs.readFile(e.file),{debugName=e.file})end);if ok then report.compiled+=1 else table.insert(report.failures,{file=e.file,error=tostring(err)})end end
fs.writeFile('.tmp/audit-compile.json',serde.encode('json',report,true));print(serde.encode('json',report,true))
