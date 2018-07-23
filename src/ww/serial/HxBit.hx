package ww.serial;

#if (macro||eval)
import ww.macro.Info;
import ww.macro.Utils;
import haxe.macro.Type;
import haxe.macro.Expr;
import ww.macro.Defines;
import ww.macro.WorkerProxy;

using haxe.macro.Context;
using tink.MacroApi;

private enum abstract Errors(String) to String {
    var Func = 'Functions can not be transferred with HxBit. Consider https://github.com/ncannasse/hxbit#unsupported-types';
}

private abstract C(ComplexType) from ComplexType to ComplexType {
    public static var Serializable(get, never):C;
    static function get_Serializable():C return macro:hxbit.Serializable;

    @:to public function toType():haxe.macro.Type return this.toType().sure();
    @:to function asString():String return this.toType().sure().getID(false);
}
#end

class HxBit #if (marcro||eval) implements ISerial #end {

    #if (hxbit && !(macro || eval))
    @:isVar public static var hxbit(get, null):hxbit.Serializer;

    private static function get_hxbit():hxbit.Serializer {
        if (hxbit == null) hxbit = new hxbit.Serializer();
        return hxbit;
    }
    #end
    
    #if (macro||eval)
    public var index:Int = 0;
    public var define:Defines = 'hxbit';

    public function new() {}

    
    public function timeStamp():ExprOf<Float> {
        return Utils.runners[index-1].timeStamp();
    }

    public function allowed():Bool {
        return define.defined();
    }

    public function detectIllegalTypes(type:Type, pos:Position):Void {
        switch type {
            case TFun(_, _): Func.fatalError( pos );
            case _:
        }
    }

    public function detectIllegalClassField(field:ClassField, isStatic:Bool = false):Void {
        if (field.meta.has(':s')) {
            detectIllegalTypes(field.type, field.pos);
        }
    }

    public function detectIllegalEnumField(field:EnumField):Void {
        
    }

    public function encode(expr:Expr, info:Info):Expr {
        var ctype:C = info.trigger;
        var r = ctype.unify(C.Serializable)
            ? macro @:hxbit ww.serial.HxBit.hxbit.serialize($expr).getData()
            : macro @:hxbitFallback $e{Utils.runners[index-1].encode(expr, info)};
        return r;
    }

    public function decode(expr:Expr, info:Info):Expr {
        var ctype:C = info.trigger;
        //var cls = ctype.toString().resolve();
        var cls = Context.followWithAbstracts( ctype.toType() ).toComplex().toString().resolve();
        var r = ctype.unify(C.Serializable) 
            ? macro @:hxbit ww.serial.HxBit.hxbit.unserialize(haxe.io.Bytes.ofData($expr), $cls)
            : macro @:hxbitFallback $e{Utils.runners[index-1].decode(expr, info)};
        return r;
    }
    #end

}