"""Render PNG previews (architecture diagram + interface table) mirroring the deck."""
import textwrap
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle

SF_BLUE="#0176D3"; MULE="#006D9C"; GREEN="#2E844A"; NAVY="#032D60"; SLATE="#444A59"
LIGHT="#F3F4F6"; GREY="#323232"; WHITE="#FFFFFF"; LINE="#9AA0AA"; ORANGE="#C96A00"

# ---------------- Architecture diagram ----------------
fig, ax = plt.subplots(figsize=(13.333, 7.5), dpi=110)
ax.set_xlim(0, 13.333); ax.set_ylim(0, 7.5); ax.axis("off"); ax.invert_yaxis()

def rbox(x, y, w, h, text, fill, fg=WHITE, fs=10, bold=True, ls=None):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.08",
                 linewidth=1.2, edgecolor=(ls or fill), facecolor=fill, zorder=3))
    ax.text(x + w/2, y + h/2, text, ha="center", va="center", color=fg,
            fontsize=fs, fontweight=("bold" if bold else "normal"), zorder=4, wrap=True)
    return (x, y, w, h)

def cx(b): return b[0]+b[2]/2
def cy(b): return b[1]+b[3]/2
def link(a, b, color=LINE, lw=1.5, dash=None):
    ax.plot([cx(a), cx(b)], [cy(a), cy(b)], color=color, lw=lw, ls=(dash or "-"), zorder=1)

# title bar
ax.add_patch(Rectangle((0,0),13.333,1.0, facecolor=NAVY, edgecolor="none", zorder=2))
ax.text(0.4,0.5,"Solution Architecture \u2014 API-led, Event-driven on MuleSoft",
        color=WHITE, fontsize=18, fontweight="bold", va="center", zorder=4)

# headers
rbox(0.25,1.15,2.5,0.4,"CHANNELS",GREEN,fs=10)
rbox(3.05,1.15,3.0,0.4,"SALESFORCE PLATFORM",SF_BLUE,fs=10)
rbox(6.35,1.15,2.6,0.4,"INTEGRATION BACKBONE",MULE,fs=10)
rbox(9.25,1.15,3.85,0.4,"SYSTEMS OF RECORD / EXTERNAL",SLATE,fs=10)

mc=rbox(0.25,1.75,2.5,0.75,"Marketing Cloud\n(campaigns)",GREEN,fs=10)
dr=rbox(0.25,2.75,2.5,0.9,"Drupal Portal\n(self-service + forms)",GREEN,fs=10)
mo=rbox(0.25,3.9,2.5,0.75,"Hybrid Mobile App",GREEN,fs=10)
tr=rbox(0.25,4.9,2.5,0.9,"External Trading\nSystem (UI mashup)",GREEN,fs=10)

sf=rbox(3.05,1.75,3.0,4.05,"",SF_BLUE)
ax.text(4.55,2.05,"Salesforce",ha="center",color=WHITE,fontsize=15,fontweight="bold",zorder=4)
ax.text(3.2,3.7,"\u2022 Sales & Service Cloud\n\u2022 Headless Experience Cloud\n\u2022 Platform Events / CDC\n\u2022 Salesforce Connect (OData)\n\u2022 Apex / Flow / LWC\n\u2022 Composite & Pub-Sub APIs",
        ha="left",va="center",color=WHITE,fontsize=10,zorder=4)

mule=rbox(6.35,1.75,2.6,4.05,"",MULE)
ax.text(7.65,2.1,"MuleSoft\nAnypoint",ha="center",color=WHITE,fontsize=13,fontweight="bold",zorder=4)
ax.text(6.5,3.9,"\u2022 System / Process /\n   Experience APIs\n\u2022 mTLS + OAuth/OIDC\n\u2022 Central monitoring\n\u2022 Reusable templates\n\u2022 Error queue (DLQ)",
        ha="left",va="center",color=WHITE,fontsize=9.5,zorder=4)

