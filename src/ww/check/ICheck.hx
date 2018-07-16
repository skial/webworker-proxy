package ww.check;

import haxe.macro.Type;
import haxe.macro.Expr;
import ww.macro.Defines;

interface ICheck {
    public var define:Defines;
    public function allowed():Bool;
    public function detectIllegalTypes(type:Type, pos:Position):Void;
}