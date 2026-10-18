Get[FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]],"Kernel","Licensebox.wl"}]];
assert[condition_,description_String]:=If[!TrueQ[condition],Print["FAIL: ",description];Exit[1]];
options=<|"product"->"demo","keys"-><|"test-key"->"A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg"|>,"directory"->FileNameJoin[{$TemporaryDirectory,"licensebox-wolfram-callbacks"}],"server"->"http://127.0.0.1:1"|>;
binding="m1:linux-machine-id:783b8906a4af61095e68f3f0b4468a953be69ddd7afcf35850b501a7361f309e";
base=<|"clock"->Function[1700000000.],"machine_binding"->Function[binding]|>;
Do[
 c=LicenseboxOpen[options,Join[base,callback]];
 assert[AssociationQ[c],"callback test must create an actual client"];
 result=LicenseboxSignIn[c,.1];
 assert[FailureQ[result]&&result[[1]]==="callback_error","callback exceptions and invalid results must be contained"];
 LicenseboxClose[c];LicenseboxClose[c];
 assert[MatchQ[LicenseboxStatus[c],Failure["closed",_Association]],"closed clients must be rejected"],
 {callback,{<|"machine_binding"->Function[Throw["expected"]]|>,<|"machine_binding"->Function[Throw["expected","tag"]]|>,<|"machine_binding"->Function[42]|>,<|"clock"->Function[Abort[]]|>,<|"clock"->Function[Infinity]|>,<|"cancelled"->Function[42]|>}}
];
c=LicenseboxOpen[options,Join[base,<|"cancelled"->Function[True]|>]];
assert[AssociationQ[c],"cancellation test must create an actual client"];
assert[MatchQ[LicenseboxSignIn[c,.1],Failure["cancelled",_Association]],"typed cancellation must map to native cancellation"];
LicenseboxClose[c];
c=LicenseboxOpen[options,Join[base,<|"machine_binding"->Function[reentry=LicenseboxStatus[c];binding]|>]];
assert[AssociationQ[c],"reentry test must create an actual client"];
LicenseboxSignIn[c,.1];
assert[MatchQ[reentry,Failure["invalid_argument",_Association]],"callbacks must not reenter a client"];
LicenseboxClose[c];
Print["PASS: actual Wolfram callback exception, abort, type, reentry and closed-client checks"];