sx=9.25; sw=3.85
cm=rbox(sx,1.75,sw,0.55,"Customer Master \u2014 Hadoop",SLATE,fs=10)
pm=rbox(sx,2.42,sw,0.55,"Position Master (real-time)",SLATE,fs=10)
cb=rbox(sx,3.09,sw,0.55,"Core Banking \u2014 OData",SLATE,fs=10)
ca=rbox(sx,3.76,sw,0.55,"Credit Agencies \u00d73+ (REST/OIDC)",SLATE,fs=10)
rs=rbox(sx,4.43,sw,0.55,"Legacy RockStar (migrate + sync)",SLATE,fs=10)
dl=rbox(sx,5.10,sw,0.55,"Enterprise Data Lake (CDC)",SLATE,fs=10)

for c in (mc,dr,mo): link(c,sf,color=GREEN)
link(tr,sf,color=GREEN,dash="--")
link(sf,mule,color=SF_BLUE,lw=2.5)
for b in (cm,pm,cb,ca,rs,dl): link(mule,b,color=MULE)
link(sf,cb,color=ORANGE,lw=1.3,dash="--")

ax.text(0.25,6.05,"Solid = via MuleSoft (monitored, mTLS, reusable)   \u00b7   Orange dashed = Salesforce Connect data virtualization   \u00b7   Blue = event/API bridge",
        fontsize=9.5,color=GREY)
ax.add_patch(Rectangle((0.25,6.3),2.0,0.4, facecolor=NAVY, edgecolor="none", zorder=3))
ax.text(1.25,6.5,"Key Assumptions",ha="center",va="center",color=WHITE,fontsize=11,fontweight="bold",zorder=4)
ax.text(2.45,6.5,"MuleSoft licensed; certs by EA \u00b7 Customer Master real-time+batch \u00b7 Core banking OData \u00b7 Agencies REST+OIDC \u00b7 Data lake subscribes \u00b7 Headless Experience Cloud (no Communities UI)",
        fontsize=9.5,color=GREY,va="center")

plt.subplots_adjust(left=0,right=1,top=1,bottom=0)
fig.savefig("preview_architecture.png", dpi=110)
plt.close(fig)

# ---------------- Interface table ----------------
headers=["ID","Source \u2192 Target","Content","Pattern","SF API / Mechanism","Security","Error handling"]
rows=[
["INT-01","Marketing Cloud \u2192 SF","Leads near-real-time to swarm","Remote Call-In + UI Update","Platform Event / Pub-Sub; empApi","OAuth + mTLS","Replay by replayId; DLQ"],
["INT-02","Drupal \u2192 SF","Capture prospect","Remote Call-In (Req-Reply)","REST API","OAuth + mTLS","Sync error; retry 5xx"],
["INT-03","Rules engine \u2192 SF","Daily call-list load","Batch Data Sync","Bulk API 2.0","Named Cred + mTLS","Failed-row reprocess"],
["INT-04","SF UI \u2192 map","Call list on a map","UI integration","lightning-map / Maps","Key in Named Cred","'Address not found'"],
["INT-05","SF \u2192 Manager UI","High-value call closed (live)","UI Update on Data Change","Platform Event + empApi","Sharing/FLS","Resubscribe + replay"],
["INT-06","SF \u2192 Credit agencies","Credit checks \u00d73+, \u22641 min, partial retry","RPC Request & Reply","Apex Continuation / Flow HTTP Callout \u2192 Mule fan-out","OpenID Connect + mTLS","'Agency XYZ down'; resubmit retries only failed"],
["INT-07","SF \u2192 Hadoop + Position Master","Registered customer near-real-time","RPC Fire & Forget","Platform Event \u2192 Mule fan-out","mTLS","Retry + DLQ \u2192 admin queue"],
["INT-08","Master \u2192 Experience Cloud","Create/activate user + invite","Remote Call-In","REST + createExternalUser","OAuth + mTLS","Retry queue"],
["INT-09","Drupal \u2194 Experience Cloud","Real-time self-service as end-user","Remote Call-In (Req-Reply)","Connect REST / headless APIs","End-user OAuth \u2014 no API user","401 \u2192 re-auth"],
["INT-10/12","Drupal \u2192 SF","Contact info / raise inquiry","Remote Call-In","REST API (end-user)","End-user OAuth + mTLS","Validation error to UI"],
["INT-11","SF \u2192 Core banking","Transaction history >100k/hr","Data Virtualization","Salesforce Connect (OData) + Mule cache","Named Cred + mTLS","Circuit breaker; cached"],
["INT-13","SF \u2192 Customer Master","Propagate updates","RPC Fire & Forget","Platform Event / CDC \u2192 Mule","mTLS","Retry + DLQ"],
["INT-14","Mobile \u2192 SF","Same functions as portal","Remote Call-In","REST / GraphQL","End-user OAuth (PKCE) + mTLS","Offline retry"],
["INT-15","Drupal/Mule \u2192 SF","Loan app all-or-nothing","Remote Call-In (transactional)","Composite API (allOrNone)","OAuth + mTLS","Whole-graph rollback"],
["INT-16","SF \u2194 Trading system","No swivel + auto-log","UI mashup + RPC","Canvas/iframe + SSO; log callout","SSO + mTLS","Log retry queue"],
["INT-17","SF \u2192 ESB","Millions of loan events/day","RPC Fire & Forget (scale)","High-Volume PE / Pub-Sub API","OAuth + mTLS","Replay + DLQ; monitor"],
["INT-18","RockStar \u2194 SF","Migration + 3-mo sync","Batch + near-real-time sync","Bulk API 2.0 + CDC \u2194 Mule","mTLS","Bulk error rows; conflict rules"],
["INT-19","SF \u2192 Data Lake","Non-PII; ins/upd/del; history, changed-fields-only","RPC Fire & Forget (event-driven)","Change Data Capture \u2192 Mule","mTLS + PII filter","Replay; gap detect; DLQ"],
]
col_frac=[0.06,0.155,0.17,0.14,0.195,0.13,0.15]
wrap_chars=[8,20,24,20,28,18,22]

