BeginPackage["Licensebox`"];
LicenseboxOpen::usage="LicenseboxOpen[options, callbacks] creates a native licensing client. callbacks are trusted functions keyed by on_sign_in, clock, machine_binding, cancelled.";
LicenseboxClose::usage="LicenseboxClose[client] releases native resources.";
LicenseboxLease::usage="LicenseboxLease[client] checks protected access.";
LicenseboxRequire::usage="LicenseboxRequire[client,module] checks module access.";
LicenseboxStatus::usage="LicenseboxStatus[client] returns local verified status.";
LicenseboxSignIn::usage="LicenseboxSignIn[client,timeout] explicitly activates.";
LicenseboxLogout::usage="LicenseboxLogout[client] removes cached authorization.";
LicenseboxModules::usage="LicenseboxModules[client] lists modules.";
LicenseboxRequests::usage="LicenseboxRequests[client] lists requests.";
LicenseboxRequestAccess::usage="LicenseboxRequestAccess[client,modules,note] requests access.";
LicenseboxAccessLink::usage="LicenseboxAccessLink[client] returns a private access link.";
LicenseboxRecord::usage="LicenseboxRecord[client,command,success,elapsed] records fixed-command usage.";
LicenseboxDeriveBinding::usage="LicenseboxDeriveBinding[product,source,raw] derives native binding.";
LicenseboxNativeBinding::usage="LicenseboxNativeBinding[product] reads native identity locally.";
LicenseboxVerifyLease::usage="LicenseboxVerifyLease[token,product,keys,now] verifies exact signed bytes.";
Begin["`Private`"];
Needs["JLink`"];
$root=DirectoryName[DirectoryName[$InputFileName]];
$initialized=False;
failure[code_String]:=Failure[code,<|"MessageTemplate"->code|>];
dependency[name_String,local_String,system_String]:=With[{configured=Environment[name]},Which[StringQ[configured]&&configured!="",configured,FileExistsQ[FileNameJoin[{$root,"build",local}]],FileNameJoin[{$root,"build",local}],True,system]];
initialize[]:=Module[{jna,gson,bridge,link,loaded},
 If[TrueQ[$initialized],Return[True]];
 jna=dependency["JNA_JAR","jna.jar","/usr/share/java/jna.jar"];
 gson=dependency["GSON_JAR","gson.jar","/usr/share/java/gson.jar"];
 bridge=FileNameJoin[{$root,"build","licensebox-wolfram.jar"}];
 If[!AllTrue[{jna,gson,bridge},FileExistsQ],Return[failure["native_dependency_missing"]]];
 link=InstallJava[];If[Head[link]=!=LinkObject,Return[failure["java_unavailable"]]];
 AddToClassPath[bridge,jna,gson];loaded=LoadJavaClass["dev.licensebox.WolframBridge"];
 If[Head[loaded]=!=JavaClass,Return[failure["native_dependency_missing"]]];
 (* J/Link proxy results require Boolean objects, retained once per JVM. *)
 $trueObject=JavaNew["java.lang.Boolean",True];$falseObject=JavaNew["java.lang.Boolean",False];
 If[!JavaObjectQ[$trueObject]||!JavaObjectQ[$falseObject],Return[failure["native_dependency_missing"]]];
 $initialized=True;True
];
(* RawJSON uses UTF-8 byte strings; J/Link uses Unicode Java strings. *)
encode[x_]:=FromCharacterCode[ToCharacterCode[ExportString[x,"RawJSON","Compact"->True]],"UTF8"];
decode[s_String]:=ImportString[FromCharacterCode[ToCharacterCode[s,"UTF8"]],"RawJSON"];
unwrap[s_String]:=Module[{a=Quiet[Check[decode[s],$Failed]]},If[!AssociationQ[a]||!KeyExistsQ[a,"ok"],Return[failure["protocol_error"]]];If[TrueQ[a["ok"]],Lookup[a,"value",Null],failure[Lookup[a,"error","protocol_error"]]]];
unwrap[_]:=failure["native_error"];
callbackDefault["cancelled"]:=Function[False];
callbackDefault[_]:=Function[Null];
callbackFallback["clock"]:=0.;callbackFallback["machine_binding"]:="";callbackFallback["cancelled"]:=$trueObject;callbackFallback[_]:=Null;
invokeCallback[f_,key_String,args_List,state_Symbol]:=Module[{value,valid=True,completed=False},
 If[TrueQ[state[]],Return[callbackFallback[key]]];
 value=Catch[Catch[(value=CheckAbort[Quiet[Check[Apply[f,args],$Failed]],$Failed];completed=True;value),_,Function[{v,t},$Failed]]];
 If[!TrueQ[completed]||value===$Failed,valid=False,
  Switch[key,
   "clock",value=Quiet[Check[N[value,MachinePrecision],$Failed]];valid=MachineNumberQ[value]&&TrueQ[Im[value]==0],
   "machine_binding",valid=StringQ[value]&&StringFreeQ[value,FromCharacterCode[0]],
   "cancelled",valid=MatchQ[value,True|False],
   "on_sign_in",value=Null]];
 If[!TrueQ[valid],state[]=True;callbackFallback[key],If[key==="cancelled",If[TrueQ[value],$trueObject,$falseObject],value]]
];
LicenseboxOpen[options_Association,callbacks_Association:<||>]:=Module[{symbols,proxy,obj,error,state,busy,ready,flags,methods={"signIn","clock","binding","cancelled"},names={"on_sign_in","clock","machine_binding","cancelled"}},
 ready=initialize[];If[FailureQ[ready],Return[ready]];
 If[!SubsetQ[names,Keys[callbacks]]||!AllTrue[Values[callbacks],MatchQ[#,_Function|_Symbol]&],Return[failure["invalid_argument"]]];
 symbols=Table[Unique["Licensebox`Private`callback$"],4];state=Unique["Licensebox`Private`callbackState$"];busy=Unique["Licensebox`Private`busy$"];state[]=False;busy[]=False;
 MapThread[Function[{symbol,key},With[{s=symbol,f=Lookup[callbacks,key,callbackDefault[key]],k=key,st=state},s[args___]:=invokeCallback[f,k,{args},st]]],{symbols,names}];
 proxy=ImplementJavaInterface["dev.licensebox.WolframBridge$Callbacks",MapThread[Rule,{methods,(Context[#]<>SymbolName[#])&/@symbols}]];
 flags=Append[KeyExistsQ[callbacks,#]&/@Take[names,3],True];
 obj=Quiet[Check[JavaNew["dev.licensebox.WolframBridge",encode[options],proxy,Sequence@@flags],$Failed]];
 If[!JavaObjectQ[obj],If[JavaObjectQ[proxy],ReleaseJavaObject[proxy]];Scan[ClearAll,Join[symbols,{state,busy}]];Return[failure["native_error"]]];
 error=obj@creationError[];
 If[error!="",ReleaseJavaObject[obj];ReleaseJavaObject[proxy];Scan[ClearAll,Join[symbols,{state,busy}]];Return[failure[error]]];
 <|"Object"->obj,"Proxy"->proxy,"Symbols"->symbols,"CallbackState"->state,"Busy"->busy|>
];
LicenseboxClose[c_Association]:=Module[{busy=Lookup[c,"Busy",None]},
 If[busy=!=None&&TrueQ[busy[]],Return[failure["invalid_argument"]]];
 If[JavaObjectQ[c["Object"]],c["Object"]@close[];ReleaseJavaObject[c["Object"]]];
 If[JavaObjectQ[c["Proxy"]],ReleaseJavaObject[c["Proxy"]]];
 Scan[ClearAll,Join[c["Symbols"],{c["CallbackState"],c["Busy"]}]];Null
];
call[c_Association,op_,args_:<||>]:=Module[{busy=Lookup[c,"Busy",None],state=Lookup[c,"CallbackState",None],result},
 If[!JavaObjectQ[c["Object"]],Return[failure["closed"]]];
 If[busy===None||state===None,Return[failure["invalid_argument"]]];
 If[TrueQ[busy[]],Return[failure["invalid_argument"]]];busy[]=True;
 result=CheckAbort[Quiet[Check[unwrap[c["Object"]@call[op,encode[args]]],failure["native_error"]]],busy[]=False;Abort[]];busy[]=False;
 If[TrueQ[state[]],state[]=False;failure["callback_error"],result]
];
LicenseboxLease[c_]:=call[c,"lease"];
LicenseboxRequire[c_,m_String]:=call[c,"require",<|"module"->m|>];
LicenseboxStatus[c_]:=call[c,"status"];
LicenseboxSignIn[c_,t_:0.]:=call[c,"sign_in",<|"timeout"->N[t]|>];
LicenseboxLogout[c_]:=call[c,"logout"];
LicenseboxModules[c_]:=call[c,"modules"];
LicenseboxRequests[c_]:=call[c,"requests"];
LicenseboxRequestAccess[c_,ms_List,note_String:""]:=call[c,"request",<|"modules"->ms,"note"->note|>];
LicenseboxAccessLink[c_]:=call[c,"access-link"];
LicenseboxRecord[c_,command_String,success:(True|False),elapsed_?NumericQ]:=call[c,"record",<|"command"->command,"success"->success,"elapsed"->N[elapsed]|>];
LicenseboxDeriveBinding[p_String,s_String,raw_String]:=Module[{ready=initialize[]},If[FailureQ[ready],ready,unwrap[WolframBridge`derive[p,s,raw]]]];
LicenseboxNativeBinding[p_String]:=Module[{ready=initialize[]},If[FailureQ[ready],ready,unwrap[WolframBridge`nativeBinding[p]]]];
LicenseboxVerifyLease[t_String,p_String,keys_Association,now_?NumericQ]:=Module[{ready=initialize[]},If[FailureQ[ready],ready,unwrap[WolframBridge`verify[t,p,encode[keys],N[now]]]]];
End[];EndPackage[];
