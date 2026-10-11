"""Author editable SVG gamepass illustrations from monetization.luau."""
from pathlib import Path
import json, re, zipfile

ROOT=Path('Z:/final-final-actual-final/MeteorShift')
OUT=ROOT/'assets/gamepass-icons'
OUT.mkdir(parents=True,exist_ok=True)
INK='#11172D'

def path(d,fill,stroke=INK,w=9,extra=''):
 return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'
def rect(x,y,w,h,fill,r=0,stroke=INK,sw=9):
 return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>'
def ellipse(x,y,rx,ry,fill,stroke=INK,w=9):
 return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{w}"/>'
def text(s,x,y,size=74,fill='#FFF6D6'):
 return f'<text x="{x}" y="{y}" text-anchor="middle" font-family="Inter,Arial" font-weight="900" font-size="{size}" fill="{fill}" stroke="{INK}" stroke-width="9" paint-order="stroke fill">{s}</text>'
def sparkle(x,y,s=16,color='#FFF3B7'):
 return path(f'M{x} {y-s} L{x+4} {y-4} L{x+s} {y} L{x+4} {y+4} L{x} {y+s} L{x-4} {y+4} L{x-s} {y} L{x-4} {y-4}Z',color,'none',0)
def badge(s,color='#FFE06B'):
 return ellipse(393,119,77,61,color)+text(s,393,144,69)
def crystal(x,y,s=1,color='#70EACF'):
 return f'<g transform="translate({x} {y}) scale({s})">'+path('M0 -79 L49 -39 L42 31 L0 75 L-49 30 L-48 -36Z',color)+path('M0 -79 L13 -32 L0 75 L-22 14 L-48 -36Z','#BDFDE4','none',0)+path('M13 -32 L49 -39 L42 31 L0 75Z','#2DAAB6','none',0)+path('M-48 -36 L13 -32 L49 -39','none',INK,5)+'</g>'
def coin(x,y,s=1):
 return f'<g transform="translate({x} {y}) scale({s})">'+ellipse(0,0,58,65,'#EDA72A')+ellipse(-4,-7,46,51,'#FFDF6B',INK,5)+path('M-21 -32 L-11 -43 L13 -43 L20 -32 L9 -21 L-9 -21 L-15 -10 L9 -10 L20 1 L20 20 L9 31 L-15 31 L-23 18','none','#B97521',10)+path('M0 -48 L0 -33 M0 27 L0 42','none','#B97521',7)+path('M-29 -34 L-19 -42','none','#FFF4B2',7)+'</g>'

def ore():
 a=crystal(244,269,1.45)+crystal(133,339,.83)+crystal(350,344,.78)
 a+=path('M88 387 L187 411 L311 414 L408 382 L382 426 L131 432Z','#253B55',INK,7)
 a+=path('M129 168 L293 337 L270 358 L112 190Z','#AE7850')
 a+=path('M105 167 Q197 101 280 144 L304 192 L239 172 Q177 160 112 202 L83 209Z','#D1E3E9')
 a+=path('M105 167 Q198 101 280 144 L284 158 Q184 135 102 187Z','#FFFFFF','none',0)
 a+=badge('2×')
 return a

def cash():
 a=path('M105 358 L112 185 L248 165 L333 215 L327 391 L189 414Z','#237D61')
 a+=path('M112 185 L248 165 L333 215 L191 236Z','#84E5A4')
 a+=path('M191 236 L333 215 L327 391 L189 414Z','#38B887')
 a+=path('M119 218 L170 238 M119 251 L169 271 M118 287 L169 306 M117 326 L168 343','none','#114B47',7)
 a+=coin(282,330,1.12)+coin(153,350,.76)+coin(199,269,.73)
 a+=path('M124 176 L149 168 L213 216 L186 223Z','#D4FFDF','none',0)
 a+=badge('2×','#88F3B1')
 return a

def backpack():
 a=path('M195 154 L195 119 Q253 88 298 120 L298 155','none','#E6AD68',21)
 a+=path('M164 174 Q138 246 146 399 L176 426 L339 416 Q365 324 344 203 L316 178Z','#22656D')
 a+=rect(152,153,190,268,'#48C6BA',35)
 a+=path('M162 168 L329 168 L313 249 L180 249Z','#98F0C8')
 a+=path('M169 177 L328 177','none','#D6FFE5',8)
 a+=rect(181,277,133,99,'#21878D',18)
 a+=rect(228,219,40,52,'#FDE58C',8,INK,7)
 a+=path('M183 312 L313 312','none','#70E5D4',6)
 a+=rect(126,287,32,84,'#277C84',9,INK,7)+rect(337,285,32,82,'#277C84',9,INK,7)
 a+=badge('2×')
 return a

