package dev.licensebox;
import com.google.gson.*;
import java.util.*;
/** J/Link interface: callbacks are application functions, never JSON settings. */
public final class WolframBridge implements AutoCloseable {
 public interface Callbacks {void signIn(String url,String code);double clock();String binding();boolean cancelled();}
 private Client client;private String creationError;
 public WolframBridge(String json,Callbacks cb,boolean sign,boolean clock,boolean binding,boolean cancel){
  try{JsonObject o=JsonParser.parseString(json).getAsJsonObject();Map<String,String> keys=new LinkedHashMap<>();o.getAsJsonObject("keys").entrySet().forEach(e->keys.put(e.getKey(),e.getValue().getAsString()));Client.Config cfg=new Client.Config(o.get("product").getAsString(),keys);
   if(o.has("version"))cfg.version=o.get("version").getAsString();if(o.has("server"))cfg.server=o.get("server").getAsString();if(o.has("directory"))cfg.directory=o.get("directory").getAsString();if(o.has("ca_bundle"))cfg.caBundle=o.get("ca_bundle").getAsString();
   if(sign)cfg.onSignIn=cb::signIn;if(clock)cfg.clock=cb::clock;if(binding)cfg.machineBinding=cb::binding;if(cancel)cfg.cancelled=cb::cancelled;client=new Client(cfg);
  }catch(Client.LicenseboxException e){creationError=e.code;}
 }
 public String creationError(){return creationError==null?"":creationError;}
 private static String success(JsonElement v){JsonObject o=new JsonObject();o.addProperty("ok",true);o.add("value",v);return o.toString();}
 private static String failure(String code){JsonObject o=new JsonObject();o.addProperty("ok",false);o.addProperty("error",code);return o.toString();}
 public synchronized String call(String op,String args){try{if(client==null)return failure("closed");JsonObject a=JsonParser.parseString(args).getAsJsonObject();JsonElement v;
  switch(op){case "lease":v=client.lease();break;case "require":v=client.require(a.get("module").getAsString());break;case "status":v=client.status();break;case "sign_in":v=client.signIn(a.get("timeout").getAsDouble());break;case "logout":client.logout();v=JsonNull.INSTANCE;break;case "modules":v=client.modules();break;case "requests":v=client.requests();break;case "request":List<String> ms=new ArrayList<>();a.getAsJsonArray("modules").forEach(x->ms.add(x.getAsString()));v=client.requestAccess(ms,a.get("note").getAsString());break;case "access-link":v=new JsonPrimitive(client.accessLink());break;case "record":client.record(a.get("command").getAsString(),a.get("success").getAsBoolean(),a.get("elapsed").getAsDouble());v=JsonNull.INSTANCE;break;default:return failure("invalid_argument");}return success(v);
 }catch(Client.LicenseboxException e){return failure(e.code);}catch(IllegalStateException e){return failure("invalid_argument");}}
 public synchronized void close(){if(client!=null){client.close();client=null;}}
 public static String derive(String p,String s,String raw){try{return success(new JsonPrimitive(Client.deriveBinding(p,s,raw)));}catch(Client.LicenseboxException e){return failure(e.code);}}
 public static String nativeBinding(String p){try{return success(new JsonPrimitive(Client.nativeBinding(p)));}catch(Client.LicenseboxException e){return failure(e.code);}}
 public static String verify(String token,String p,String keys,double now){try{Map<String,String> ks=new LinkedHashMap<>();JsonParser.parseString(keys).getAsJsonObject().entrySet().forEach(e->ks.put(e.getKey(),e.getValue().getAsString()));return success(Client.verifyLease(token,p,ks,now));}catch(Client.LicenseboxException e){return failure(e.code);}}
}
