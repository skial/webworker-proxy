package ww.check;

import haxe.macro.Expr;

interface ISerializer {
    public function encode(expr:Expr, info:{}):Expr;
    public function decode(expr:Expr, info:{}):Expr;
}