def offline():
 a=path('M151 324 L148 217 L234 217 L234 326Z','#5964B6')
 a+=path('M104 324 L324 324 L359 380 L91 380Z','#8D9AE5')
 a+=rect(170,152,51,90,'#9AA9E7',9)+rect(250,211,48,112,'#B8C8F3',8)
 a+=path('M159 155 L227 155','none','#DDE8FF',10)
 a+=path('M196 83 L218 92 L210 110 L188 102Z','#B5C4F4',INK,5)
 a+=ellipse(354,193,69,77,'#FEE59D')
 a+=path('M374 131 Q341 161 365 201 Q381 222 414 219 Q393 249 362 245 Q321 240 302 210 Q281 175 299 148 Q326 119 354 117Z','#FFF0B4',INK,7)
 a+=ellipse(254,335,111,111,'#9BA8E4')+ellipse(254,335,91,91,'#F6F5FF',INK,6)
 a+=path('M254 257 L254 266 M326 335 L317 335 M254 413 L254 404 M179 335 L188 335','none','#646CB1',7)
 a+=text('8H',255,357,65,'#4754A4')
 return a

def deposit():
 a=path('M110 272 L391 272 L353 369 L149 369Z','#5C75AC')
 a+=path('M116 279 L385 279 L369 310 L134 310Z','#C5DDF0','none',0)
 a+=path('M149 369 L353 369 L335 413 L169 413Z','#2C466E')
 a+=ellipse(249,270,137,32,'#182C47',INK,8)
 a+=crystal(147,190,.59)+crystal(369,183,.47)
 a+=path('M208 117 L296 117 L296 202 L339 202 L253 290 L168 202 L208 202Z','#65E5C2')
 a+=path('M220 129 L281 129 L281 213 L307 213 L254 264 L204 213 L220 213Z','#AEFFD7','none',0)
 a+=path('M172 389 L327 389','none','#769DD2',8)
 a+=path('M83 183 Q60 257 113 313 M424 186 Q446 248 393 309','none','#D8EBFF',7)
 return a

def vip():
 a=ellipse(256,306,153,146,'#BE7F22')+ellipse(256,299,135,130,'#FFE086',INK,6)
 a+=ellipse(256,299,114,110,'#1D2445',INK,6)
 a+=path('M132 195 L111 101 L186 141 L253 77 L321 141 L400 101 L379 195Z','#FFD875')
 a+=path('M132 195 L379 195 L367 222 L146 222Z','#E2A63E')
 a+=path('M130 116 L150 178 L185 155 L253 97 L321 155 L377 125 L364 182 L148 182Z','#FFF2B1','none',0)
 a+=path('M252 133 L275 159 L252 184 L231 159Z','#AF79ED',INK,6)
 a+=text('VIP',256,325,87)
 a+=path('M145 391 L135 458 L206 421 M367 391 L377 458 L306 421','#B989DA')
 return a

def drillbot():
 a=path('M173 322 L123 364 L138 407 L199 408 L221 366Z','#738BA6')
 a+=path('M306 322 L355 364 L341 407 L280 408 L258 366Z','#738BA6')
 a+=rect(155,231,176,133,'#D99732',24)
 a+=path('M166 247 L319 247 L308 283 L176 283Z','#FFE599','none',0)
 a+=rect(211,289,68,39,'#FFEF9D',11,INK,6)
 a+=path('M174 255 L137 269 L106 333 L140 350 L175 300Z','#67829F')
 a+=path('M319 255 L352 268 L384 326 L349 343 L319 298Z','#67829F')
 a+=rect(136,143,218,120,'#C5DFE6',30)
 a+=rect(156,166,177,69,'#1D3749',16,INK,6)
 a+=rect(177,185,43,24,'#77F4DD',7,'none',0)+rect(266,185,43,24,'#77F4DD',7,'none',0)
 a+=path('M245 143 L245 110','none','#CEDFE7',10)+ellipse(245,99,15,15,'#65E9D0',INK,6)
 a+=path('M342 282 L378 263 L407 281 L417 321 L392 361 L344 333Z','#EBB142')
 a+=path('M392 276 L445 301 L466 334 L419 337 L382 316Z','#FFE7A1')
 a+=path('M404 284 L396 317 M422 294 L414 326 M440 307 L434 334','none','#A67731',6)
 a+=path('M175 376 L165 402 M309 376 L319 402','none','#C9DCE6',7)
 return a

