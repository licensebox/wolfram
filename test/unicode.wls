Get[FileNameJoin[{DirectoryName[DirectoryName[$InputFileName]],"Kernel","Licensebox.wl"}]];
sample="caf\:00e9 \:2013 test \:4e16\:754c";
encoded=Licensebox`Private`encode[<|"ok"->True,"value"->sample|>];
If[!StringQ[encoded]||!MemberQ[ToCharacterCode[encoded],233],Print["FAIL: JSON must be Unicode at the Java boundary"];Exit[1]];
If[Licensebox`Private`unwrap[encoded]=!=sample,Print["FAIL: Java JSON Unicode roundtrip"];Exit[1]];
Print["PASS: Wolfram RawJSON UTF-8 byte strings and Java Unicode roundtrip"];
