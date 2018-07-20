package ww.macro;

import haxe.macro.Expr;

typedef Info = {
    capture:Bool,
    ret:ComplexType,
    trigger:ComplexType,
    args:Array<FunctionArg>,
    isMovable:Bool,
}