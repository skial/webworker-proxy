package ;

#if (macro||eval)
import haxe.macro.Type;
import haxe.macro.Expr;
import ww.macro.Defines;
import ww.macro.Utils.reverseRunners as runners;

using haxe.macro.Context;
using tink.MacroApi;

private enum abstract Meta(String) to String {
    var CoreApi = ':coreApi';
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

    /*public macro function move(self:Expr):ExprOf<Null<T>> {
        return macro $self = null;
    }*/

    #if (macro||eval)
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
                    for (p in f.params) repeat(p.t, f.pos);
                }

                for (s in cls.statics.get()) {
                    checkClsField(s, true);
                    for (p in s.params) repeat(p.t, s.pos);
                }

                for (p in params) repeat(p, pos);

            case x = TEnum(_.get() => enm, params) if (!enm.meta.has(CoreApi)):
                check(x, pos);
                for (key in enm.constructs.keys()) {
                    var f = enm.constructs.get(key);
                    checkEnmField(f);
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