def phoenix():
 a=''
 for flip in (False,True):
  side=''
  side+=path('M222 254 L137 192 L51 144 L78 227 L147 284 L218 306Z','#F1631D')
  side+=path('M211 277 L131 254 L45 245 L94 313 L168 335 L224 319Z','#EA431E')
  side+=path('M218 310 L136 315 L66 337 L123 368 L190 360 L231 333Z','#CB2D24')
  side+=path('M51 144 L69 199 L107 232 L78 227Z','#FFD75B','none',0)
  side+=path('M45 245 L76 290 L131 308 L94 313Z','#FFCF45','none',0)
  side+=path('M66 337 L106 359 L147 350 L123 368Z','#FFBA3A','none',0)
  side+=path('M85 208 L158 268 L194 278 M94 281 L172 311 M121 339 L190 337','none','#A92C23',7)
  a+=f'<g transform="translate(512 0) scale(-1 1)">{side}</g>' if flip else side
 a+=path('M242 322 Q225 368 189 412 L209 452 L254 415 L269 459 L308 442 Q275 382 276 326Z','#E4481C')
 a+=path('M209 394 L205 436 L236 416 L240 362 M261 389 L273 443 L294 433 L274 383','#FFBE30','none',0)
 a+=ellipse(256,287,61,78,'#E45417')
 a+=path('M223 258 L260 244 L289 283 L267 332 L235 331 L209 299Z','#FFA127','none',0)
 a+=path('M205 171 L198 139 L223 127 L208 95 L254 103 L242 65 L282 85 L299 122 L319 161 L308 224 L269 242 L224 221Z','#F36621')
 a+=path('M208 95 L249 104 L269 137 L227 130Z','#FFB03F','none',0)
 a+=path('M254 103 L242 65 L277 80 L290 105Z','#FFD454','none',0)
 a+=path('M208 168 L242 147 L272 170 L254 218 L225 211Z','#DC3E1D','none',0)
 a+=path('M267 163 L299 157 L292 184 L268 191Z','#FFF18C',INK,6)
 a+=path('M293 188 L315 185 L327 203 L303 219 L286 207Z','#FFC447',INK,7)
 a+=path('M226 347 L219 368 L241 376 L252 362 M270 347 L270 367 L293 374 L304 359','#FFAD37',INK,7)
 return a

DESIGNS=[('TwoXOre','2x Ore','#23BEA7',ore),('TwoXCash','2x Cash','#42C582',cash),
 ('BiggerBackpack','Bigger Backpack','#34B8B2',backpack),('OfflineHours','Offline Hours+','#8B8EE8',offline),
 ('AutoDeposit','Auto-Deposit','#59C7E4',deposit),('VIP','VIP','#D7AA52',vip),
 ('Drillbot','Drillbot Pet','#DCAA51',drillbot),('SolarPhoenix','Solar Phoenix Pet','#F47537',phoenix)]
source=(ROOT/'src/shared/config/monetization.luau').read_text()
records=[]
for key,name,accent,fn in DESIGNS:
 bg=f'''<defs><radialGradient id="bg" cx="50%" cy="40%" r="75%"><stop stop-color="{accent}" stop-opacity=".48"/><stop offset="1" stop-color="#11172D"/></radialGradient></defs>
 <rect width="512" height="512" fill="#141E36"/><rect width="512" height="512" fill="url(#bg)"/>
 <circle cx="256" cy="251" r="185" fill="none" stroke="{accent}" stroke-opacity=".18" stroke-width="2"/>
 <circle cx="256" cy="251" r="163" fill="none" stroke="{accent}" stroke-opacity=".13" stroke-width="15"/>
 <path d="M32 83V32H83 M429 32H480V83 M32 429V480H83 M429 480H480V429" fill="none" stroke="{accent}" stroke-opacity=".72" stroke-width="5"/>
 <path d="M73 112L100 136 M413 384L438 410 M80 404L110 373 M399 114L426 85" stroke="{accent}" stroke-opacity=".35" stroke-width="12"/>
 <ellipse cx="256" cy="437" rx="159" ry="22" fill="#080E22" opacity=".4"/>'''
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">{bg}{fn()}{sparkle(84,85,13)}{sparkle(417,426,12)}{sparkle(426,71,7)}</svg>'
 (OUT/f'{key}.svg').write_text(svg,encoding='utf-8')
 match=re.search(r'\b'+key+r'\s*=\s*\{(.*?)\}\s*:: Pass',source,re.S)
 body=match.group(1)
 desc=re.search(r'Description\s*=\s*"([^"]+)"',body).group(1)
 price=re.search(r'Robux\s*=\s*(\d+)',body)
 records.append(dict(key=key,name=name,accent=accent,description=desc,robux=int(price.group(1)) if price else None,svg=svg))
(OUT/'designs.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print(json.dumps({'icons':len(records),'folder':str(OUT)}))
