package ww.serial;

import ww.macro.Info;
import haxe.macro.Type;
import haxe.macro.Expr;
import ww.macro.Defines;

interface ISerial {
    public var index:Int;
    public var define:Defines;
    public function timeStamp():ExprOf<Float>;
    public function allowed():Bool;
    public function detectIllegalTypes(type:Type, pos:Position):Void;
    public function detectIllegalClassField(field:ClassField, isStatic:Bool = false):Void;
    public function detectIllegalEnumField(field:EnumField):Void;

    public function encode(expr:Expr, info:Info):Expr;
    public function decode(expr:Expr, info:Info):Expr;
}