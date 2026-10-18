import dev.licensebox.WolframBridge;
public final class BridgeLifetime {
 public static void main(String[] args) {
  String options="{\"product\":\"demo\",\"keys\":{\"test-key\":\"A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg\"},\"directory\":\"/tmp/licensebox-wolfram-bridge-lifetime\",\"server\":\"http://127.0.0.1:1\"}";
  for(int i=0;i<100;i++)try(WolframBridge client=new WolframBridge(options,null,false,false,false,false)) {
   if(!client.creationError().isEmpty())throw new AssertionError(client.creationError());
   client.close();if(!client.call("status","{}").contains("closed"))throw new AssertionError("closed handle accepted");
  }
  WolframBridge.Callbacks callbacks=new WolframBridge.Callbacks(){public void signIn(String u,String c){}public double clock(){return 1700000000;}public String binding(){throw new IllegalStateException("expected callback failure");}public boolean cancelled(){return false;}};
  try(WolframBridge client=new WolframBridge(options,callbacks,false,true,true,false)) {
   if(!client.call("sign_in","{\"timeout\":0.1}").contains("callback_error"))throw new AssertionError("callback failure lost");
  }
 }
}
