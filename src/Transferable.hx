package ;

#if hxbit
import hxbit.Serializer;
import hxbit.Serializable;
#end

abstract Transferable<T>(T) {

    public inline function new(v) this = v;
    public inline function get():T return this;

    public static inline function of<A>(v:Transferable<A>) return v;

    #if tink_json
    @:from static inline function fromRepresentation<A>(v:tink.json.Representation<A>) {
        return new Transferable(v.get());
    }
    #end

    #if hxbit
    @:from public static function fromHxBit<T:Serializable>(v:T):Transferable<haxe.io.Bytes> {
        return new Transferable(new hxbit.Serializer().serialize(v));
    }
    #end

}