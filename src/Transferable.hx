package ;

#if hxbit
import hxbit.Serializer;
import hxbit.Serializable;
#end

#if (macro||eval)
import haxe.macro.Type;
import haxe.macro.Expr;
import ww.macro.Defines;
import ww.macro.Utils.reverseRunners as runners;

using haxe.macro.Context;
using tink.MacroApi;
#end

private enum abstract SError(String) to String {
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

    @:to function asString():String {
        return toType().getID(false);
    }
}

private enum abstract Meta(String) to String {
    var CoreApi = ':coreApi';
    var HxBitSerial = ':s';
}
#end

@:forward abstract Transferable<T>(T) to T {

    public var moved(get, never):Bool;
    inline function get_moved():Bool return this == null;
    public inline function new(v) this = v;
    @:to public inline function unwrap():T return this;

    @:to inline function next():tink.CoreApi.Promise<T> {
        return unwrap();
    }

    @:from public static macro function of<A>(self:Expr):ExprOf<Transferable<A>> {
        var result = macro new Transferable($self);

        var type:Type = switch self.typeof() {
            case Success(t): t;
            case Failure(e):
                trace(e);
                null;
        }

        if (!WWP_DisableCheck.defined()) detectIllegalTypes(type, self.pos);

        if (WWP_Debug) trace( result.toString() );

        return result;
    }

    public macro function get<A>(self:Expr):ExprOf<A> {
        var result = macro $self.unwrap();
        var raw = (macro $self.unwrap()).typeof();
        var out = haxe.macro.Context.getExpectedType();
        var ctype = out.toComplex();
        var cls = ctype.toString().resolve();
        
        /*switch raw {
            case Success(t):
                if (HxBit.defined() && out.unify(C.HxBitSerializable) && t.unify(C.Bytes)) {
                    result = macro ww.macro.Utils.hxbit.unserialize(($self.unwrap()), $cls);

                } else if (WWP_Std_Serializer.defined() && out.match(TInst(_, _)) && t.unify(C.String)) {
                    result = macro (haxe.Unserializer.run($self.unwrap()):$ctype);

                }

            case Failure(e):
                trace( e );

        }*/

        if (WWP_Debug) trace( result.toString() );

        return result;
    }

    public macro function move(self:Expr):ExprOf<Null<T>> {
        return macro $self = null;
    }

    #if (macro||eval)
    /*private static function detectIllegalTypes(type:Type, pos:Position, ?hxbit:Bool = false, stdSerial:Bool = false) {
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

    }*/

    public static function detectIllegalTypes(type:Type, pos:Position) {
        if (type == null) return;

        if (WWP_Debug) {
            trace( type.reduce(false) );
        }

        var repeat = detectIllegalTypes.bind(_, _);
        var check = (t:Type, p:Position) -> for (c in runners) c.detectIllegalTypes(t, p);
        var checkClsField = (f:ClassField, s:Bool = false) -> for (c in runners) c.detectIllegalClassField(f, s);
        var checkEnmField = (f:EnumField) -> for (c in runners) c.detectIllegalEnumField(f);
        switch type.reduce(false) {
            case x = TInst(_.get() => cls, params) if (!cls.meta.has(CoreApi) && !cls.isInterface):
                check(x, pos);
                for (f in cls.fields.get()) {
                    checkClsField(f);
                    //repeat(f.type, f.pos);
                    for (p in f.params) repeat(p.t, f.pos);
                }

                for (s in cls.statics.get()) {
                    checkClsField(s, true);
                    //repeat(s.type, s.pos);
                    for (p in s.params) repeat(p.t, s.pos);
                }

                for (p in params) repeat(p, pos);

            case x = TEnum(_.get() => enm, params) if (!enm.meta.has(CoreApi)):
                check(x, pos);
                for (key in enm.constructs.keys()) {
                    var f = enm.constructs.get(key);
                    checkEnmField(f);
                    //repeat(f.type, f.pos);
                    for (p in f.params) repeat(p.t, f.pos);
                }

                for (p in params) repeat(p, pos);

            case x:
                if (WWP_Debug.defined()) trace( x );
                check(x, pos);

        }

    }
    #end

}

