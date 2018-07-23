package ww.macro;

import haxe.macro.Expr;

typedef Info = {
    capture:Bool,
    isPromise:Bool,
    isMovable:Bool,
    ret:ComplexType,
    trigger:ComplexType,
    args:Array<FunctionArg>,
}