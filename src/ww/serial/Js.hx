package ww.serial;

#if (macro||eval)
import ww.macro.Info;
import haxe.macro.Type;
import haxe.macro.Expr;
import ww.macro.Defines;

using haxe.macro.Context;
using tink.MacroApi;

private enum abstract Errors(String) to String {
    var JS_Func = 'JavaScript\'s structured clone algorithm can not duplicate functions. See https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Structured_clone_algorithm';
    var JS_Error = 'JavaScript\'s structured clone algorithm can not duplicated errors. See https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Structured_clone_algorithm';
    var JS_DOM = 'Attempting to clone DOM nodes will likewise throw a DATA_CLONE_ERR exception. See https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API/Structured_clone_algorithm';
}

private abstract C(ComplexType) from ComplexType to ComplexType {
    public static var JsError(get, never):C;
    static function get_JsError():C return macro:js.Error;

    public static var JsNode(get, never):C;
    static function get_JsNode():C return macro:js.html.Node;

    @:to public function toType():haxe.macro.Type return this.toType().sure();
    @:to function asString():String return this.toType().sure().getID(false);

}
#end

class Js #if (macro||eval) implements ISerial extends Std #end {

    #if (macro||eval)
    public function new() {
        super(JS);
    }

    override public function allowed():Bool return JS.defined();

    override public function detectIllegalTypes(type:Type, pos:Position):Void {
        if (JS.defined()) switch type {
            case TInst(_.get() => cls, _) if (cls.isExtern):
                if (type.unify(C.JsError)) JS_Error.fatalError( pos );
                if (type.unify(C.JsNode)) JS_DOM.fatalError( pos );

            case TFun(_, _) if (JS.defined()):
                JS_Func.fatalError( pos );

            case _:
        }

    }

    override public function timeStamp():ExprOf<Float> {
        return macro js.Browser.window.performance.now();
    }

    override public function encode(expr:Expr, info:Info):Expr {
        return macro @:js ww.serial.Std.createStdTransferable($expr);
    }

    override public function decode(expr:Expr, info:Info):Expr {
        return macro @:js ww.serial.Std.readStdTransferable($expr);
    }

    /*public function wait() {}
    public function check() {}
    public function reply() {}*/
    #end

}