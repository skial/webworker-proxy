package ;

import haxe.io.Bytes;

#if hxbit
import hxbit.Serializer;
import hxbit.Serializable;
#end

#if (macro||eval)
import haxe.macro.Expr;

using haxe.macro.Context;
using tink.MacroApi;
#end

private enum abstract SConst(String) to String {
    var HxBit = 'hxbit';
}

private enum abstract SError(String) to String {
    var WWP01_Func = 'Functions can not be transferred.';
}

#if (macro||eval)
private enum abstract C(ComplexType) from ComplexType to ComplexType {
    public static var Serializable(get, never):C;
    static function get_Serializable():C return macro:hxbit.Serializable;

    public static var Bytes(get, never):C;
    static function get_Bytes():C return macro:haxe.io.Bytes;

    @:to public function toType():haxe.macro.Type {
        return this.toType().sure();
    }
}
#end

abstract Transferable<T>(T) {

    public inline function new(v) this = v;
    public inline function unwrap():T return this;

    public static macro function of<A>(self:Expr, args:Array<Expr>):ExprOf<Transferable<A>> {
        var result = macro new Transferable($self);

        if (HxBit.defined() && self.is(C.Serializable)) {
            result = macro @:mergeBlock {
                var bytes:haxe.io.Bytes = ww.macro.Utils.serializer.serialize($self);
                var t:Transferable<haxe.io.Bytes> = new Transferable(bytes);
                t;
            }

        } else {
            switch self.typeof() {
                case Success(t): switch t {
                    case TFun(_, _): WWP01_Func.fatalError( self.pos );
                    case _:

                }
                case Failure(e): trace( e );
            }

        }

        return result;
    }

    public macro function get<A>(self:Expr):ExprOf<A> {
        var result = self;
        var raw = (macro $self.unwrap()).typeof();
        var out = haxe.macro.Context.getExpectedType();
        var eout = out.toComplex().toString().resolve();

        switch raw {
            case Success(t):
                if (HxBit.defined() && out.unify(C.Serializable) && t.unify(C.Bytes)) {
                    result = unserialize(self, C.Bytes, eout);
                }

            case Failure(e):
                trace( e );

        }

        return result;
    }

    #if (macro||eval)
    private static function unserialize(expr:Expr, c:ComplexType, cls:Expr):Expr {
        return macro ww.macro.Utils.serializer.unserialize(($expr.unwrap():$c), $cls);
    }
    #end

}