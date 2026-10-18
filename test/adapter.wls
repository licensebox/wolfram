Get[FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]],"Kernel","Licensebox.wl"}]];
r=Licensebox`Private`decode[$ScriptInputString];
run[r_]:=Module[{c,v,options},Switch[r["op"],"derive",Return[LicenseboxDeriveBinding[r["product"],r["source"],r["raw_id"]]],"native",Return[LicenseboxNativeBinding[r["product"]]],"verify",Return[LicenseboxVerifyLease[r["token"],r["product"],r["keys"],r["now"]]]];
 options=KeyTake[r,{"product","keys","server","directory","ca_bundle"}];options["version"]="conformance";
 c=LicenseboxOpen[options,<|"clock"->Function[r["now"]],"machine_binding"->Function[Lookup[r,"binding",""]],"on_sign_in"->Function[{url,code},Null]|>];If[FailureQ[c],Return[c]];
 v=Switch[r["op"],"lease",LicenseboxLease[c],"require",LicenseboxRequire[c,Lookup[r,"module","core"]],"repeat",With[{x=LicenseboxRequire[c,"core"]},If[FailureQ[x],x,LicenseboxRequire[c,"core"]]],"status",LicenseboxStatus[c],"sign_in",LicenseboxSignIn[c,3.],"logout",LicenseboxLogout[c],"modules",LicenseboxModules[c],"requests",LicenseboxRequests[c],"request",LicenseboxRequestAccess[c,{"export"},"caf\:00e9 \:2013 test"],"access-link",LicenseboxAccessLink[c],"record",LicenseboxRecord[c,"export",True,.125];LicenseboxRecord[c,"export",False,.025];Null];LicenseboxClose[c];v];
v=run[r];Print[Licensebox`Private`encode[If[FailureQ[v],<|"ok"->False,"error"->v[[1]]|>,<|"ok"->True,"value"->v|>]]];
