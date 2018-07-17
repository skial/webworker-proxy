package ww.check;

import haxe.macro.Type;
import haxe.macro.Expr;
import ww.macro.Defines;

class Std implements IRunner {

    public var define:Defines;
    
    public function new(d:String = 'std') {
        define = d;
    }

    public function allowed():Bool return true;

    public function detectIllegalTypes(type:Type, pos:Position):Void {

    }

    public function encode(expr:Expr, info:{}):Expr {
        return expr;
    }

    public function decode(expr:Expr, info:{}):Expr {
        return expr;
    }

}