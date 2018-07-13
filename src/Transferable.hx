package ;

#if hxbit
import hxbit.Serializer;
import hxbit.Serializable;
#end

#if (macro||eval)
import haxe.macro.Type;
import haxe.macro.Expr;
import ww.macro.Defines;

using haxe.macro.Context;
using tink.MacroApi;
#end

private enum abstract SError(String) to String {
    var WWP01_HxBit_Func = 'Functions can not be transferred. Consider https://github.com/ncannasse/hxbit#unsupported-types';
    var WWP02_Std_Func = 'haxe.Serializer can not encode methods. See https://api.haxe.org/haxe/Serializer.html';
}

#if (macro||eval)
private abstract C(ComplexType) from ComplexType to ComplexType {
    public static var HxBitSerializable(get, never):C;
    static function get_HxBitSerializable():C return macro:hxbit.Serializable;

    public static var StdSerializer(get, never):C;
    static function get_StdSerializer():C return macro:haxe.Serializer;

    public static var StdUnserializer(get, never):C;
    static function get_StdUnserializer():C return macro:haxe.Unserializer;

    public static var String(get, never):C;
    static function get_String():C return macro:String;

    public static var Bytes(get, never):C;
    static function get_Bytes():C return macro:haxe.io.Bytes;

    @:to public function toType():haxe.macro.Type {
        return this.toType().sure();
    }
}

private enum abstract Meta(String) to String {
    var CoreApi = ':coreApi';
    var HxBitSerial = ':s';
}
#end

abstract Transferable<T>(T) {

    public var moved(get, never):Bool;
    inline function get_moved():Bool return this == null;
    public inline function new(v) this = v;
    public inline function unwrap():T return this;

    public static macro function of<A>(self:Expr, args:Array<Expr>):ExprOf<Transferable<A>> {
        var result = macro new Transferable($self);

        var type:Type = switch self.typeof() {
            case Success(t): t;
            case Failure(e):
                trace(e);
                null;
        }

        if (HxBit.defined() && self.is(C.HxBitSerializable)) {
            detectIllegalTypes(type, self.pos, true, false);
            result = macro @:mergeBlock {
                var bytes:haxe.io.Bytes = ww.macro.Utils.hxbit.serialize($self);
                var t:Transferable<haxe.io.Bytes> = new Transferable(bytes);
                t;
            }

        } else if (WWP_Std_Serializer.defined() && !self.is(C.Bytes) && type.match(TInst(_, _))) {
            detectIllegalTypes(type, self.pos, false, true);
            result = macro @:mergeBlock {
                var t:Transferable<String> = new Transferable(haxe.Serializer.run($self));
                t;
            }

        }

        if (WWP_Debug) trace( result.toString() );

        return result;
    }

    public macro function get<A>(self:Expr):ExprOf<A> {
        var result = self;
        var raw = (macro $self.unwrap()).typeof();
        var out = haxe.macro.Context.getExpectedType();
        var ctype = out.toComplex();
        var cls = ctype.toString().resolve();
        
        switch raw {
            case Success(t):
                if (HxBit.defined() && out.unify(C.HxBitSerializable) && t.unify(C.Bytes)) {
                    result = macro ww.macro.Utils.hxbit.unserialize(($self.unwrap()), $cls);

                } else if (WWP_Std_Serializer.defined() && out.match(TInst(_, _)) && t.unify(C.String)) {
                    result = macro (haxe.Unserializer.run($self.unwrap()):$ctype);

                }

            case Failure(e):
                trace( e );

        }

        if (WWP_Debug) trace( result.toString() );

        return result;
    }

    public macro function move(self:Expr):ExprOf<Null<T>> {
        return macro $self = null;
    }

    #if (macro||eval)
    private static function detectIllegalTypes(type:Type, pos:Position, ?hxbit:Bool = false, stdSerial:Bool = false) {
        if (type == null) return;
        if (WWP_Debug) {
            trace( 'hxbit: $hxbit | std: $stdSerial' );
            trace( type.reduce(false) );
        }
        var repeat = detectIllegalTypes.bind(_, _, hxbit, stdSerial);
        switch type.reduce(false) {
            case TInst(_.get() => cls, params) if (!cls.meta.has(CoreApi) && !cls.isInterface):
                for (f in cls.fields.get()) {
                    if (hxbit && !f.meta.has(HxBitSerial)) continue;
                    repeat(f.type, f.pos);
                    for (p in f.params) repeat(p.t, f.pos);
                }

                for (s in cls.statics.get()) {
                    if (hxbit && !s.meta.has(HxBitSerial)) continue;
                    repeat(s.type, s.pos);
                    for (p in s.params) repeat(p.t, s.pos);
                }

                for (p in params) repeat(p, pos);

            case TEnum(_.get() => enm, params) if (!enm.meta.has(CoreApi)):
                for (key in enm.constructs.keys()) {
                    var f = enm.constructs.get(key);
                    repeat(f.type, f.pos);
                    for (p in f.params) repeat(p.t, f.pos);
                }

                for (p in params) repeat(p, pos);

            case TFun(_, _) if (hxbit):
                WWP01_HxBit_Func.fatalError( pos );

            case TFun(_, _) if (stdSerial):
                WWP02_Std_Func.fatalError( pos );

            case x:
                if (WWP_Debug.defined()) trace( x );

        }

    }
    #end

}