Get[FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]],"Kernel","Licensebox.wl"}]];
Do[c=LicenseboxOpen[<|"product"->"demo","keys"-><|"test-key"->"A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg"|>,"directory"->FileNameJoin[{$TemporaryDirectory,"licensebox-wolfram-lifetime"}]|>];If[!AssociationQ[c]||!JLink`JavaObjectQ[c["Object"]],Print["FAIL: client creation did not return a live client"];Exit[1]];LicenseboxClose[c],{100}];

Print["PASS: actual Wolfram 100-client creation and deterministic close"];
