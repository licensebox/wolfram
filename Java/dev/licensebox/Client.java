package dev.licensebox;

import com.google.gson.*;
import com.sun.jna.*;
import com.sun.jna.ptr.PointerByReference;
import java.lang.ref.Cleaner;
import java.lang.ref.Reference;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.function.*;

/** Owns a native Licensebox C >=0.3 client. Close with try-with-resources.
 * Linux is validated. Callbacks must not reenter the client. */
public class Client implements AutoCloseable {
    public static final class LicenseboxException extends RuntimeException {
        public final String code;
        public LicenseboxException(String code,String detail) {super("licensebox: "+detail);this.code=code;}
    }
    public static class Config {
        public String product,version="",server,directory,caBundle;
        public Map<String,String> keys=new LinkedHashMap<>();
        public BiConsumer<String,String> onSignIn;
        public BooleanSupplier cancelled;
        /** Trusted platform/test seams; never accept identity from end users. */
        public Supplier<String> machineBinding;
        public DoubleSupplier clock;
        public Config(String product,Map<String,String> keys) {this.product=product;this.keys=new LinkedHashMap<>(keys);}
    }
    public static final class SizeT extends IntegerType {
        public SizeT(){this(0);} public SizeT(long value){super(Native.SIZE_T_SIZE,value,true);}
    }
    public interface SignInCallback extends Callback {void invoke(Pointer context,String url,String code);}
    public interface ClockCallback extends Callback {double invoke(Pointer context);}
    public interface BindingCallback extends Callback {int invoke(Pointer context,Pointer output,SizeT capacity);}
    public interface CancelCallback extends Callback {int invoke(Pointer context);}
    @Structure.FieldOrder({"context","onSignIn","clock","binding","cancelled"})
    public static class NativeCallbacks extends Structure {
        public Pointer context;
        public SignInCallback onSignIn;
        public ClockCallback clock;
        public BindingCallback binding;
        public CancelCallback cancelled;
    }
    public interface NativeApi extends Library {
        NativeApi API=Native.load(System.getenv().getOrDefault("LICENSEBOX_LIBRARY","licensebox"),NativeApi.class,Collections.singletonMap(Library.OPTION_STRING_ENCODING,"UTF-8"));
        int lb_client_create_json(String options,NativeCallbacks callbacks,PointerByReference output);
        int lb_client_call_json(Pointer client,String operation,String args,PointerByReference output);
        void lb_client_destroy(Pointer client);
        String lb_error_code(Pointer client);String lb_error_message(Pointer client);String lb_result_code(int code);
        void lb_free(Pointer output);
        int lb_native_binding(String product,byte[] output,SizeT capacity);
        int lb_derive_binding(String product,String source,String raw,byte[] output,SizeT capacity);
        int lb_verify_lease_json(String token,String product,String keys,double now,PointerByReference output);
    }
    private static final Cleaner CLEANER=Cleaner.create();
    private static final class State {
        volatile Throwable failure;
        final NativeCallbacks callbacks=new NativeCallbacks();
        State(Config cfg) {
            if(cfg.onSignIn!=null) callbacks.onSignIn=(ctx,url,code)->{try{cfg.onSignIn.accept(url,code);}catch(Throwable e){failure=e;}};
            if(cfg.clock!=null) callbacks.clock=ctx->{try{double value=cfg.clock.getAsDouble();if(!Double.isFinite(value))throw new IllegalArgumentException("invalid clock result");return value;}catch(Throwable e){failure=e;return 0;}};
            if(cfg.machineBinding!=null) callbacks.binding=(ctx,out,capacity)->{try{byte[] bytes=argument(cfg.machineBinding.get()).getBytes(StandardCharsets.UTF_8);if(bytes.length>=capacity.longValue())return 1;out.write(0,bytes,0,bytes.length);out.setByte(bytes.length,(byte)0);return 0;}catch(Throwable e){failure=e;return 1;}};
            callbacks.cancelled=ctx->{if(failure!=null)return 1;try{return cfg.cancelled!=null&&cfg.cancelled.getAsBoolean()?1:0;}catch(Throwable e){failure=e;return 1;}};
        }
    }
    private static final class Resource implements Runnable {
        Pointer handle;final State state;
        Resource(Pointer handle,State state){this.handle=handle;this.state=state;}
        public synchronized void run(){if(handle!=null){NativeApi.API.lb_client_destroy(handle);handle=null;}}
    }
    private final State state;
    private final Resource resource;
    private final Cleaner.Cleanable cleanable;
    private boolean busy;
    public Client(Config cfg) {
        JsonObject options=new JsonObject();options.addProperty("product",argument(cfg.product));options.addProperty("version",argument(cfg.version));
        JsonObject keys=new JsonObject();cfg.keys.forEach((key,value)->keys.addProperty(argument(key),argument(value)));options.add("keys",keys);
        if(cfg.server!=null)options.addProperty("server",argument(cfg.server));
        if(cfg.directory!=null)options.addProperty("directory",argument(cfg.directory));
        if(cfg.caBundle!=null)options.addProperty("ca_bundle",argument(cfg.caBundle));
        state=new State(cfg);PointerByReference out=new PointerByReference();
        int result=NativeApi.API.lb_client_create_json(options.toString(),state.callbacks,out);
        Reference.reachabilityFence(state);
        if(result!=0||state.failure!=null){if(out.getValue()!=null)NativeApi.API.lb_client_destroy(out.getValue());if(state.failure!=null)throw new LicenseboxException("callback_error","application callback failed");throw resultError(result,null);}
        resource=new Resource(out.getValue(),state);cleanable=CLEANER.register(this,resource);
    }
    private static String argument(String value){if(value==null||value.indexOf(0)>=0)throw new LicenseboxException("invalid_argument","null/NUL argument");return value;}
    private static LicenseboxException resultError(int result,Pointer handle) {
        String code=NativeApi.API.lb_result_code(result),message=code;
        if(handle!=null&&!code.equals("invalid_argument")) {String saved=NativeApi.API.lb_error_code(handle);if(!saved.equals("ok"))code=saved;message=NativeApi.API.lb_error_message(handle);}
        return new LicenseboxException(code,message);
    }
    private static JsonElement output(Pointer value) {
        if(value==null)throw new LicenseboxException("protocol_error","missing native result");
        try{return JsonParser.parseString(value.getString(0,"UTF-8"));}
        catch(JsonParseException e){throw new LicenseboxException("protocol_error","invalid native JSON");}
        finally{NativeApi.API.lb_free(value);}
    }
    private synchronized JsonElement call(String operation,JsonObject args) {
        if(resource.handle==null)throw new IllegalStateException("client is closed");
        if(busy)throw new IllegalStateException("callbacks must not reenter the client");
        busy=true;PointerByReference out=new PointerByReference();
        try {
            int result=NativeApi.API.lb_client_call_json(resource.handle,operation,args.toString(),out);
            if(state.failure!=null||result!=0) {
                NativeApi.API.lb_free(out.getValue());
                if(state.failure!=null){Throwable cause=state.failure;state.failure=null;LicenseboxException error=new LicenseboxException("callback_error","application callback failed");error.initCause(cause);throw error;}
                throw resultError(result,resource.handle);
            }
            return output(out.getValue());
        } finally {busy=false;Reference.reachabilityFence(this);}
    }
    public JsonElement lease(){return call("lease",new JsonObject());}
    public JsonElement require(String module){JsonObject args=new JsonObject();args.addProperty("module",argument(module));return call("require",args);}
    public JsonElement status(){return call("status",new JsonObject());}
    public JsonElement signIn(){return signIn(0);}
    public JsonElement signIn(double timeout){if(!Double.isFinite(timeout))throw new IllegalArgumentException("invalid timeout");JsonObject args=new JsonObject();args.addProperty("timeout",timeout);return call("sign_in",args);}
    public void logout(){call("logout",new JsonObject());}
    public JsonElement modules(){return call("modules",new JsonObject());}
    public JsonElement requests(){return call("requests",new JsonObject());}
    public JsonElement requestAccess(List<String> modules,String note){JsonObject args=new JsonObject();JsonArray names=new JsonArray();modules.forEach(value->names.add(argument(value)));args.add("modules",names);args.addProperty("note",argument(note));return call("request",args);}
    public String accessLink(){return call("access-link",new JsonObject()).getAsString();}
    public void record(String command,boolean success,double elapsed){if(!Double.isFinite(elapsed)||elapsed<0)throw new IllegalArgumentException("invalid elapsed time");JsonObject args=new JsonObject();args.addProperty("command",argument(command));args.addProperty("success",success);args.addProperty("elapsed",elapsed);call("record",args);}
    @Override public synchronized void close(){if(busy)throw new IllegalStateException("callbacks must not reenter the client");cleanable.clean();}
    public static String deriveBinding(String product,String source,String raw) {
        int end=raw.length();while(end>0&&raw.charAt(end-1)==0)end--;raw=raw.substring(0,end);
        if(raw.indexOf(0)>=0)throw new LicenseboxException("identity_unavailable","invalid native identity");
        byte[] out=new byte[128];int result=NativeApi.API.lb_derive_binding(argument(product),argument(source),raw,out,new SizeT(out.length));
        if(result!=0)throw resultError(result,null);return Native.toString(out,"UTF-8");
    }
    public static String nativeBinding(String product){byte[] out=new byte[128];int result=NativeApi.API.lb_native_binding(argument(product),out,new SizeT(out.length));if(result!=0)throw resultError(result,null);return Native.toString(out,"UTF-8");}
    public static JsonElement verifyLease(String token,String product,Map<String,String> keys,double now) {
        if(!Double.isFinite(now))throw new IllegalArgumentException("invalid time");JsonObject object=new JsonObject();keys.forEach((k,v)->object.addProperty(argument(k),argument(v)));PointerByReference out=new PointerByReference();
        int result=NativeApi.API.lb_verify_lease_json(argument(token),argument(product),object.toString(),now,out);if(result!=0){NativeApi.API.lb_free(out.getValue());throw resultError(result,null);}return output(out.getValue());
    }
}
