Get[FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]],"Kernel","Licensebox.wl"}]];
Do[c=LicenseboxOpen[<|"product"->"demo","keys"-><|"test-key"->"A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg"|>,"directory"->FileNameJoin[{$TemporaryDirectory,"licensebox-wolfram-lifetime"}]|>];If[FailureQ[c],Print[c];Exit[1]];LicenseboxClose[c],{100}];