fig, ax = plt.subplots(figsize=(15.5, 9.0), dpi=110)
ax.set_xlim(0,1); ax.set_ylim(0,1); ax.axis("off"); ax.invert_yaxis()
ax.add_patch(Rectangle((0,0),1,0.045, facecolor=NAVY, edgecolor="none"))
ax.text(0.005,0.022,"Interface List  \u2014  Pattern \u00b7 Salesforce API \u00b7 Security \u00b7 Error handling per interface",
        color=WHITE, fontsize=13, fontweight="bold", va="center")

xs=[0]; 
for f in col_frac: xs.append(xs[-1]+f)
top=0.055; row_h=(1-top)/ (len(rows)+1)

def wrapt(t,w): return "\n".join(textwrap.wrap(t,w)) or t

# header
for c,h in enumerate(headers):
    ax.add_patch(Rectangle((xs[c],top),col_frac[c],row_h, facecolor=NAVY, edgecolor=WHITE, lw=0.6))
    ax.text(xs[c]+0.004, top+row_h/2, h, color=WHITE, fontsize=8.5, fontweight="bold", va="center")
# body
for r,row in enumerate(rows):
    y=top+row_h*(r+1)
    fillc = LIGHT if r%2 else WHITE
    maxlines=1
    cells=[]
    for c,val in enumerate(row):
        wt=wrapt(val,wrap_chars[c]); cells.append(wt); maxlines=max(maxlines,wt.count("\n")+1)
    for c,val in enumerate(cells):
        ax.add_patch(Rectangle((xs[c],y),col_frac[c],row_h, facecolor=fillc, edgecolor="#D8DCE2", lw=0.5))
        ax.text(xs[c]+0.004, y+row_h/2, val, color=(NAVY if c==0 else GREY),
                fontsize=7.2, fontweight=("bold" if c==0 else "normal"), va="center")

plt.subplots_adjust(left=0.005,right=0.995,top=0.995,bottom=0.005)
fig.savefig("preview_interface_table.png", dpi=110)
plt.close(fig)
print("rendered preview_architecture.png and preview_interface_table.png")
